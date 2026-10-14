import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/ai/ai_clients.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/montage/application/montage_service.dart';
import 'package:hookkadr/features/projects/project.dart';
import 'package:hookkadr/features/render/media_analyzer.dart';

/// Returns canned measurements; can be told to fail for one clip.
class FakeAnalyzer implements ClipAnalyzer {
  FakeAnalyzer(this.facts, {this.failFor});
  final Map<String, ClipFacts> facts;
  final String? failFor;
  final calls = <String>[];

  @override
  Future<ClipFacts> analyze(String id, String path) async {
    calls.add(id);
    if (id == failFor) throw Exception('ffprobe failed');
    return facts[id]!;
  }
}

class FakeRenderer implements VideoRenderer {
  EditPlan? lastPlan;
  String? lastResolution;
  Exception? failure;

  @override
  Future<String> render({
    required EditPlan plan,
    required List<ProjectClip> clips,
    required String resolution,
    required String name,
    void Function(double progress)? onProgress,
  }) async {
    lastPlan = plan;
    lastResolution = resolution;
    if (failure != null) throw failure!;
    onProgress?.call(0.5);
    onProgress?.call(1);
    return '/renders/$name.mp4';
  }
}

class MemoryRepository implements ProjectRepository {
  final projects = <String, Project>{};

  @override
  Future<Project> addProject(
    Map<String, dynamic> plan, {
    List<ProjectClip> clips = const [],
  }) async {
    final p = Project(
      id: 'p${projects.length + 1}',
      name: plan['title'] as String,
      createdAt: DateTime(2026),
      planJson: plan,
      clips: clips,
    );
    projects[p.id] = p;
    return p;
  }

  @override
  Project? byId(String id) => projects[id];

  @override
  Future<void> setLastRender(String id, RenderInfo info) async {
    projects[id] = projects[id]!.copyWith(lastRender: info);
  }
}

const _settings = MontageSettings(
  targetSec: 10,
  aspectRatio: '9:16',
  resolution: '720p',
  platform: 'Reels',
);

const _clips = [
  MontageClip(id: 'clip_01', path: '/a.mp4', name: 'a.mp4', durationSec: 6),
  MontageClip(id: 'clip_02', path: '/b.mp4', name: 'b.mp4', durationSec: 8),
];

final _facts = {
  'clip_01': const ClipFacts(id: 'clip_01', durationSec: 6, sceneCuts: [3]),
  'clip_02': const ClipFacts(
    id: 'clip_02',
    durationSec: 8,
    silences: [(start: 2, end: 3)],
    hasAudio: true,
  ),
};

MontageService _service(
  FakeAnalyzer a,
  FakeRenderer r,
  MemoryRepository repo,
) => MontageService(
  analyzer: a,
  renderer: r,
  repository: repo,
  clock: () => DateTime(2026, 10, 12),
  fileSize: (_) => 1234567,
);

