import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/plan/auto_editor.dart';
import 'package:hookkadr/features/projects/project.dart';
import 'package:hookkadr/features/render/grade_preview.dart';
import 'package:hookkadr/features/render/media_analyzer.dart';
import 'package:hookkadr/features/render/render_plan.dart';

const _a = ClipFacts(id: 'clip_01', durationSec: 20, sceneCuts: [4, 9, 14]);
const _b = ClipFacts(id: 'clip_02', durationSec: 20, sceneCuts: [6, 12]);

Map<String, dynamic> _build(AutoStyle? style, {int sec = 20}) =>
    AutoEditor.build(
      clips: const [_a, _b],
      targetSec: sec,
      aspectRatio: '9:16',
      resolution: '1080p',
      title: 'T',
      style: style,
    );

void main() {
  test('no style keeps the plain cut-only montage (backwards compatible)', () {
    final plan = EditPlan.fromJson(_build(null));
    expect(plan.grade, isNull);
    expect(plan.shots.every((s) => s.transition == ShotTransition.cut), isTrue);
    expect(plan.shots.every((s) => s.motion == ShotMotion.none), isTrue);
  });

  for (final style in AutoStyle.values) {
    test('${style.name}: valid plan with grade, within target length', () {
      final plan = EditPlan.fromJson(_build(style));
      expect(plan.grade, isNotNull);
      expect(plan.grade!.isNeutral, isFalse);
      expect(plan.durationSec, closeTo(20, 1.5));
      // Same footage is never reused: ranges per clip do not overlap.
      for (final id in ['clip_01', 'clip_02']) {
        final r = [
          for (final s in plan.shots)
            if (s.sourceClipId == id) (s.sourceIn!, s.sourceOut!),
        ]..sort((x, y) => x.$1.compareTo(y.$1));
        for (var i = 1; i < r.length; i++) {
          expect(r[i].$1, greaterThanOrEqualTo(r[i - 1].$2 - 0.01));
        }
      }
    });
  }

  test('kino fades in, crossfades and slow-zooms; dinamik stays on cuts', () {
    final kino = EditPlan.fromJson(_build(AutoStyle.kino));
    expect(kino.shots.first.transition, ShotTransition.fadeBlack);
    expect(
      kino.shots.any((s) => s.transition == ShotTransition.crossfade),
      isTrue,
    );
    expect(kino.shots.every((s) => s.motion == ShotMotion.slowZoom), isTrue);

    final din = EditPlan.fromJson(_build(AutoStyle.dinamik));
    expect(din.shots.every((s) => s.transition == ShotTransition.cut), isTrue);
    expect(din.shots.any((s) => s.motion == ShotMotion.punchIn), isTrue);
    // Dynamic pacing is faster than cinematic.
    expect(din.shots.length, greaterThan(kino.shots.length));
  });

  test('a styled plan renders xfade, zoompan and the grade filter', () {
    final plan = EditPlan.fromJson(_build(AutoStyle.kino));
    final r = buildRenderArgs(
      plan: plan,
      clips: const [
        ProjectClip(id: 'clip_01', path: '/tmp/a.mp4', name: 'a'),
        ProjectClip(id: 'clip_02', path: '/tmp/b.mp4', name: 'b'),
      ],
      hasAudio: const {},
      fontPath: '/tmp/f.ttf',
      textDir: '/tmp/t',
      outputPath: '/tmp/o.mp4',
      videoEncoder: 'h264_videotoolbox',
      resolution: '720p',
    );
    final f = r.args[r.args.indexOf('-filter_complex') + 1];
    expect(f, contains('xfade='));
    expect(f, contains('zoompan='));
    expect(f, contains('colorbalance='));
    expect(f, contains('fade=t=in'));
  });

  group('gradeColorMatrix (preview matches export)', () {
    test('neutral grade is the identity', () {
      final m = gradeColorMatrix(const ColorGrade());
      expect(m, [
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    });

    test('zero saturation makes every channel the same luma', () {
      final m = gradeColorMatrix(const ColorGrade(saturation: 0));
      expect(m.sublist(0, 3), m.sublist(5, 8));
      expect(m.sublist(0, 3), m.sublist(10, 13));
    });

    test('warm temperature lifts red and lowers blue', () {
      final m = gradeColorMatrix(const ColorGrade(temperature: 1));
      expect(m[4], greaterThan(0));
      expect(m[14], lessThan(0));
      expect(m[9], 0);
    });

    test('contrast scales around mid grey and exposure brightens', () {
      final m = gradeColorMatrix(
        const ColorGrade(contrast: 1.5, exposure: 0.1),
      );
      expect(m[0], 1.5);
      expect(m[4], closeTo(128 * -0.5 + 10, 1e-9));
    });
  });
}
