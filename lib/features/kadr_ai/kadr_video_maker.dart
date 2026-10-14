import 'dart:io';

import '../ai/ai_clients.dart';
import '../ai/plan_generator.dart';
import '../analysis/domain/edit_plan.dart';
import '../montage/application/montage_service.dart';
import '../product_ad/application/product_ad_service.dart';
import '../projects/project.dart';
import 'kadr_video_composer.dart';

/// Draws and animates storyboard scenes. [KadrPainterScenes] runs it on the
/// phone; tests use a fake.
abstract interface class ScenePainter {
  /// Paints one scene; returns the image path.
  Future<String> paintScene(
    String prompt, {
    required String aspectRatio,
    required int seed,
    void Function(double progress)? onProgress,
  });

  /// Animates one scene from its painted [keyframe]; returns the clip path
  /// and its length in seconds.
  Future<(String, double)> animateScene(
    String prompt, {
    required String aspectRatio,
    required String keyframe,
    required int seed,
    void Function(double progress)? onProgress,
  });

  /// Called once before a job, so a live job loads the motion module first
  /// instead of reloading mid-way.
  Future<void> prepare({required bool live});
}

typedef StoryboardWriter = Future<List<StoryScene>> Function(
  String request,
  int durationSec,
  int scenes,
);

class KadrVideoResult {
  const KadrVideoResult({
    required this.projectId,
    required this.outputPath,
    required this.scenes,
    required this.live,
    required this.durationSec,
  });
  final String projectId;
  final String outputPath;
  final List<StoryScene> scenes;
  final bool live;
  final double durationSec;
}

/// "Describe a video → Kadr AI makes it", fully on the phone:
/// storyboard (brain) → one painting per scene (painter) → optional motion
/// (AnimateDiff) → music → beat-locked plan → render → verification.
class KadrVideoMaker {
  KadrVideoMaker({
    required this.repository,
    required this.renderer,
    required this.music,
    required this.painter,
    required this.storyboard,
    required this.verify,
    int Function(String path)? fileSize,
    DateTime Function()? clock,
  }) : _fileSize = fileSize ?? ((p) => File(p).lengthSync()),
       _clock = clock ?? DateTime.now;

  final ProjectRepository repository;
  final VideoRenderer renderer;
  final MusicMaker music;
  final ScenePainter painter;
  final StoryboardWriter storyboard;
  final OutputVerifier verify;
  final int Function(String path) _fileSize;
  final DateTime Function() _clock;

  /// Scenes for a video: about one per 3 s, 3–5 (each one is drawn on the
  /// phone, so more scenes means more waiting).
  static int sceneCount(int durationSec, {required bool live}) =>
      live ? 4 : (durationSec / 3).round().clamp(3, 5);

  Future<KadrVideoResult> create({
    required String request,
    int durationSec = 15,
    bool live = false,
    String aspectRatio = '9:16',
    String resolution = '1080p',
    int? seed,
    void Function(String stage)? onStage,
    void Function(double progress)? onProgress,
  }) async {
    final n = sceneCount(durationSec, live: live);
    onStage?.call('Kadr AI ssenariy yozmoqda');
    final scenes = await storyboard(request, durationSec, n);
    if (scenes.length < 2) {
      throw const AiException('Kadr AI sahnalarni yoza olmadi.');
    }
    await painter.prepare(live: live);
    // One seed for the whole video keeps the look consistent across scenes.
    final base = seed ?? DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    final clips = <ProjectClip>[];
    for (final (i, sc) in scenes.indexed) {
      void step(double p) => onProgress?.call(
        ((i + (live ? p * 0.35 : p)) / scenes.length).clamp(0, 1).toDouble(),
      );
      onStage?.call('Sahna ${i + 1}/${scenes.length} chizilmoqda');
      final image = await painter.paintScene(
        sc.prompt,
        aspectRatio: aspectRatio,
        seed: base + i,
        onProgress: step,
      );
      var path = image;
      double? sec;
      if (live) {
        onStage?.call('Sahna ${i + 1}/${scenes.length} jonlantirilmoqda');
        final (clip, len) = await painter.animateScene(
          sc.prompt,
          aspectRatio: aspectRatio,
          keyframe: image,
          seed: base + i,
          onProgress: (p) => onProgress?.call(
            ((i + 0.35 + p * 0.65) / scenes.length).clamp(0, 1).toDouble(),
          ),
        );
        path = clip;
        sec = len;
      }
      clips.add(
        ProjectClip(
          id: 'clip_${(i + 1).toString().padLeft(2, '0')}',
          path: path,
          name: 'Kadr AI sahna ${i + 1}',
          durationSec: sec,
          sizeBytes: _fileSize(path),
        ),
      );
    }

    final total = live
        ? scenes.length *
              KadrVideoComposer.motionBeats *
              KadrVideoComposer.beatFrames /
              KadrVideoComposer.fps
        : durationSec.toDouble();
    onStage?.call('Fon musiqasi yaratilmoqda');
    final musicPath = await music.make(
      durationSec: total,
      bpm: KadrVideoComposer.bpm,
    );
    final title = request.trim().isEmpty ? 'Kadr AI video' : request.trim();
    final json = KadrVideoComposer.compose(
      scenes: scenes,
      clipIds: [for (final c in clips) c.id],
      title: title,
      live: live,
      durationSec: durationSec,
      aspectRatio: aspectRatio,
      resolution: resolution,
      musicPath: musicPath,
    );
    final plan = EditPlan.fromJson(json); // never store an invalid plan
    final project = await repository.addProject(json, clips: clips);

    onStage?.call('Video render qilinmoqda');
    final out = await renderer.render(
      plan: plan,
      clips: clips,
      resolution: resolution,
      name: title,
    );
    onStage?.call('Tayyor video tekshirilmoqda');
    final problems = await verify(out, plan);
    if (problems.isNotEmpty) {
      throw AiException('Video tekshiruvdan o‘tmadi: ${problems.join('; ')}');
    }
    await repository.setLastRender(
      project.id,
      RenderInfo(
        path: out,
        sizeBytes: _fileSize(out),
        resolution: resolution,
        aspectRatio: aspectRatio,
        durationSec: plan.durationSec,
        fps: plan.export.fps,
        createdAt: _clock(),
        planSignature: planSignature(json),
      ),
    );
    return KadrVideoResult(
      projectId: project.id,
      outputPath: out,
      scenes: scenes,
      live: live,
      durationSec: plan.durationSec,
    );
  }
}
