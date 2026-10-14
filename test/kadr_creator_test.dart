import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/ai/ai_clients.dart';
import 'package:hookkadr/features/ai/plan_generator.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/director/quality_control.dart';
import 'package:hookkadr/features/kadr_ai/kadr_painter.dart';
import 'package:hookkadr/features/kadr_ai/kadr_video_composer.dart';
import 'package:hookkadr/features/kadr_ai/kadr_video_maker.dart';
import 'package:hookkadr/features/kadr_ai/model_catalog.dart';
import 'package:hookkadr/features/montage/application/montage_service.dart';
import 'package:hookkadr/features/product_ad/application/product_ad_service.dart';
import 'package:hookkadr/features/product_ad/data/ad_output_check.dart';
import 'package:hookkadr/features/projects/project.dart';

List<StoryScene> _scenes(int n, {double sec = 3}) => [
  for (var i = 0; i < n; i++)
    StoryScene(
      sec: sec,
      prompt: 'a red ceramic cup on a wooden table, scene ${i + 1}',
      caption: i.isEven ? 'Sahna ${i + 1}' : null,
    ),
];

class _Repo implements ProjectRepository {
  final projects = <String, Project>{};
  RenderInfo? last;
  @override
  Future<Project> addProject(
    Map<String, dynamic> plan, {
    List<ProjectClip> clips = const [],
  }) async {
    final p = Project(
      id: 'p${projects.length + 1}',
      name: plan['title'] as String,
      planJson: plan,
      clips: clips,
      createdAt: DateTime(2026),
    );
    projects[p.id] = p;
    return p;
  }

  @override
  Project? byId(String id) => projects[id];
  @override
  Future<void> setLastRender(String id, RenderInfo info) async => last = info;
}

class _Renderer implements VideoRenderer {
  EditPlan? plan;
  @override
  Future<String> render({
    required EditPlan plan,
    required List<ProjectClip> clips,
    required String resolution,
    required String name,
    void Function(double progress)? onProgress,
  }) async {
    this.plan = plan;
    return '/tmp/kadr.mp4';
  }
}

class _Music implements MusicMaker {
  double? duration;
  int? bpm;
  @override
  Future<String> make({required double durationSec, required int bpm}) async {
    duration = durationSec;
    this.bpm = bpm;
    return '/tmp/music.m4a';
  }
}

class _Painter implements ScenePainter {
  final painted = <(String, int)>[];
  final animated = <String>[];
  bool? preparedLive;
  @override
  Future<void> prepare({required bool live}) async => preparedLive = live;
  @override
  Future<String> paintScene(
    String prompt, {
    required String aspectRatio,
    required int seed,
    void Function(double progress)? onProgress,
  }) async {
    painted.add((prompt, seed));
    onProgress?.call(1);
    return '/tmp/scene_${painted.length}.png';
  }

  @override
  Future<(String, double)> animateScene(
    String prompt, {
    required String aspectRatio,
    required String keyframe,
    required int seed,
    void Function(double progress)? onProgress,
  }) async {
    animated.add(keyframe);
    return (
      '/tmp/clip_${animated.length}.mp4',
      KadrVideoComposer.motionFrames / KadrVideoComposer.motionFps,
    );
  }
}

class _Brain implements GrammarTextModel {
  _Brain(this.reply);
  final String reply;
  String? grammar;
  @override
  ProviderKind get kind => ProviderKind.offline;
  @override
  Future<String> complete({
    required String system,
    required List<Map<String, String>> messages,
    int maxTokens = 8000,
  }) async => reply;
  @override
  Future<String> completeWithGrammar({
    required String system,
    required List<Map<String, String>> messages,
    required String grammar,
    int maxTokens = 600,
  }) async {
    this.grammar = grammar;
    return reply;
  }

  @override
  Future<void> verify() async {}
}

KadrVideoMaker _maker(
  _Repo repo,
  _Renderer r,
  _Music m,
  _Painter p, {
  List<StoryScene>? scenes,
  OutputVerifier? verify,
}) => KadrVideoMaker(
  repository: repo,
  renderer: r,
  music: m,
  painter: p,
  storyboard: (req, sec, n) async => scenes ?? _scenes(n),
  verify: verify ?? (_, _) async => const [],
  fileSize: (_) => 1000,
  clock: () => DateTime(2026),
);

