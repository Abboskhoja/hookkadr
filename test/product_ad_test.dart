import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/core/theme/app_theme.dart';
import 'package:hookkadr/features/product_ad/data/ad_output_check.dart';
import 'package:hookkadr/features/product_ad/presentation/product_ad_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hookkadr/features/ai/ai_clients.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/director/quality_control.dart';
import 'package:hookkadr/features/montage/application/montage_service.dart';
import 'package:hookkadr/features/product_ad/application/ad_copy_writer.dart';
import 'package:hookkadr/features/product_ad/application/product_ad_service.dart';
import 'package:hookkadr/features/product_ad/data/music_synth.dart';
import 'package:hookkadr/features/product_ad/domain/ad_copy.dart';
import 'package:hookkadr/features/product_ad/domain/product_ad_composer.dart';
import 'package:hookkadr/features/projects/project.dart';

AdCopy _copy() => AdCopy(
  hook: 'Yangi kolleksiya keldi',
  lines: ['Tabiiy charm', 'Qo‘lda tikilgan', 'Har kunga mos'],
  cta: 'Hoziroq buyurtma bering',
);

List<String> _ids(int n) => [
  for (var i = 1; i <= n; i++) 'img_${i.toString().padLeft(2, '0')}',
];

class _Model implements GrammarTextModel {
  _Model(this.reply);
  final String reply;
  String? grammar;
  String? prompt;
  @override
  ProviderKind get kind => ProviderKind.offline;
  @override
  Future<String> completeWithGrammar({
    required String system,
    required List<Map<String, String>> messages,
    required String grammar,
    int maxTokens = 600,
  }) async {
    this.grammar = grammar;
    prompt = messages.last['content'];
    return reply;
  }

  @override
  Future<String> complete({
    required String system,
    required List<Map<String, String>> messages,
    int maxTokens = 8000,
  }) => throw StateError('grammar path expected');
  @override
  Future<void> verify() async {}
}

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
  List<ProjectClip>? clips;
  @override
  Future<String> render({
    required EditPlan plan,
    required List<ProjectClip> clips,
    required String resolution,
    required String name,
    void Function(double progress)? onProgress,
  }) async {
    this.plan = plan;
    this.clips = clips;
    onProgress?.call(1);
    return '/tmp/out.mp4';
  }
}

class _Music implements MusicMaker {
  int? bpm;
  double? duration;
  @override
  Future<String> make({required double durationSec, required int bpm}) async {
    duration = durationSec;
    this.bpm = bpm;
    return '/tmp/music.m4a';
  }
}

