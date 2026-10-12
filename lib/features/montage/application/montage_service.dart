import 'dart:io';

import '../../ai/ai_clients.dart';
import '../../ai/plan_generator.dart';
import '../../analysis/domain/edit_plan.dart';
import '../../plan/auto_editor.dart';
import '../../projects/project.dart';
import '../../render/media_analyzer.dart';

/// Measures a clip's scene cuts and silences. Implemented by [MediaAnalyzer]
/// (FFmpeg); faked in tests.
abstract interface class ClipAnalyzer {
  Future<ClipFacts> analyze(String id, String path);
}

/// Turns an [EditPlan] plus source clips into an MP4 and returns its path.
/// Implemented by `RenderService` (FFmpeg); faked in tests.
abstract interface class VideoRenderer {
  Future<String> render({
    required EditPlan plan,
    required List<ProjectClip> clips,
    required String resolution,
    required String name,
    void Function(double progress)? onProgress,
  });
}

/// Persistence the montage flow needs. `AppController` implements it.
abstract interface class ProjectRepository {
  Future<Project> addProject(
    Map<String, dynamic> plan, {
    List<ProjectClip> clips,
  });
  Project? byId(String id);
  Future<void> setLastRender(String id, RenderInfo info);
}

/// A clip the user attached in chat, with its stable id and instruction.
class MontageClip {
  const MontageClip({
    required this.id,
    required this.path,
    required this.name,
    this.note = '',
    this.durationSec,
    this.sizeBytes,
  });

  final String id;
  final String path;
  final String name;
  final String note;
  final double? durationSec;
  final int? sizeBytes;

  /// Too big for inline upload to the video-understanding model.
  bool get tooLargeForAi => (sizeBytes ?? 0) > GeminiClient.maxInlineBytes;
}

/// Output targets for the next montage (the "next action" settings).
class MontageSettings {
  const MontageSettings({
    required this.targetSec,
    required this.aspectRatio,
    required this.resolution,
    required this.platform,
  });

  final int targetSec;
  final String aspectRatio;
  final String resolution;
  final String platform;
}

/// Result of [MontageService.buildProject].
class MontageResult {
  const MontageResult({required this.projectId, required this.plan, this.note});

  final String projectId;
  final Map<String, dynamic> plan;

  /// Shown to the user when something about the result needs explaining
  /// (e.g. the offline editor cannot read written instructions).
  final String? note;
}

/// Application service for "drop clips → finished video".
///
/// Why a service instead of widget code: the flow (measure → plan → validate
/// → persist → render → record) is business logic. Keeping it out of
/// `State` makes it testable with fakes and reusable from Studio or a
/// future background job, and the UI only reports stages and progress.
class MontageService {
  MontageService({
    required this.analyzer,
    required this.renderer,
    required this.repository,
    DateTime Function()? clock,
    int Function(String path)? fileSize,
  }) : _clock = clock ?? DateTime.now,
       _fileSize = fileSize ?? ((p) => File(p).lengthSync());

  final ClipAnalyzer analyzer;
  final VideoRenderer renderer;
  final ProjectRepository repository;
  final DateTime Function() _clock;
  final int Function(String path) _fileSize;

  /// Measures every clip, plans the edit and stores a new project.
  ///
  /// Uses [planner] only when it can actually watch video ([canWatchVideo])
  /// and every clip is small enough to upload; otherwise falls back to the
  /// offline [AutoEditor]. Throws [AiException] when nothing usable is found
  /// or the AI fails, and never stores an invalid plan.
  Future<MontageResult> buildProject({
    required List<MontageClip> clips,
    required String prompt,
    required MontageSettings settings,
    PlanGenerator? planner,
    bool canWatchVideo = false,
    StageCallback? onStage,
  }) async {
    onStage?.call('Kliplar o‘lchanmoqda: sahnalar va pauzalar');
    final facts = <ClipFacts>[];
    for (final c in clips) {
      try {
        facts.add(await analyzer.analyze(c.id, c.path));
      } catch (_) {
        // Measurement is an optimisation; a clip still works without it.
        facts.add(ClipFacts(id: c.id, durationSec: c.durationSec ?? 0));
      }
    }

    final useAi =
        planner != null && canWatchVideo && !clips.any((c) => c.tooLargeForAi);
    final Map<String, dynamic> plan;
    String? note;
    if (useAi) {
      plan = await planner.fromClips(
        clips: [
          for (final (i, c) in clips.indexed)
            ClipInput(
              id: c.id,
              path: c.path,
              note: [if (c.note.isNotEmpty) c.note, facts[i].hint].join('\n'),
              durationSec: c.durationSec ?? facts[i].durationSec,
            ),
        ],
        prompt: prompt,
        platform: settings.platform,
        durationSec: settings.targetSec,
        aspectRatio: settings.aspectRatio,
        resolution: settings.resolution,
      );
    } else {
      onStage?.call(
        'Avto-montaj: pauzalar kesilmoqda, sahnalar bo‘yicha kesish',
      );
      plan = AutoEditor.build(
        clips: [
          for (final f in facts)
            if (f.durationSec > 0) f,
        ],
        targetSec: settings.targetSec,
        aspectRatio: settings.aspectRatio,
        resolution: settings.resolution,
        title: prompt.isEmpty ? 'Avto-montaj' : prompt,
      );
      if ((plan['shots'] as List).isEmpty) {
        throw const AiException(
          'Kliplardan ishlatsa bo‘ladigan qism topilmadi.',
        );
      }
      if (clips.any((c) => c.note.isNotEmpty) || prompt.isNotEmpty) {
        note =
            'Eslatma: bu tezkor avto-montaj (AI’siz). Izoh va matnli ko‘rsatmalarni '
            'hisobga olish uchun Gemini’ni ulang — u videoni ko‘rib reja tuzadi.';
      }
    }
    EditPlan.fromJson(plan); // throws EditPlanFormatException if invalid

    final project = await repository.addProject(
      plan,
      clips: [
        for (final (i, c) in clips.indexed)
          ProjectClip(
            id: c.id,
            path: c.path,
            name: c.name,
            durationSec: c.durationSec ?? facts[i].durationSec,
            sizeBytes: c.sizeBytes,
          ),
      ],
    );
    return MontageResult(projectId: project.id, plan: plan, note: note);
  }

  /// Renders the project's current plan and records it as the current
  /// output. Returns null when the project has no footage to render.
  Future<RenderInfo?> render(
    String projectId, {
    required String resolution,
    StageCallback? onStage,
    void Function(double progress)? onProgress,
  }) async {
    final project = repository.byId(projectId);
    if (project == null || project.clips.isEmpty) return null;
    final plan = EditPlan.fromJson(project.planJson);
    onStage?.call(
      'Video render qilinmoqda (${resolution == '4K' ? '4K — sekinroq' : resolution})',
    );
    final out = await renderer.render(
      plan: plan,
      clips: project.clips,
      resolution: resolution,
      name: project.name,
      onProgress: onProgress,
    );
    final info = RenderInfo(
      path: out,
      sizeBytes: _fileSize(out),
      resolution: resolution,
      aspectRatio: plan.aspectRatio,
      durationSec: plan.durationSec,
      fps: 30,
      createdAt: _clock(),
      planSignature: planSignature(project.planJson),
    );
    await repository.setLastRender(projectId, info);
    return info;
  }
}
