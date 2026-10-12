import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:path_provider/path_provider.dart';

/// Video poster frames via the FFmpeg we already ship (replaces the
/// unmaintained `video_thumbnail` plugin, which breaks Android builds on
/// Gradle 9 because it still uses `jcenter()`).
abstract final class Thumbnailer {
  /// JPEG of the frame at [atSec] (0.5 s skips black first frames), or null.
  static Future<Uint8List?> jpeg(
    String videoPath, {
    double atSec = 0.5,
    int maxWidth = 260,
  }) async {
    final tmp = await getTemporaryDirectory();
    final out = File(
      '${tmp.path}/thumb_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    try {
      final session = await FFmpegKit.executeWithArguments([
        '-y',
        '-hide_banner',
        '-loglevel',
        'error',
        '-ss',
        atSec.toStringAsFixed(2),
        '-i',
        videoPath,
        '-frames:v',
        '1',
        '-vf',
        'scale=$maxWidth:-2',
        '-q:v',
        '5',
        out.path,
      ]);
      if (!ReturnCode.isSuccess(await session.getReturnCode()) ||
          !out.existsSync()) {
        // Very short clips: fall back to the first frame.
        if (atSec > 0) {
          return await jpeg(videoPath, atSec: 0, maxWidth: maxWidth);
        }
        return null;
      }
      return await out.readAsBytes();
    } finally {
      if (out.existsSync()) out.deleteSync();
    }
  }
}