void main() {
  test(
    'without an AI that can watch video, the offline editor builds the project',
    () async {
      final repo = MemoryRepository();
      final stages = <String>[];
      final result = await _service(FakeAnalyzer(_facts), FakeRenderer(), repo)
          .buildProject(
            clips: _clips,
            prompt: '',
            settings: _settings,
            onStage: stages.add,
          );
      final plan = EditPlan.fromJson(result.plan);
      expect(plan.aspectRatio, '9:16');
      expect(plan.shots.map((s) => s.sourceClipId).toSet(), {
        'clip_01',
        'clip_02',
      });
      expect(result.note, isNull); // no written instructions were ignored
      expect(repo.byId(result.projectId)!.clips, hasLength(2));
      expect(stages.first, contains('o‘lchanmoqda'));
    },
  );

  test(
    'written instructions with the offline editor produce an honest note',
    () async {
      final result = await _service(
        FakeAnalyzer(_facts),
        FakeRenderer(),
        MemoryRepository(),
      ).buildProject(clips: _clips, prompt: 'Tezroq qil', settings: _settings);
      expect(result.note, contains('AI’siz'));
    },
  );

  test('a failed measurement does not block the montage', () async {
    final analyzer = FakeAnalyzer(_facts, failFor: 'clip_02');
    final result = await _service(
      analyzer,
      FakeRenderer(),
      MemoryRepository(),
    ).buildProject(clips: _clips, prompt: '', settings: _settings);
    expect(analyzer.calls, ['clip_01', 'clip_02']);
    expect(EditPlan.fromJson(result.plan).shots, isNotEmpty);
  });

  test('no usable footage is reported, nothing is stored', () async {
    final repo = MemoryRepository();
    final empty = {'clip_01': const ClipFacts(id: 'clip_01', durationSec: 0.3)};
    expect(
      () => _service(FakeAnalyzer(empty), FakeRenderer(), repo).buildProject(
        clips: const [MontageClip(id: 'clip_01', path: '/a', name: 'a')],
        prompt: '',
        settings: _settings,
      ),
      throwsA(isA<AiException>()),
    );
    expect(repo.projects, isEmpty);
  });

  test('render records real file facts as the current output', () async {
    final repo = MemoryRepository();
    final renderer = FakeRenderer();
    final svc = _service(FakeAnalyzer(_facts), renderer, repo);
    final built = await svc.buildProject(
      clips: _clips,
      prompt: '',
      settings: _settings,
    );
    final progress = <double>[];
    final info = await svc.render(
      built.projectId,
      resolution: '1080p',
      onProgress: progress.add,
    );

    expect(info, isNotNull);
    expect(info!.sizeBytes, 1234567);
    expect(info.resolution, '1080p');
    expect(renderer.lastResolution, '1080p');
    expect(progress, [0.5, 1]);
    expect(repo.byId(built.projectId)!.renderIsCurrent, isTrue);
  });

  test('a project without clips is not rendered', () async {
    final repo = MemoryRepository();
    final p = await repo.addProject({
      'schemaVersion': 1,
      'title': 't',
      'summary': 's',
      'durationSec': 3,
      'aspectRatio': '9:16',
      'shots': [
        {'id': 's1', 'startSec': 0, 'endSec': 3, 'description': 'd'},
      ],
      'mediaSlots': <Map<String, dynamic>>[],
      'captions': <Map<String, dynamic>>[],
      'audioTracks': <Map<String, dynamic>>[],
      'export': {'resolution': '720p', 'fps': 30},
    });
    final info = await _service(
      FakeAnalyzer(_facts),
      FakeRenderer(),
      repo,
    ).render(p.id, resolution: '720p');
    expect(info, isNull);
  });

  test(
    'render metadata preserves the requested 60 FPS instead of assuming 30',
    () async {
      final repo = MemoryRepository();
      final renderer = FakeRenderer();
      final svc = _service(FakeAnalyzer(_facts), renderer, repo);
      final built = await svc.buildProject(
        clips: _clips,
        prompt: '',
        settings: _settings,
      );
      (repo.byId(built.projectId)!.planJson['export'] as Map)['fps'] = 60;
      final info = await svc.render(built.projectId, resolution: '720p');
      expect(renderer.lastPlan!.export.fps, 60);
      expect(info!.fps, 60);
    },
  );

  test(
    'failed artifact verification never replaces the previous valid render',
    () async {
      final repo = MemoryRepository();
      final renderer = FakeRenderer();
      final svc = _service(FakeAnalyzer(_facts), renderer, repo);
      final built = await svc.buildProject(
        clips: _clips,
        prompt: '',
        settings: _settings,
      );
      final previous = await svc.render(built.projectId, resolution: '720p');
      renderer.failure = Exception('Encoded artifact did not match the plan');
      await expectLater(
        svc.render(built.projectId, resolution: '1080p'),
        throwsA(same(renderer.failure)),
      );
      expect(repo.byId(built.projectId)!.lastRender, same(previous));
    },
  );
}
