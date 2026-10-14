import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/ai/ai_clients.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/director/capability_registry.dart';
import 'package:hookkadr/features/director/hook_engine.dart';
import 'package:hookkadr/features/director/kadr_director.dart';
import 'package:hookkadr/features/director/quality_control.dart';
import 'package:hookkadr/features/montage/application/montage_service.dart';
import 'package:hookkadr/features/projects/project.dart';
import 'package:hookkadr/features/render/media_analyzer.dart';
import 'package:hookkadr/features/vision/scene_quality_scanner.dart';

Map<String, dynamic> _plan({
  double firstLen = 4,
  List<Map<String, dynamic>> captions = const [],
  Map<String, dynamic>? music,
  bool cards = false,
}) {
  final shots = <Map<String, dynamic>>[];
  var t = 0.0;
  final lens = [firstLen, 4, 4, 4, 4];
  for (var i = 0; i < 5; i++) {
    shots.add({
      'id': 's${i + 1}',
      'startSec': t,
      'endSec': t + lens[i],
      'description': 'Kadr ${i + 1}',
      if (!(cards && i == 4)) 'sourceClipId': 'clip_01',
      if (!(cards && i == 4)) 'sourceIn': i * 4.0,
      if (!(cards && i == 4)) 'sourceOut': i * 4.0 + lens[i],
    });
    t += lens[i];
  }
  return {
    'schemaVersion': 1,
    'title': 'Premium kafel',
    'summary': 'Kafel reklamasi',
    'durationSec': t,
    'aspectRatio': '9:16',
    'shots': shots,
    'mediaSlots': <Map<String, dynamic>>[],
    'captions': captions,
    'audioTracks': <Map<String, dynamic>>[],
    'export': {'resolution': '1080p', 'fps': 30},
    'music': ?music,
  };
}

class _FakeAnalyzer implements ClipAnalyzer {
  @override
  Future<ClipFacts> analyze(String id, String path) async =>
      ClipFacts(id: id, durationSec: 20, sceneCuts: const [5, 10, 15]);
}

class _QualityAnalyzer implements TechnicalQualityAnalyzer {
  _QualityAnalyzer({this.fail = false});
  final bool fail;
  @override
  Future<TechnicalQualityReport> scan(String path) async {
    if (fail) throw const FormatException('bad media');
    return const TechnicalQualityReport(
      modelVersion: 'test',
      samples: 2,
      meanQuality: 0.75,
      flags: {'blurry': 1},
    );
  }
}

const _clips = [
  ProjectClip(id: 'clip_01', path: '/a.mp4', name: 'a', durationSec: 30),
  ProjectClip(id: 'clip_02', path: '/b.mp4', name: 'b', durationSec: 20),
];

Set<String> _codes(List<QcFinding> f) => {for (final x in f) x.code};