void main() {
  group('model catalog', () {
    test('painter and motion packs are pinned, licensed and sized', () {
      for (final p in [KadrModelPack.painter, KadrModelPack.motion]) {
        expect(p.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(p.url, contains('/resolve/'));
        expect(p.url, isNot(contains('/main/')), reason: 'pinned revision');
        expect(p.sizeBytes, greaterThan(100 * 1024 * 1024));
        expect(p.license, isNotEmpty);
        expect(p.purpose, isNotEmpty);
      }
      expect(KadrModelPack.painter.role, KadrPackRole.painter);
      expect(KadrModelPack.motion.role, KadrPackRole.motion);
      expect(KadrModelPack.all.map((p) => p.id).toSet().length, 4);
      expect(KadrModelPack.decoder.license, 'MIT');
      expect(KadrModelPack.decoder.sizeBytes, lessThan(20 * 1024 * 1024));
    });
  });

  group('painter', () {
    test('canvas sizes are SD-friendly multiples of 64 near 512²', () {
      for (final a in ['9:16', '16:9', '1:1', '4:5', '3:4']) {
        final (w, h) = paintSizeFor(a);
        expect(w % 64, 0, reason: a);
        expect(h % 64, 0, reason: a);
        expect(w * h, inInclusiveRange(250000, 360000), reason: a);
        final (mw, mh) = motionSizeFor(a);
        expect(mw % 64, 0);
        expect(mh % 64, 0);
      }
      final (w, h) = paintSizeFor('9:16');
      expect(h / w, closeTo(16 / 9, 0.1));
    });

    test('styles add English look words and keep the scene first', () {
      final p = PaintStyle.product.apply('a watch on white marble.');
      expect(p, startsWith('a watch on white marble,'));
      expect(p, contains('product photography'));
      expect(PaintStyle.byName('nope'), PaintStyle.photo);
      expect(PaintStyle.negative, contains('watermark'));
    });

    test('frames become a 30 fps H.264 clip', () {
      final a = framesToClipArgs(
        framesDir: '/d',
        frames: 16,
        fps: 6,
        outPath: '/o.mp4',
        encoder: 'h264_videotoolbox',
      );
      expect(a, containsAllInOrder(['-framerate', '6', '-i', '/d/f_%03d.png']));
      expect(a.join(' '), contains('minterpolate=fps=30'));
      expect(a.join(' '), contains('tpad=stop_mode=clone'));
      expect(a, containsAllInOrder(['-t', '2.667']));
      expect(a.last, '/o.mp4');
    });
  });

  group('offline prompts', () {
    test('storyboard grammar asks for exactly n English scenes', () {
      final g = PlanGenerator.storyboardGrammar(4);
      expect(g, startsWith('root ::= scene scene scene scene\n'));
      expect(g, contains('"SCENE: "'));
    });

    test('grammar storyboard is parsed and evenly timed', () {
      final s = PlanGenerator.parseGrammarStoryboard(
        'SCENE: a cozy cafe at sunrise, warm light | Ertalabki qahva\n'
        'SCENE: barista pouring latte art, close up | -\n'
        'garbage line\n'
        'SCENE: friends laughing at a table, golden hour | Bizga keling\n',
        durationSec: 12,
      );
      expect(s.length, 3);
      expect(s.map((e) => e.sec), everyElement(4.0));
      expect(s[0].caption, 'Ertalabki qahva');
      expect(s[1].caption, isNull);
      expect(s[2].prompt, startsWith('friends laughing'));
    });

    test('image prompts are trimmed to what the text encoder reads', () {
      final long = List.filled(80, 'word').join(' ');
      expect(PlanGenerator.cleanImagePrompt(long).split(' ').length, 60);
      expect(PlanGenerator.cleanImagePrompt(' a cat, ('), 'a cat');
    });

    test(
      'offline brain writes the image prompt under an English grammar',
      () async {
        final brain = _Brain('a white cat sleeping on a sunny windowsill');
        final gen = PlanGenerator(planner: brain);
        final p = await gen.writeGenerationPrompt(
          request: 'deraza oldida uxlayotgan oq mushuk',
          video: false,
          aspectRatio: '1:1',
        );
        expect(p, 'a white cat sleeping on a sunny windowsill');
        expect(brain.grammar, PlanGenerator.imagePromptGrammar);
      },
    );

    test(
      'offline brain writes the storyboard under the scene grammar',
      () async {
        final brain = _Brain(
          'SCENE: a bakery window with fresh bread | Issiq non\n'
          'SCENE: hands kneading dough, flour in the air | -\n'
          'SCENE: a family sharing bread at dinner | Har kuni yangi\n',
        );
        final s = await PlanGenerator(planner: brain).writeStoryboard(
          request: 'nonvoyxona reklamasi',
          durationSec: 9,
          aspectRatio: '9:16',
          scenes: 3,
        );
        expect(s.length, 3);
        expect(brain.grammar, PlanGenerator.storyboardGrammar(3));
      },
    );
  });

  group('KadrVideoComposer', () {
    test('beats: proportional, at least 3 each, exact total', () {
      final b = KadrVideoComposer.allocate([1, 2, 1], 22);
      expect(b.fold<int>(0, (a, x) => a + x), 22);
      expect(b.every((x) => x >= 3), isTrue);
      expect(b[1], greaterThan(b[0]));
      expect(
        () => KadrVideoComposer.allocate([1, 1, 1, 1, 1, 1, 1, 1], 22),
        throwsArgumentError,
      );
    });

    test('stills: exact length on the beat grid, valid and clean plan', () {
      final json = KadrVideoComposer.compose(
        scenes: _scenes(5),
        clipIds: [for (var i = 1; i <= 5; i++) 'clip_0$i'],
        title: 'Kafe',
        live: false,
        durationSec: 15,
        musicPath: '/m.m4a',
      );
      final plan = EditPlan.fromJson(json);
      expect(plan.durationSec, 15);
      expect(plan.shots.first.motion, ShotMotion.punchIn);
      for (final s in plan.shots) {
        final f = s.startSec * KadrVideoComposer.fps;
        expect(f % KadrVideoComposer.beatFrames, closeTo(0, 1e-6));
      }
      expect(plan.captions.length, 3);
      expect(json['music'], isNotNull);
      final qc = QualityControl.check(plan);
      expect(qc.where((f) => f.severity == Severity.problem), isEmpty);
      expect(qc.map((f) => f.code), isNot(contains("caption_overlap")));
    });

    test('live: four beats (16 frames at 6 fps) per scene, no zoom', () {
      final json = KadrVideoComposer.compose(
        scenes: _scenes(4),
        clipIds: [for (var i = 1; i <= 4; i++) 'clip_0$i'],
        title: 'Jonli',
        live: true,
      );
      final plan = EditPlan.fromJson(json);
      const clip = KadrVideoComposer.motionFrames / KadrVideoComposer.motionFps;
      expect(plan.durationSec, closeTo(4 * clip, 1e-9));
      for (final s in plan.shots) {
        expect(s.duration, closeTo(clip, 1e-9));
        expect(s.motion, ShotMotion.none);
      }
    });
  });

  group('KadrVideoMaker', () {
    test(
      'stills: paints every scene with one seed family, renders, verifies',
      () async {
        final repo = _Repo();
        final r = _Renderer();
        final m = _Music();
        final p = _Painter();
        final res = await _maker(
          repo,
          r,
          m,
          p,
        ).create(request: 'Kafe reklamasi', durationSec: 15, seed: 100);
        expect(p.preparedLive, isFalse);
        expect(p.painted.length, 5);
        expect([for (final x in p.painted) x.$2], [100, 101, 102, 103, 104]);
        expect(p.animated, isEmpty);
        expect(res.durationSec, 15);
        expect(m.bpm, KadrVideoComposer.bpm);
        expect(r.plan!.shots.length, 5);
        expect(repo.last!.durationSec, 15);
        expect(repo.projects.values.single.clips.first.isImage, isTrue);
      },
    );

    test('live: each painted scene is animated from its keyframe', () async {
      final p = _Painter();
      final m = _Music();
      final res = await _maker(
        _Repo(),
        _Renderer(),
        m,
        p,
      ).create(request: 'Dengiz shamoli', live: true);
      expect(p.preparedLive, isTrue);
      expect(p.animated, [
        '/tmp/scene_1.png',
        '/tmp/scene_2.png',
        '/tmp/scene_3.png',
        '/tmp/scene_4.png',
      ]);
      expect(res.live, isTrue);
      expect(m.duration, closeTo(res.durationSec, 1e-9));
    });

    test('a file that fails verification is never reported as done', () async {
      final repo = _Repo();
      await expectLater(
        _maker(
          repo,
          _Renderer(),
          _Music(),
          _Painter(),
          verify: (_, _) async => ['ovoz yo‘q'],
        ).create(request: 'x'),
        throwsA(isA<AiException>()),
      );
      expect(repo.last, isNull);
    });

    test('too few scenes from the brain is an honest error', () async {
      await expectLater(
        _maker(
          _Repo(),
          _Renderer(),
          _Music(),
          _Painter(),
          scenes: _scenes(1),
        ).create(request: 'x'),
        throwsA(isA<AiException>()),
      );
    });

    test('verification uses the real output checker contract', () {
      expect(adOutputProblems, isA<Function>());
    });
  });
}
