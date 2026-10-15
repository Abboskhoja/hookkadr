import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/plan/plan_ops.dart';
import 'package:hookkadr/features/plan/ripple_trim.dart';
import 'package:hookkadr/features/projects/project.dart';
import 'package:hookkadr/features/render/render_plan.dart';

/// Three shots: s1 0–4 (clip_01 from 1 s), s2 4–9 (clip_02, 2× speed),
/// s3 9–12 (clip_03). One caption on each shot, a music bed under it all.
Map<String, dynamic> _plan({int fps = 30}) => {
  'schemaVersion': 1,
  'title': 'T',
  'summary': 'S',
  'durationSec': 12.0,
  'aspectRatio': '9:16',
  'shots': [
    {
      'id': 's1',
      'startSec': 0.0,
      'endSec': 4.0,
      'description': 'a',
      'sourceClipId': 'clip_01',
      'sourceIn': 1.0,
      'sourceOut': 5.0,
    },
    {
      'id': 's2',
      'startSec': 4.0,
      'endSec': 9.0,
      'description': 'b',
      'sourceClipId': 'clip_02',
      'sourceIn': 0.0,
      'sourceOut': 10.0,
      'speed': 2.0,
      'transition': 'crossfade',
      'transitionSec': 0.8,
    },
    {
      'id': 's3',
      'startSec': 9.0,
      'endSec': 12.0,
      'description': 'c',
      'sourceClipId': 'clip_03',
      'sourceIn': 0.0,
      'sourceOut': 3.0,
    },
  ],
  'mediaSlots': <Map<String, dynamic>>[],
  'captions': [
    {'startSec': 1.0, 'endSec': 3.0, 'text': 'birinchi'},
    {'startSec': 5.0, 'endSec': 8.0, 'text': 'ikkinchi'},
    {'startSec': 9.5, 'endSec': 11.5, 'text': 'uchinchi'},
  ],
  'audioTracks': [
    {
      'kind': 'voiceover',
      'startSec': 6.0,
      'endSec': 8.0,
      'description': 'ovoz',
    },
  ],
  'export': {'resolution': '1080p', 'fps': fps},
};

List<Shot> _shots(Map<String, dynamic> p) => EditPlan.fromJson(p).shots;
List<Caption> _caps(Map<String, dynamic> p) => EditPlan.fromJson(p).captions;

TrimResult _tail(
  Map<String, dynamic> p,
  String id,
  double delta, {
  int fps = 30,
  double? sourceLimit,
  List<double> snap = const [],
  double window = 0,
}) => RippleTrim.apply(
  p,
  shotId: id,
  edge: TrimEdge.tail,
  deltaSec: delta,
  fps: fps,
  sourceLimit: sourceLimit,
  snapTargets: snap,
  snapWindowSec: window,
);

