import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/plan/plan_ops.dart';
import 'package:hookkadr/features/projects/project.dart';
import 'package:hookkadr/features/render/beat_detector.dart';
import 'package:hookkadr/features/render/render_plan.dart';

Map<String, dynamic> _plan() => {
  'schemaVersion': 1,
  'title': 'T',
  'summary': 'S',
  'durationSec': 9.0,
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
      'sourceOut': 5.0,
    },
  ],
  'mediaSlots': <Map<String, dynamic>>[],
  'captions': <Map<String, dynamic>>[],
  'audioTracks': <Map<String, dynamic>>[],
  'export': {'resolution': '1080p', 'fps': 30},
};

List<Shot> _shots(Map<String, dynamic> p) => EditPlan.fromJson(p).shots;

void main() {
  group('studio operations keep a valid plan', () {
    test('split at the playhead creates two shots with matching sources', () {
      final p = PlanOps.splitAt(_plan(), 1.5)!;
      final s = _shots(p);
      expect(s.map((x) => x.id), ['s1', 's3', 's2']);
      expect(s[0].endSec, 1.5);
      expect(s[0].sourceOut, 2.5);
      expect(s[1].sourceIn, 2.5);
      expect(s[1].sourceOut, 5.0);
      expect(EditPlan.fromJson(p).durationSec, 9);
    });

    test('split too close to an edge is refused', () {
      expect(PlanOps.splitAt(_plan(), 0.2), isNull);
    });

    test('duplicate and move reorder without gaps', () {
      final d = PlanOps.duplicate(_plan(), 's1');
      expect(_shots(d).map((x) => x.id), ['s1', 's3', 's2']);
      expect(EditPlan.fromJson(d).durationSec, 13);
      final m = PlanOps.move(_plan(), 's2', -1);
      final s = _shots(m);
      expect(s.map((x) => x.id), ['s2', 's1']);
      expect(s.first.startSec, 0);
      expect(s.last.endSec, 9);
    });

    test('trim start removes footage from the head and ripples', () {
      final p = PlanOps.trimStart(_plan(), 's1', 1.0);
      final s = _shots(p);
      expect(s[0].sourceIn, 2.0);
      expect(s[0].duration, 3.0);
      expect(s[1].startSec, 3.0);
    });

    test('resize keeps the source range in step', () {
      final s = _shots(PlanOps.resizeShot(_plan(), 's1', 2));
      expect(s[0].sourceOut, 3.0);
    });

    test('captions can be added, edited and removed', () {
      var p = PlanOps.addCaption(
        _plan(),
        startSec: 1,
        endSec: 3,
        text: 'Salom',
      );
      p = PlanOps.updateCaption(p, 0, 'Assalomu alaykum');
      expect(EditPlan.fromJson(p).captions.single.text, 'Assalomu alaykum');
      expect(EditPlan.fromJson(PlanOps.removeCaption(p, 0)).captions, isEmpty);
    });

    test('music is validated and its volume clamped', () {
      var p = PlanOps.setMusic(_plan(), {'path': '/m.mp3', 'name': 'song'});
      p = PlanOps.setMusicVolume(p, 2);
      expect(EditPlan.fromJson(p).music!.volume, 1);
      expect(EditPlan.fromJson(PlanOps.setMusic(p, null)).music, isNull);
      expect(
        () => EditPlan.fromJson({
          ..._plan(),
          'music': {'path': '/m', 'name': 'x', 'volume': -1},
        }),
        throwsA(isA<EditPlanFormatException>()),
      );
    });

    test('beat sync moves cuts onto nearby beats and respects the minimum', () {
      // cut at 4.0 and end at 9.0; beats every 0.5 s offset by 0.2
      final beats = [for (var i = 0; i < 30; i++) 0.2 + i * 0.5];
      final p = PlanOps.snapToBeats(_plan(), beats);
      final s = _shots(p);
      expect(s[0].endSec, closeTo(4.2, 1e-9));
      expect(s[1].endSec, closeTo(9.2, 1e-9));
      expect(
        s[0].sourceOut,
        closeTo(5.2, 1e-9),
      ); // source follows the new length
    });
  });

  group('beat detector', () {
    Int16List clicks({
      required double bpm,
      double seconds = 12,
      double jitter = 0,
    }) {
      const rate = BeatDetector.sampleRate;
      final pcm = Int16List((seconds * rate).round());
      final rnd = math.Random(1);
      final period = 60 / bpm;
      for (var t = 0.3; t < seconds; t += period) {
        final start = ((t + (rnd.nextDouble() - 0.5) * jitter) * rate).round();
        for (var i = 0; i < 300 && start + i < pcm.length; i++) {
          pcm[start + i] = (12000 * math.sin(i * 0.9) * math.exp(-i / 80))
              .round();
        }
      }
      // light noise floor
      for (var i = 0; i < pcm.length; i++) {
        pcm[i] += rnd.nextInt(60) - 30;
      }
      return pcm;
    }

    test('finds the tempo of a 120 BPM click track', () {
      final a = BeatDetector.fromPcm(clicks(bpm: 120, jitter: 0.01));
      expect(a.bpm, closeTo(120, 4));
      // beats line up with the clicks (0.3 + k*0.5)
      final first = a.beats.first;
      expect(
        ((first - 0.3) / 0.5 - ((first - 0.3) / 0.5).round()).abs(),
        lessThan(0.15),
      );
    });

    for (final bpm in [90.0, 150.0]) {
      test('no octave error at $bpm BPM', () {
        final a = BeatDetector.fromPcm(clicks(bpm: bpm, jitter: 0.01));
        expect(a.bpm, closeTo(bpm, bpm * 0.04));
      });
    }

    test('silence has no beats', () {
      final a = BeatDetector.fromPcm(Int16List(BeatDetector.sampleRate * 5));
      expect(a.beats, isEmpty);
      expect(a.bpm, 0);
    });
  });

  test('render: music is looped, faded, ducked and mixed', () {
    final plan = EditPlan.fromJson({
      ..._plan(),
      'music': {
        'path': '/m.mp3',
        'name': 'song',
        'volume': 0.4,
        'offsetSec': 2,
        'fadeOutSec': 1.5,
      },
    });
    final r = buildRenderArgs(
      plan: plan,
      clips: const [
        ProjectClip(id: 'clip_01', path: '/a.mp4', name: 'a'),
        ProjectClip(id: 'clip_02', path: '/b.mp4', name: 'b'),
      ],
      hasAudio: const {'clip_01'},
      fontPath: '/f.ttf',
      textDir: '/t',
      outputPath: '/o.mp4',
      videoEncoder: 'h264_videotoolbox',
      resolution: '720p',
    );
    expect(r.args, containsAllInOrder(['-stream_loop', '-1', '-i', '/m.mp3']));
    final filter = r.args[r.args.indexOf('-filter_complex') + 1];
    expect(filter, contains('[2:a]atrim=start=2.000:duration=9.000'));
    expect(filter, contains('volume=0.40'));
    expect(filter, contains('afade=t=out:st=7.500:d=1.500'));
    expect(filter, contains('sidechaincompress'));
    expect(r.args, containsAllInOrder(['-map', '[amix]']));
  });

  group('speed and effects', () {
    test('2x speed halves the shot and keeps the source range', () {
      final p = PlanOps.setSpeed(_plan(), 's1', 2);
      final s = _shots(p);
      expect(s[0].duration, 2.0);
      expect(s[0].sourceIn, 1.0);
      expect(s[0].sourceOut, 5.0);
      expect(s[1].startSec, 2.0);
    });

    test('split respects speed when dividing the source', () {
      final fast = PlanOps.setSpeed(_plan(), 's1', 2); // s1: 0–2 s, source 1–5
      final s = _shots(PlanOps.splitAt(fast, 1.0)!);
      expect(s[0].sourceOut, 3.0);
      expect(s[1].sourceIn, 3.0);
      expect(s[1].sourceOut, 5.0);
    });

    test('transition for all shots skips the first one', () {
      final p = PlanOps.setTransition(_plan(), null, 'crossfade', seconds: 0.3);
      final s = _shots(p);
      expect(s[0].transition, ShotTransition.cut);
      expect(s[1].transition, ShotTransition.crossfade);
      expect(s[1].transitionSec, 0.3);
    });

    test('motion is stored per shot', () {
      expect(
        _shots(PlanOps.setMotion(_plan(), 's2', 'punchIn'))[1].motion,
        ShotMotion.punchIn,
      );
    });
  });

  group('media and freeze frame', () {
    test('freeze frame splits at the playhead and holds that frame', () {
      final p = PlanOps.insertFreezeFrame(_plan(), 2.0)!;
      final s = _shots(p);
      expect(s.map((x) => x.freeze), [false, true, false, false]);
      expect(s[1].duration, 1.0);
      // frame taken from source time 1.0 + 2.0 (minus one frame)
      expect(s[1].sourceIn, closeTo(2.96, 1e-9));
      expect(EditPlan.fromJson(p).durationSec, 10); // +1 s
    });

    test('a shot without footage cannot be frozen', () {
      final p = {
        ..._plan(),
        'shots': [
          {'id': 's1', 'startSec': 0.0, 'endSec': 9.0, 'description': 'card'},
        ],
      };
      expect(PlanOps.insertFreezeFrame(p, 3), isNull);
    });

    test('new media is appended at the end with unique ids', () {
      final p = PlanOps.appendShots(_plan(), [
        (clipId: 'clip_03', seconds: 4.0, still: false),
        (clipId: 'clip_04', seconds: 3.0, still: true),
      ]);
      final s = _shots(p);
      expect(s.map((x) => x.id), ['s1', 's2', 's3', 's4']);
      expect(s[2].startSec, 9.0);
      expect(s[3].sourceClipId, 'clip_04');
      expect(EditPlan.fromJson(p).durationSec, 16);
    });

    test('waveform envelope is normalised and follows loudness', () {
      const rate = BeatDetector.sampleRate;
      final pcm = Int16List(rate * 2);
      for (var i = rate; i < pcm.length; i++) {
        pcm[i] = (8000 * math.sin(i * 0.3))
            .round(); // silent 1 s, then loud 1 s
      }
      final env = BeatDetector.fromPcm(pcm).envelope;
      expect(env.length, closeTo(20, 2));
      expect(env.first, lessThan(0.05));
      expect(env.reduce(math.max), 1.0);
    });
  });

  test('render: freeze frame holds one frame and is silent', () {
    final plan = EditPlan.fromJson(PlanOps.insertFreezeFrame(_plan(), 2.0)!);
    final r = buildRenderArgs(
      plan: plan,
      clips: const [
        ProjectClip(id: 'clip_01', path: '/a.mp4', name: 'a'),
        ProjectClip(id: 'clip_02', path: '/b.mp4', name: 'b'),
      ],
      hasAudio: const {'clip_01', 'clip_02'},
      fontPath: '/f.ttf',
      textDir: '/t',
      outputPath: '/o.mp4',
      videoEncoder: 'h264_videotoolbox',
      resolution: '720p',
    );
    final filter = r.args[r.args.indexOf('-filter_complex') + 1];
    expect(filter, contains('[0:v]trim=start=2.960:duration=0.050'));
    expect(filter, contains('anullsrc=r=44100:cl=stereo,atrim=duration=1.000'));
  });
}