void main() {
  group('AdCopy', () {
    test('cleans model artefacts and keeps lines short enough to read', () {
      final c = AdCopy(
        hook: '  **"Yangi kolleksiya"**  ',
        lines: [
          'Juda ham chiroyli va zamonaviy dizayndagi charm sumka endi sotuvda',
        ],
        cta: 'Buyurtma bering!',
      );
      expect(c.hook, 'Yangi kolleksiya');
      expect(c.lines.single.length, lessThanOrEqualTo(AdCopy.maxChars));
      expect(c.lines.single, isNot(endsWith(' ')));
    });

    test('drops list numbering and a cut-off bracket the model left', () {
      expect(AdCopy.fit('1. Qo‘lda tikilgan sifat.'), 'Qo‘lda tikilgan sifat.');
      expect(AdCopy.fit('3) Unutilmas uslub'), 'Unutilmas uslub');
      expect(
        AdCopy.fit('O‘zingizni ajratib oling! (Bir necha rangda mavjud)'),
        'O‘zingizni ajratib oling!',
      );
      expect(AdCopy.fit('Yangi (2026) kolleksiya'), 'Yangi (2026) kolleksiya');
      // The video font has no emoji: they would render as empty boxes.
      expect(AdCopy.fit('🌟 Qo‘lda tikilgan sifat ✨'), 'Qo‘lda tikilgan sifat');
      expect(AdCopy.fit('👜 Har bir sumka o‘ziga xos'), 'Har bir sumka o‘ziga xos');
    });

    test('refuses empty hook or call to action', () {
      expect(
        () => AdCopy(hook: ' ', lines: const [], cta: 'Ok'),
        throwsArgumentError,
      );
      expect(
        () => AdCopy(hook: 'Ok', lines: const [], cta: '**'),
        throwsArgumentError,
      );
    });
  });

  group('ProductAdComposer', () {
    Map<String, dynamic> plan() => ProductAdComposer.compose(
      clipIds: _ids(5),
      copy: _copy(),
      title: 'Charm sumka reklamasi',
      durationSec: 20,
      musicPath: '/tmp/music.m4a',
    );

    test(
      '5 photos become a valid 20.0 s 9:16 plan, each photo once, in order',
      () {
        final p = EditPlan.fromJson(plan());
        expect(p.durationSec, 20);
        expect(p.aspectRatio, '9:16');
        expect(p.export.fps, 30);
        expect(p.shots.map((s) => s.sourceClipId), _ids(5));
        expect(p.shots.last.endSec, 20);
        for (final (i, s) in p.shots.indexed) {
          if (i > 0) expect(s.startSec, p.shots[i - 1].endSec);
          expect(s.sourceIn, 0);
          expect(s.sourceOut! - (s.endSec - s.startSec), closeTo(0, 1e-9));
        }
      },
    );

    test('every cut lands on a music beat and on a whole video frame', () {
      final p = EditPlan.fromJson(plan());
      final beat = 60 / ProductAdComposer.bpm;
      for (final s in p.shots.take(p.shots.length - 1)) {
        final beats = s.endSec / beat;
        expect(
          beats,
          closeTo(beats.roundToDouble(), 1e-9),
          reason: '${s.endSec}',
        );
        final frames = s.endSec * 30;
        expect(frames, closeTo(frames.roundToDouble(), 1e-9));
      }
      expect(p.music!.beats.first, 0);
      expect(p.music!.beats[1], closeTo(beat, 1e-9));
    });

    test('hook is the shortest beat, the call to action has the most room', () {
      final d = [
        for (final s in EditPlan.fromJson(plan()).shots) s.endSec - s.startSec,
      ];
      expect(
        d.first,
        lessThanOrEqualTo(d.reduce((a, b) => a < b ? a : b) + 1e-9),
      );
      expect(d.last, greaterThanOrEqualTo(d[1]));
      expect(d.every((x) => x >= 2.0 - 1e-9), isTrue, reason: '$d');
    });

    test('photos move (Ken Burns) and scenes dissolve into each other', () {
      final p = EditPlan.fromJson(plan());
      expect(p.shots.every((s) => s.motion != ShotMotion.none), isTrue);
      expect(p.shots.first.transition, ShotTransition.fadeBlack);
      expect(
        p.shots.skip(1).every((s) => s.transition == ShotTransition.crossfade),
        isTrue,
      );
      expect(p.grade, isNotNull);
    });

    test(
      'hook, one benefit per middle photo and CTA are readable on screen',
      () {
        final p = EditPlan.fromJson(plan());
        expect(p.captions.map((c) => c.text), [
          'Yangi kolleksiya keldi',
          'Tabiiy charm',
          'Qo‘lda tikilgan',
          'Har kunga mos',
          'Hoziroq buyurtma bering',
        ]);
        expect(
          p.captions.first.startSec,
          lessThan(1.0),
        ); // hook in the first second
        expect(p.captions.last.endSec, lessThanOrEqualTo(20));
        final qc = QualityControl.check(p);
        expect(qc.where((f) => f.severity == Severity.problem), isEmpty);
        expect(qc.map((f) => f.code), isNot(contains('caption_overlap')));
      },
    );

    test('music fades and is part of the plan', () {
      final m = EditPlan.fromJson(plan()).music!;
      expect(m.path, '/tmp/music.m4a');
      expect(m.fadeOutSec, greaterThan(0));
      expect(m.volume, inInclusiveRange(0.3, 0.8));
    });

    test('rejects too few photos or more than the duration can show', () {
      expect(
        () => ProductAdComposer.compose(
          clipIds: _ids(1),
          copy: _copy(),
          title: 't',
        ),
        throwsArgumentError,
      );
      expect(
        () => ProductAdComposer.compose(
          clipIds: _ids(12),
          copy: _copy(),
          title: 't',
          durationSec: 15,
        ),
        throwsArgumentError,
      );
    });

    test('other formats and lengths stay exact', () {
      final p = EditPlan.fromJson(
        ProductAdComposer.compose(
          clipIds: _ids(3),
          copy: AdCopy(hook: 'A', lines: const ['B'], cta: 'C'),
          title: 't',
          durationSec: 15,
          aspectRatio: '1:1',
        ),
      );
      expect(p.durationSec, 15);
      expect(p.shots.last.endSec, 15);
      expect(p.aspectRatio, '1:1');
    });
  });

  group('AdCopyWriter', () {
    test(
      'Kadr AI writes the copy under a grammar for exactly N photos',
      () async {
        final m = _Model(
          'HOOK: Yangi kolleksiya keldi\n'
          'FOTO: Tabiiy charm\nFOTO: Qo‘lda tikilgan\nFOTO: Har kunga mos\n'
          'CTA: Hoziroq buyurtma bering\n',
        );
        final r = await AdCopyWriter(m).write(brief: 'Charm sumka', photos: 5);
        expect(r.byAi, isTrue);
        expect(r.copy.lines, hasLength(3));
        expect(r.copy.hook, 'Yangi kolleksiya keldi');
        expect('FOTO: '.allMatches(m.grammar!).length, 1);
        expect(m.grammar, contains('foto foto foto'));
        expect(m.prompt, contains('Charm sumka'));
      },
    );

    test(
      'without the on-device model it says so and uses a template',
      () async {
        final r = await AdCopyWriter(null)
            .write(brief: 'Charm sumka', photos: 4);
        expect(r.byAi, isFalse);
        expect(r.copy.lines, hasLength(2));
        expect(r.copy.hook, contains('Charm sumka'));
      },
    );

    test(
      'an unusable answer falls back to the template, not to garbage',
      () async {
        final r = await AdCopyWriter(_Model('nimadir noto‘g‘ri'))
            .write(brief: 'Kofe', photos: 3);
        expect(r.byAi, isFalse);
        expect(r.copy.lines, hasLength(1));
      },
    );
  });

  group('MusicSynth', () {
    test('builds an FFmpeg graph for an exact-length, beat-locked track', () {
      final args = MusicSynth.buildArgs(
        durationSec: 20,
        bpm: 90,
        outPath: '/o.m4a',
      );
      expect(args.last, '/o.m4a');
      expect(args, containsAllInOrder(['-t', '20.000']));
      final graph = args[args.indexOf('-filter_complex') + 1];
      expect(graph, contains('aevalsrc'));
      expect(graph, contains('afade=t=out'));
    });

    test('beat grid starts at zero and spans the track', () {
      final b = MusicSynth.beatTimes(durationSec: 20, bpm: 90);
      expect(b.first, 0);
      expect(b, hasLength(30));
      expect(b.last, lessThan(20));
    });
  });

  group('ProductAdService', () {
    test(
      'photos → copy → music → plan → project → render, all verified',
      () async {
        final repo = _Repo();
        final renderer = _Renderer();
        final music = _Music();
        final stages = <String>[];
        final r =
            await ProductAdService(
              repository: repo,
              renderer: renderer,
              music: music,
              copyWriter: AdCopyWriter(null),
              verify: (_, _) async => const [],
              fileSize: (_) => 1234,
            ).create(
              images: [
                for (final id in _ids(5))
                  ProjectClip(id: id, path: '/p/$id.jpg', name: '$id.jpg'),
              ],
              brief: 'Charm sumka',
              onStage: stages.add,
            );
        expect(r.copyByAi, isFalse);
        expect(music.duration, 20);
        expect(music.bpm, ProductAdComposer.bpm);
        expect(renderer.plan!.durationSec, 20);
        expect(renderer.clips, hasLength(5));
        expect(repo.byId(r.projectId), isNotNull);
        expect(repo.last!.durationSec, 20);
        expect(r.outputPath, '/tmp/out.mp4');
        expect(stages, isNotEmpty);
      },
    );

    test(
      'a render that fails verification is not reported as finished',
      () async {
        final repo = _Repo();
        await expectLater(
          ProductAdService(
            repository: repo,
            renderer: _Renderer(),
            music: _Music(),
            copyWriter: AdCopyWriter(null),
            verify: (_, _) async => const ['duration: 12.0 s'],
            fileSize: (_) => 1,
          ).create(
            images: [
              for (final id in _ids(3))
                ProjectClip(id: id, path: '/p/$id.jpg', name: id),
            ],
            brief: 'Kofe',
          ),
          throwsA(isA<AiException>()),
        );
        expect(repo.last, isNull);
      },
    );
  });

  group('output check', () {
    final plan = EditPlan.fromJson(
      ProductAdComposer.compose(
        clipIds: _ids(3),
        copy: AdCopy(hook: 'A', lines: const ['B'], cta: 'C'),
        title: 't',
        musicPath: '/m.m4a',
      ),
    );

    test('music must really be in the file, for the whole length', () {
      expect(
        adOutputProblems({
          'streams': [
            {'codec_type': 'video'},
            {'codec_type': 'audio', 'duration': '20.01'},
          ],
        }, plan),
        isEmpty,
      );
      expect(
        adOutputProblems({
          'streams': [
            {'codec_type': 'video'},
          ],
        }, plan),
        isNotEmpty,
      );
      expect(
        adOutputProblems({
          'streams': [
            {'codec_type': 'audio', 'duration': '12.0'},
          ],
        }, plan),
        isNotEmpty,
      );
    });
  });

  group('setup sheet', () {
    Future<AdSetup?> open(WidgetTester tester, int photos) async {
      SharedPreferences.setMockInitialValues({});
      final app = AppController(
        keys: MemoryKeyStore(),
        prefs: await SharedPreferences.getInstance(),
      );
      tester.view.physicalSize = const Size(1080, 2400); // 360 x 800 dp
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      AdSetup? result;
      await tester.pumpWidget(
        AppScope(
          controller: app,
          child: MaterialApp(
            theme: buildTheme(Brightness.dark),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async =>
                        result = await showModalBottomSheet<AdSetup>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) =>
                              AdSetupSheet(images: List.filled(photos, null)),
                        ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('fits a 360 dp phone and returns the choices', (tester) async {
      await open(tester, 5);
      expect(tester.takeException(), isNull);
      expect(find.text('Rasmlardan reklama'), findsOneWidget);
      expect(find.textContaining('Kadr AI o‘rnatilmagan'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Charm sumka');
      await tester.tap(find.text('YouTube uchun'));
      await tester.tap(find.text('15 s'));
      await tester.pump();
      await tester.ensureVisible(find.text('Reklama yaratish'));
      await tester.tap(find.text('Reklama yaratish'));
      await tester.pumpAndSettle();
      expect(find.text('Rasmlardan reklama'), findsNothing);
    });

    testWidgets('too many photos for the length disables the button', (
      tester,
    ) async {
      await open(tester, 9);
      await tester.tap(find.text('15 s'));
      await tester.pump();
      expect(find.textContaining('ko‘pi bilan 7 ta rasm'), findsOneWidget);
      final b = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Reklama yaratish'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(b.onPressed, isNull);
    });
  });
}