void main() {
  group('tail trim (right handle)', () {
    test('lengthens the shot and ripples everything after it', () {
      final r = _tail(_plan(), 's1', 1.0);
      final s = _shots(r.plan);
      expect(s[0].endSec, 5.0);
      expect(s[0].sourceOut, 6.0, reason: 'source range follows');
      expect(s[1].startSec, 5.0);
      expect(s[2].startSec, 10.0);
      expect(EditPlan.fromJson(r.plan).durationSec, 13.0);
      expect(r.changed, isTrue);
    });

    test('shortens without leaving gaps', () {
      final r = _tail(_plan(), 's1', -1.5);
      final s = _shots(r.plan);
      expect(s[0].duration, 2.5);
      expect(s[1].startSec, 2.5);
      expect(s[2].endSec, 10.5);
    });

    test('never shorter than the minimum shot', () {
      final r = _tail(_plan(), 's1', -10);
      expect(r.duration, PlanOps.minShot);
    });

    test('stops at the end of the source footage', () {
      // clip_01 is 6 s long and the shot starts at 1 s: at most 5 s.
      final r = _tail(_plan(), 's1', 20, sourceLimit: 6);
      expect(r.duration, 5.0);
      expect(_shots(r.plan)[0].sourceOut, 6.0);
    });

    test('a 2× shot reaches the source end twice as fast', () {
      // clip_02 is 12 s: from 0 s at 2× that's 6 s of timeline.
      final r = _tail(_plan(), 's2', 20, sourceLimit: 12);
      expect(r.duration, 6.0);
      expect(_shots(r.plan)[1].sourceOut, 12.0);
    });

    test('moves in whole frames at 24, 25, 30 and 60 fps', () {
      for (final fps in const [24, 25, 30, 60]) {
        final r = _tail(_plan(fps: fps), 's1', 0.4123, fps: fps);
        final frames = r.duration * fps;
        expect(
          (frames - frames.roundToDouble()).abs(),
          lessThan(0.31),
          reason: '$fps fps: ${r.duration}s is not a whole number of frames',
        );
        expect(EditPlan.fromJson(r.plan).export.fps, fps);
      }
    });

    test('snaps to the playhead within the window, with a signal', () {
      final r = _tail(_plan(), 's1', 0.95, snap: [5.0], window: 0.1);
      expect(_shots(r.plan)[0].endSec, 5.0);
      expect(r.snappedAt, 5.0);
      final far = _tail(_plan(), 's1', 0.5, snap: [5.0], window: 0.1);
      expect(far.snappedAt, isNull);
    });

    test('a source limit beats a snap target', () {
      final r = _tail(
        _plan(),
        's1',
        3,
        sourceLimit: 6,
        snap: [7.0],
        window: 0.5,
      );
      expect(r.duration, 5.0);
      expect(r.snappedAt, isNull);
    });

    test('a tiny drag is not a change', () {
      expect(_tail(_plan(), 's1', 0.01).changed, isFalse);
    });

    test('the preview edge is the last frame of the shot', () {
      final r = _tail(_plan(), 's1', 1.0);
      expect(r.edgeSec, closeTo(5.0 - 1 / 30, 1e-9));
    });
  });

  group('head trim (left handle)', () {
    TrimResult head(Map<String, dynamic> p, String id, double d) =>
        RippleTrim.apply(
          p,
          shotId: id,
          edge: TrimEdge.head,
          deltaSec: d,
          fps: 30,
        );

    test('removes footage from the head; the shot keeps its place', () {
      final r = head(_plan(), 's1', 1.0);
      final s = _shots(r.plan);
      expect(s[0].startSec, 0.0);
      expect(s[0].sourceIn, 2.0);
      expect(s[0].duration, 3.0);
      expect(s[1].startSec, 3.0);
    });

    test('timeline seconds are converted for a 2× shot', () {
      // Dragging 1 s of timeline on a 2× shot removes 2 s of source.
      final r = head(_plan(), 's2', 1.0);
      final s = _shots(r.plan)[1];
      expect(s.sourceIn, 2.0);
      expect(s.duration, 4.0);
    });

    test('cannot reveal footage before the clip starts', () {
      final r = head(_plan(), 's1', -5);
      final s = _shots(r.plan)[0];
      expect(s.sourceIn, 0.0);
      expect(s.duration, 5.0);
    });

    test('a shot without source footage is left alone', () {
      final p = _plan();
      (p['shots'] as List)[2]
        ..remove('sourceIn')
        ..remove('sourceOut');
      final r = head(p, 's3', 1.0);
      expect(r.changed, isFalse);
    });
  });

  group('everything else on the timeline', () {
    test('captions follow their shots', () {
      final c = _caps(_tail(_plan(), 's1', -1.0).plan);
      expect(c[0].startSec, 1.0); // on s1, still inside it
      expect(c[0].endSec, 3.0);
      expect(c[1].startSec, 4.0); // on s2: moved 1 s earlier with it
      expect(c[1].endSec, 7.0);
      expect(c[2].startSec, 8.5); // on s3
      expect(c[2].endSec, 10.5);
    });

    test('a caption on a shortened shot is clipped to it', () {
      final c = _caps(_tail(_plan(), 's1', -2.0).plan);
      expect(c[0].endSec, 2.0);
    });

    test('a caption whose footage is trimmed away is dropped', () {
      final p = _plan();
      (p['captions'] as List)[0] = {
        'startSec': 3.0,
        'endSec': 3.9,
        'text': 'oxiri',
      };
      final c = _caps(_tail(p, 's1', -3.0).plan);
      expect(c.map((x) => x.text), isNot(contains('oxiri')));
    });

    test('audio beds keep absolute time, clipped to the new length', () {
      final a = EditPlan.fromJson(_tail(_plan(), 's3', -2.5).plan).audioTracks;
      expect(a.single.startSec, 6.0);
      expect(a.single.endSec, 8.0);
    });

    test('every preview is a valid plan the renderer accepts', () {
      for (final d in const [-10.0, -2.0, -0.3, 0.0, 0.7, 4.0, 40.0]) {
        for (final id in const ['s1', 's2', 's3']) {
          expect(
            () => EditPlan.fromJson(_tail(_plan(), id, d).plan),
            returnsNormally,
            reason: '$id $d',
          );
        }
      }
    });

    test('a transition can never be longer than half a trimmed shot', () {
      // s1 cut to its minimum (0.5 s) while s2 carries a 0.8 s crossfade.
      final plan = EditPlan.fromJson(_tail(_plan(), 's1', -10).plan);
      final args = buildRenderArgs(
        plan: plan,
        clips: const [
          ProjectClip(id: 'clip_01', path: '/a.mp4', name: 'a'),
          ProjectClip(id: 'clip_02', path: '/b.mp4', name: 'b'),
          ProjectClip(id: 'clip_03', path: '/c.mp4', name: 'c'),
        ],
        hasAudio: const {},
        fontPath: '/f.ttf',
        textDir: '/t',
        outputPath: '/o.mp4',
        videoEncoder: 'libx264',
        resolution: '1080p',
      ).args;
      final filter = args[args.indexOf('-filter_complex') + 1];
      final m = RegExp(r'xfade=[^:]+:duration=([\d.]+)').firstMatch(filter)!;
      expect(double.parse(m.group(1)!), lessThanOrEqualTo(0.25));
    });

    test('the start plan is never mutated (cancel = drop the preview)', () {
      final start = _plan();
      final before = start.toString();
      _tail(start, 's1', 2.0);
      RippleTrim.apply(
        start,
        shotId: 's1',
        edge: TrimEdge.head,
        deltaSec: 1,
        fps: 30,
      );
      expect(start.toString(), before);
    });
  });
}