void main() {
  group('understand', () {
    final cases = {
      'Videoni 20 soniyaga qisqartir': DirectorGoal.edit,
      'kino uslubini ber': DirectorGoal.edit,
      'sifatni tekshir': DirectorGoal.review,
      'xatolarni top': DirectorGoal.review,
      'hook yoz': DirectorGoal.hooks,
      '2-hookni qo‘y': DirectorGoal.hooks,
      'hook variantlarini ber': DirectorGoal.hooks,
      'qaytadan montaj qil kino uslubida': DirectorGoal.remontage,
      'kafel rasmi yarat': DirectorGoal.generateImage,
      'rasm chiz: oshxona': DirectorGoal.generateImage,
      'reklama uchun rasm yarat': DirectorGoal.generateImage,
      'AI video yarat': DirectorGoal.generateVideo,
      'Menga 30 soniyalik premium avtomobil reklamasi yarat':
          DirectorGoal.production,
      'Reklama storyboardini tuz': DirectorGoal.production,
    };
    cases.forEach((text, goal) {
      test('"$text" → ${goal.name}', () {
        expect(KadrDirector.understand(text), goal);
      });
    });
  });

  group('QualityControl', () {
    test('clean plan with hook text and CTA has no problems', () {
      final plan = EditPlan.fromJson(
        _plan(
          firstLen: 2,
          captions: [
            {'startSec': 0.2, 'endSec': 2.4, 'text': 'Tanishing: kafel'},
            {'startSec': 15.5, 'endSec': 17.8, 'text': 'Bog‘laning'},
          ],
          music: {'path': '/m', 'name': 'm', 'volume': 0.3},
        ),
      );
      final f = QualityControl.check(plan, knownClipIds: {'clip_01'});
      expect(f.where((x) => x.severity == Severity.problem), isEmpty);
      expect(_codes(f), isNot(contains('slow_open')));
    });

    test('finds slow opening, no hook text, no CTA', () {
      final f = QualityControl.check(EditPlan.fromJson(_plan(firstLen: 5)));
      expect(_codes(f), containsAll(['slow_open', 'no_hook_text', 'no_cta']));
      expect(f.firstWhere((x) => x.code == 'slow_open').fix, isNotNull);
    });

    test('unreadable and overlapping captions are problems', () {
      final f = QualityControl.check(
        EditPlan.fromJson(
          _plan(
            captions: [
              {
                'startSec': 1,
                'endSec': 1.5,
                'text': 'Bu juda uzun matn bir yarim soniyada ko‘rinadi',
              },
              {'startSec': 1.2, 'endSec': 3, 'text': 'Ustiga tushadi'},
            ],
          ),
        ),
      );
      expect(_codes(f), containsAll(['caption_fast', 'caption_overlap']));
    });

    test('missing media, unknown clip, range outside, repeated footage', () {
      final plan = _plan(cards: true);
      // shot s2 reuses the footage of s1
      (plan['shots'] as List)[1]['sourceIn'] = 0.5;
      (plan['shots'] as List)[1]['sourceOut'] = 4.0;
      final f = QualityControl.check(
        EditPlan.fromJson(plan),
        clipDurations: {'clip_01': 12},
        knownClipIds: {'clip_99'},
      );
      expect(
        _codes(f),
        containsAll([
          'missing_media',
          'unknown_clip',
          'range_outside',
          'repeated_footage',
        ]),
      );
      // most serious first
      expect(f.first.severity, Severity.problem);
    });

    test('loud music is flagged', () {
      final f = QualityControl.check(
        EditPlan.fromJson(
          _plan(music: {'path': '/m', 'name': 'm', 'volume': 0.9}),
        ),
      );
      expect(_codes(f), contains('music_loud'));
    });
  });

  group('HookEngine', () {
    test('five distinct, short, claim-free variants', () {
      final v = HookEngine.generate(topic: 'premium kafel');
      expect(v.length, 5);
      expect({for (final x in v) x.text}.length, 5);
      expect({for (final x in v) x.style}.length, 5);
      for (final x in v) {
        expect(x.text.length, lessThanOrEqualTo(60), reason: x.text);
        final low = x.text.toLowerCase();
        for (final banned in ['100%', 'kafolat', 'eng yaxshi', 'bepul', '!!']) {
          expect(low, isNot(contains(banned)), reason: x.text);
        }
        expect(x.visual, isNotEmpty);
      }
    });

    test('kind changes the lead style', () {
      expect(HookEngine.kindOf('kafel reklamasi'), AdKind.interior);
      expect(HookEngine.kindOf('restoran taomi'), AdKind.food);
      final a = HookEngine.generate(topic: 'kafel');
      final b = HookEngine.generate(topic: 'restoran taomi');
      expect(a.first.style, isNot(b.first.style));
    });
  });

  group('KadrDirector', () {
    final director = KadrDirector(
      connected: {ProviderKind.offline},
      analyzer: _FakeAnalyzer(),
    );

    test(
      'production compiles measured media and preserves original plan',
      () async {
        final original = _plan();
        final r = await director.handle(
          'Menga 10 soniyalik premium avtomobil reklamasi yarat',
          plan: original,
          clips: _clips,
        );
        expect(r.goal, DirectorGoal.production);
        expect(r.changedPlan, isTrue);
        expect(r.plan['production']['brief']['subject'], 'premium avtomobil');
        expect(EditPlan.fromJson(r.plan).durationSec, 10);
        expect(original.containsKey('production'), isFalse);
        expect(
          r.steps.where((s) => s.tool == 'render').single.status,
          StepStatus.blocked,
        ); // Plan prepared; render has not been run.
      },
    );

    test(
      'production without analyzer creates honest unfilled storyboard',
      () async {
        final r = await KadrDirector().handle(
          'Reklama storyboardini tuz',
          plan: _plan(),
          clips: _clips,
        );
        expect(r.plan['production']['metrics']['mediaCoverage'], 0);
        expect(r.blocked.any((s) => s.contains('o‘lchab bo‘lmadi')), isTrue);
      },
    );

    test('invalid production request preserves original project', () async {
      final original = _plan();
      final r = await director.handle(
        '500 soniyalik reklama yarat',
        plan: original,
      );
      expect(r.changedPlan, isFalse);
      expect(identical(r.plan, original), isTrue);
      expect(r.steps.single.status, StepStatus.failed);
    });

    test(
      'review reports actual scanner results without modifying timeline',
      () async {
        final original = _plan();
        final r = await KadrDirector(qualityAnalyzer: _QualityAnalyzer())
            .handle('Sifatni tekshir', plan: original, clips: _clips);
        expect(r.changedPlan, isFalse);
        expect(identical(r.plan, original), isTrue);
        expect(r.steps.where((s) => s.tool == 'scene_quality'), hasLength(2));
        expect(r.done.join(' '), contains('75/100'));
        expect(r.done.join(' '), contains('xira: 1/2'));
      },
    );

    test('failed scanner produces blocked evidence, never a score', () async {
      final r = await KadrDirector(
        qualityAnalyzer: _QualityAnalyzer(fail: true),
      ).handle('Sifatni tekshir', plan: _plan(), clips: _clips);
      expect(
        r.steps
            .where((s) => s.tool == 'scene_quality')
            .every((s) => s.status == StepStatus.blocked),
        isTrue,
      );
      expect(r.done.join(' '), isNot(contains('/100')));
    });

    test('edit runs the command, validates and surfaces QC problems', () async {
      final r = await director.handle(
        'Oxirgi kadrni o‘chir',
        plan: _plan(cards: true),
        clips: _clips,
      );
      expect(r.changedPlan, isTrue);
      expect(EditPlan.fromJson(r.plan).shots.length, 4);
      // The card shot was the last one: its problem disappears with it.
      expect(_codes(r.findings), isNot(contains('missing_media')));
    });

    test('edit that leaves a problem reports it', () async {
      final r = await director.handle(
        'kino uslubini ber',
        plan: _plan(cards: true),
        clips: _clips,
      );
      expect(r.changedPlan, isTrue);
      expect(_codes(r.findings), contains('missing_media'));
    });

    test('review changes nothing', () async {
      final plan = _plan(firstLen: 5);
      final r = await director.handle(
        'sifatni tekshir',
        plan: plan,
        clips: _clips,
      );
      expect(r.changedPlan, isFalse);
      expect(r.plan, plan);
      expect(_codes(r.findings), contains('slow_open'));
    });

    test(
      'hooks: list does not change the plan, apply does and replaces',
      () async {
        final plan = _plan(
          captions: [
            {'startSec': 0.1, 'endSec': 2, 'text': 'Eski hook'},
            {'startSec': 10, 'endSec': 12, 'text': 'Qoladi'},
          ],
        );
        final list = await director.handle(
          'hook variantlarini ber',
          plan: plan,
        );
        expect(list.changedPlan, isFalse);
        expect(list.done.length, greaterThanOrEqualTo(5));

        final set = await director.handle('2-hookni qo‘y', plan: plan);
        expect(set.changedPlan, isTrue);
        final p = EditPlan.fromJson(set.plan);
        final opening = p.captions.where((c) => c.startSec < 1).toList();
        expect(opening.length, 1);
        expect(opening.single.text, isNot('Eski hook'));
        expect(p.captions.any((c) => c.text == 'Qoladi'), isTrue);
        expect(p.shots.first.motion, ShotMotion.punchIn);
      },
    );

    test(
      'remontage rebuilds from clips, keeps music, drops stale captions',
      () async {
        final plan = _plan(
          music: {'path': '/m', 'name': 'm', 'volume': 0.3},
          captions: [
            {'startSec': 1, 'endSec': 3, 'text': 'Eski'},
          ],
        );
        final r = await director.handle(
          'qaytadan montaj qil 12 soniya kino uslubida',
          plan: plan,
          clips: _clips,
        );
        expect(r.changedPlan, isTrue);
        final p = EditPlan.fromJson(r.plan);
        expect(p.durationSec, closeTo(12, 1.5));
        expect(p.music!.path, '/m');
        expect(p.grade, isNotNull);
        expect(p.captions, isEmpty);
        expect(r.blocked.single, contains('Eski 1 ta matn'));
      },
    );

    test('remontage without clips fails honestly', () async {
      final r = await director.handle('qaytadan montaj qil', plan: _plan());
      expect(r.changedPlan, isFalse);
      expect(r.steps.single.status, StepStatus.failed);
    });

    test('generation is never faked', () async {
      final none = await director.handle('kafel rasmi yarat', plan: _plan());
      expect(none.changedPlan, isFalse);
      expect(none.blocked.single, contains('yaratib bo‘lmaydi'));
      expect(none.blocked.single, contains('Gemini'));

      final withGemini = await KadrDirector(connected: {ProviderKind.gemini})
          .handle('kafel rasmi yarat', plan: _plan());
      expect(withGemini.changedPlan, isFalse);
      expect(withGemini.blocked.single, contains('Gemini orqali'));

      final video = await director.handle('AI video yarat', plan: _plan());
      expect(video.blocked.single, contains('yaratib bo‘lmaydi'));
    });
  });

  group('CapabilityRegistry', () {
    test('video understanding prefers Gemini (hears audio) over Claude', () {
      final best = CapabilityRegistry.best(AiTask.videoUnderstanding, {
        ProviderKind.claude,
        ProviderKind.gemini,
      });
      expect(best!.provider, ProviderKind.gemini);
      expect(
        CapabilityRegistry.best(AiTask.videoUnderstanding, {
          ProviderKind.claude,
        })!.provider,
        ProviderKind.claude,
      );
    });

    test('nothing connected → nothing available, never a fake capability', () {
      expect(CapabilityRegistry.available(AiTask.imageGeneration, {}), isEmpty);
      expect(
        CapabilityRegistry.best(AiTask.videoGeneration, {ProviderKind.claude}),
        isNull,
      );
      expect(CapabilityRegistry.missing(AiTask.speechToText), contains('yo‘q'));
    });
  });
}
