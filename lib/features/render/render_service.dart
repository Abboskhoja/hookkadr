import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../analysis/domain/edit_plan.dart';
import '../projects/project.dart';
import '../montage/application/montage_service.dart';
import 'render_plan.dart';
import 'render_verification.dart';

class RenderException implements Exception {
  const RenderException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Offline renderer: executes an EditPlan with FFmpeg on the device.
class RenderService implements VideoRenderer {
  Future<String> _fontFile() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/Inter.ttf');
    if (!file.existsSync()) {
      final data = await rootBundle.load('assets/fonts/Inter.ttf');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return file.path;
  }

  Future<bool> _hasAudio(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final streams = session.getMediaInformation()?.getStreams() ?? [];
      return streams.any((s) => s.getType() == 'audio');
    } catch (_) {
      return false;
    }
  }

  /// Renders [plan] to an MP4 and returns its path. [onProgress] is 0..1 and
  /// reflects real encoder time versus the plan duration.
  @override
  Future<String> render({
    required EditPlan plan,
    required List<ProjectClip> clips,
    required String resolution,
    required String name,
    void Function(double progress)? onProgress,
  }) async {
    for (final s in plan.shots) {
      final id = s.sourceClipId;
      if (id == null) continue;
      final clip = clips.where((c) => c.id == id).firstOrNull;
      if (clip == null || !File(clip.path).existsSync()) {
        throw RenderException('$id fayli topilmadi. Klipni qayta qo‘shing.');
      }
    }

    final music = plan.music;
    if (music != null && !File(music.path).existsSync()) {
      throw const RenderException(
        'Musiqa fayli topilmadi. Musiqani qayta tanlang.',
      );
    }
    double? musicSec;
    if (music != null) {
      final info = (await FFprobeKit.getMediaInformation(music.path))
          .getMediaInformation();
      musicSec = double.tryParse(info?.getDuration() ?? '');
    }
    final font = await _fontFile();
    final audio = <String>{};
    for (final c in clips) {
      if (!c.isImage && await _hasAudio(c.path)) audio.add(c.id);
    }
    final docs = await getApplicationDocumentsDirectory();
    final outDir = Directory('${docs.path}/renders')
      ..createSync(recursive: true);
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final out =
        '${outDir.path}/${safe}_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final textDir = Directory('${outDir.path}/.text')
      ..createSync(recursive: true);
    // LGPL build has no libx264: use the platform hardware encoder.
    final encoder = Platform.isIOS ? 'h264_videotoolbox' : 'h264_mediacodec';
    final built = buildRenderArgs(
      plan: plan,
      clips: clips,
      hasAudio: audio,
      fontPath: font,
      textDir: textDir.path,
      outputPath: out,
      videoEncoder: encoder,
      resolution: resolution,
      musicDurationSec: musicSec,
    );

    for (final e in built.textFiles.entries) {
      await File(e.key).writeAsString(e.value, flush: true);
    }
    final finished = Completer<FFmpegSession>();
    await FFmpegKit.executeWithArgumentsAsync(
      built.args,
      (session) {
        if (!finished.isCompleted) finished.complete(session);
      },
      null,
      (stats) {
        final t = stats.getTime() / 1000.0;
        if (built.totalSec > 0) {
          // Completion means the encoded artifact passed verification too.
          onProgress?.call((t / built.totalSec).clamp(0.0, 0.99));
        }
      },
    );
    final session = await finished.future;
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) {
      if (ReturnCode.isCancel(code)) {
        throw const RenderException('Render bekor qilindi.');
      }
      final logs = await session.getAllLogsAsString();
      final tail = (logs ?? '')
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final hint = tail.isEmpty ? '' : ': ${tail.last}';
      throw RenderException('Render muvaffaqiyatsiz tugadi$hint');
    }
    if (!File(out).existsSync() || File(out).lengthSync() == 0) {
      throw const RenderException('Render fayli yaratilmadi.');
    }
    try {
      final probe = (await FFprobeKit.getMediaInformation(out))
          .getMediaInformation()
          ?.getAllProperties();
      if (probe == null) {
        throw const RenderException('Eksport faylini tekshirib bo‘lmadi.');
      }
      final size = outputSize(plan.aspectRatio, resolution);
      final issues = verifyRender(
        measured: RenderMeasurements.fromProbe(probe),
        expectedWidth: size.width,
        expectedHeight: size.height,
        expectedDurationSec: plan.durationSec,
        expectedFps: plan.export.fps,
      );
      if (issues.isNotEmpty) {
        throw RenderException(issues.map((i) => i.message).join(' '));
      }
    } catch (error) {
      // A rejected file is never returned to callers or recorded as an export.
      try {
        await File(out).delete();
      } on FileSystemException {
        // Preserve the verification error when cleanup is unavailable.
      }
      if (error is RenderException) rethrow;
      throw const RenderException('Eksport faylini tekshirib bo‘lmadi.');
    }
    onProgress?.call(1);
    return out;
  }

  Future<void> cancel() => FFmpegKit.cancel();
}
