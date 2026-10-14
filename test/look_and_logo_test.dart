import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/plan/plan_ops.dart';
import 'package:hookkadr/features/projects/project.dart';
import 'package:hookkadr/features/render/render_plan.dart';

Map<String, dynamic> _json({int fps = 30, String aspect = '9:16'}) => {
  'schemaVersion': 1,
  'title': 'T',
  'summary': 'S',
  'durationSec': 6,
  'aspectRatio': aspect,
  'shots': [
    {
      'id': 's1',
      'startSec': 0,
      'endSec': 3,
      'description': 'A',
      'sourceClipId': 'clip_01',
      'sourceIn': 0,
      'sourceOut': 3,
    },
    {
      'id': 's2',
      'startSec': 3,
      'endSec': 6,
      'description': 'B',
      'sourceClipId': 'clip_01',
      'sourceIn': 3,
      'sourceOut': 6,
    },
  ],
  'mediaSlots': <Map<String, dynamic>>[],
  'captions': <Map<String, dynamic>>[],
  'audioTracks': <Map<String, dynamic>>[],
  'export': {'resolution': '1080p', 'fps': fps},
};

const _clips = [
  ProjectClip(id: 'clip_01', path: '/tmp/a.mp4', name: 'a.mp4'),
  ProjectClip(id: 'clip_02', path: '/tmp/logo.png', name: 'logo.png'),
];

RenderArgs _build(EditPlan plan, {String res = '1080p', Set<String>? audio}) =>
    buildRenderArgs(
      plan: plan,
      clips: _clips,
      hasAudio: audio ?? {'clip_01'},
      fontPath: '/tmp/Inter.ttf',
      textDir: '/tmp/t',
      outputPath: '/tmp/out.mp4',
      videoEncoder: 'h264_videotoolbox',
      resolution: res,
    );

String _filter(RenderArgs r) => r.args[r.args.indexOf('-filter_complex') + 1];

void main() {
  group('ColorGrade', () {
    test('parses, validates ranges and reports neutrality', () {
      final g = ColorGrade.fromJson({'contrast': 1.2, 'temperature': 0.3});
      expect(g.isNeutral, isFalse);
      expect(const ColorGrade().isNeutral, isTrue);
      expect(
        () => ColorGrade.fromJson({'contrast': 3}),
        throwsA(isA<EditPlanFormatException>()),
      );
      expect(
        () => ColorGrade.fromJson({'temperature': -2}),
        throwsA(isA<EditPlanFormatException>()),
      );
    });

    test('plan with invalid grade is rejected', () {
      final j = _json()..['grade'] = {'saturation': 9};
      expect(
        () => EditPlan.fromJson(j),
        throwsA(isA<EditPlanFormatException>()),
      );
    });

    test('filter uses only LGPL filters (no eq) and omits no-op parts', () {
      final f = gradeFilter(ColorGrade.presets['kino']!);
      expect(f, contains('lutyuv=y='));
      expect(f, contains('hue=s=0.900'));
      expect(f, contains('colorbalance='));
      expect(f, isNot(contains('eq=')));
      expect(gradeFilter(const ColorGrade(saturation: 1.3)), 'hue=s=1.300');
    });

    test('is applied between the timeline and the captions', () {
      final j = PlanOps.setGrade(_json(), ColorGrade.presets['iliq']);
      final r = _build(EditPlan.fromJson(j));
      final f = _filter(r);
      expect(f, contains('hue=s=1.100'));
      expect(f, contains('[vc]'));
      final neutral = _filter(_build(EditPlan.fromJson(_json())));
      expect(neutral, contains('null[vc]'));
    });
  });

  group('LogoEndCard', () {
    test('validates ranges and fits the video', () {
      expect(
        () => LogoEndCard.fromJson({'clipId': 'c', 'durationSec': 9}),
        throwsA(isA<EditPlanFormatException>()),
      );
      final j = _json()..['logo'] = {'clipId': 'clip_02', 'durationSec': 5};
      j['durationSec'] = 3; // shorter than logo
      j['shots'] = [
        {
          'id': 's1',
          'startSec': 0,
          'endSec': 3,
          'description': 'A',
          'sourceClipId': 'clip_01',
          'sourceIn': 0,
          'sourceOut': 3,
        },
      ];
      expect(
        () => EditPlan.fromJson(j),
        throwsA(isA<EditPlanFormatException>()),
      );
    });

    test('is overlaid on the last N seconds as an extra input', () {
      final j = PlanOps.setLogo(_json(), 'clip_02', seconds: 2);
      final r = _build(EditPlan.fromJson(j));
      final a = r.args;
      // clip_01 (video) + logo image looped
      expect(a.where((x) => x == '-i').length, 2);
      expect(a, containsAllInOrder(['-loop', '1', '-framerate', '30']));
      expect(a, contains('/tmp/logo.png'));
      final f = _filter(r);
      expect(f, contains('[1:v]format=rgba'));
      expect(f, contains('fade=t=in:st=0:d=0.400:alpha=1'));
      expect(f, contains('setpts=PTS-STARTPTS+4.000/TB[logo]'));
      expect(f, contains("enable='between(t,4.000,6.000)'"));
      expect(r.args.last, '/tmp/out.mp4');
    });

    test('a logo that is not an image clip is ignored, never mis-mapped', () {
      final j = PlanOps.setLogo(_json(), 'clip_01');
      final r = _build(EditPlan.fromJson(j));
      expect(_filter(r), isNot(contains('[logo]')));
    });

    test('music input index shifts past the logo input', () {
      var j = PlanOps.setLogo(_json(), 'clip_02');
      j = PlanOps.setMusic(j, {'path': '/tmp/m.mp3', 'name': 'm.mp3'});
      final f = _filter(_build(EditPlan.fromJson(j)));
      expect(f, contains('[2:a]atrim'));
    });
  });

  group('Format', () {
    test('3:4 is supported and sized correctly', () {
      expect(outputSize('3:4', '1080p'), (width: 1080, height: 1440));
      final plan = EditPlan.fromJson(_json(aspect: '3:4'));
      expect(plan.aspectRatio, '3:4');
    });

    test('fps comes from the plan and is validated', () {
      final r = _build(EditPlan.fromJson(_json(fps: 24)));
      final a = r.args;
      expect(a[a.indexOf('-r') + 1], '24');
      expect(_filter(r), contains('fps=24'));
      expect(
        () => EditPlan.fromJson(_json(fps: 45)),
        throwsA(isA<EditPlanFormatException>()),
      );
    });

    test('setFormat rejects unsupported values', () {
      expect(() => PlanOps.setFormat(_json(), fps: 120), throwsArgumentError);
      expect(
        () => PlanOps.setFormat(_json(), aspectRatio: '21:9'),
        throwsArgumentError,
      );
      final j = PlanOps.setFormat(_json(), aspectRatio: '1:1', fps: 60);
      expect(j['aspectRatio'], '1:1');
      expect((j['export'] as Map)['fps'], 60);
    });
  });

  test('PlanOps grade/logo never mutate the input and can be removed', () {
    final base = _json();
    final withGrade = PlanOps.setGrade(base, ColorGrade.presets['kino']);
    expect(base.containsKey('grade'), isFalse);
    expect(withGrade.containsKey('grade'), isTrue);
    expect(PlanOps.setGrade(withGrade, null).containsKey('grade'), isFalse);
    final withLogo = PlanOps.setLogo(base, 'clip_02');
    expect(PlanOps.setLogo(withLogo, null).containsKey('logo'), isFalse);
    // survives a full parse
    expect(EditPlan.fromJson(withLogo).logo!.clipId, 'clip_02');
  });
}
