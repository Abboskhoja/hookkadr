import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/projects/project.dart';
import 'package:hookkadr/features/render/render_plan.dart';

EditPlan _plan() => EditPlan.fromJson({
  'schemaVersion': 1,
  'title': 'T',
  'summary': 'S',
  'durationSec': 9,
  'aspectRatio': '9:16',
  'shots': [
    {
      'id': 's1',
      'startSec': 0,
      'endSec': 3,
      'description': 'Kirish',
      'sourceClipId': 'clip_01',
      'sourceIn': 2,
      'sourceOut': 5,
    },
    {
      'id': 's2',
      'startSec': 3,
      'endSec': 6,
      'description': "O'rta: 50%, test",
      'mediaSlotId': 'm1',
    },
    {
      'id': 's3',
      'startSec': 6,
      'endSec': 9,
      'description': 'Oxiri',
      'sourceClipId': 'clip_02',
      'sourceIn': 0,
      'sourceOut': 3,
    },
  ],
  'mediaSlots': [
    {'id': 'm1', 'kind': 'video', 'description': 'B-roll'},
  ],
  'captions': [
    {'startSec': 0.5, 'endSec': 2.5, 'text': "Salom, dunyo: 100%"},
  ],
  'audioTracks': <Map<String, dynamic>>[],
  'export': {'resolution': '1080p', 'fps': 30},
});

const _clips = [
  ProjectClip(id: 'clip_01', path: '/tmp/a.mp4', name: 'a.mp4'),
  ProjectClip(id: 'clip_02', path: '/tmp/b.mp4', name: 'b.mp4'),
];

void main() {
  test('output sizes follow aspect ratio and resolution', () {
    expect(outputSize('9:16', '1080p'), (width: 1080, height: 1920));
    expect(outputSize('16:9', '1080p'), (width: 1920, height: 1080));
    expect(outputSize('1:1', '720p'), (width: 720, height: 720));
    expect(outputSize('4:5', '1080p'), (width: 1080, height: 1350));
  });

  test('builds inputs, per-shot trims, concat and captions', () {
    final r = buildRenderArgs(
      plan: _plan(),
      clips: _clips,
      hasAudio: {'clip_01'},
      fontPath: '/tmp/Inter.ttf',
      textDir: '/tmp/t',
      outputPath: '/tmp/out.mp4',
      videoEncoder: 'h264_videotoolbox',
      resolution: '1080p',
    );
    final a = r.args;
    expect(a.where((x) => x == '-i').length, 2);
    expect(a, containsAllInOrder(['-i', '/tmp/a.mp4', '-i', '/tmp/b.mp4']));
    final filter = a[a.indexOf('-filter_complex') + 1];
    expect(filter, contains('[0:v]trim=start=2.000:duration=3.000'));
    expect(filter, contains('[1:v]trim=start=0.000:duration=3.000'));
    expect(filter, contains('[0:a]atrim=start=2.000'));
    // clip_02 has no audio -> silence, never a missing stream
    expect(filter, isNot(contains('[1:a]')));
    expect(filter, contains('[x2]null[vc]'));
    expect(filter, contains('[a0][a1][a2]concat=n=3:v=0:a=1[ac]'));
    expect(filter, contains('scale=1080:1920'));
    expect(filter, contains('between(t'));
    expect(a.last, '/tmp/out.mp4');
    expect(a, containsAllInOrder(['-c:v', 'h264_videotoolbox']));
    expect(r.totalSec, 9);
  });

  test('caption text goes to files so special characters are harmless', () {
    final r = buildRenderArgs(
      plan: _plan(),
      clips: _clips,
      hasAudio: const {},
      fontPath: '/tmp/Inter.ttf',
      textDir: '/tmp/t',
      outputPath: '/tmp/out.mp4',
      videoEncoder: 'h264_mediacodec',
      resolution: '720p',
    );
    final filter = r.args[r.args.indexOf('-filter_complex') + 1];
    expect(filter, isNot(contains('Salom')));
    expect(filter, contains('textfile=/tmp/t/cap0.txt'));
    expect(filter, contains('expansion=none'));
    expect(r.textFiles['/tmp/t/cap0.txt'], 'Salom, dunyo: 100%');
    expect(r.textFiles['/tmp/t/shot1.txt'], "O'rta: 50%, test");
    expect(filter, contains('scale=720:1280'));
  });

  test('a shot without footage becomes a labelled card, not fake video', () {
    final r = buildRenderArgs(
      plan: _plan(),
      clips: const [],
      hasAudio: const {},
      fontPath: '/tmp/Inter.ttf',
      textDir: '/tmp/t',
      outputPath: '/tmp/out.mp4',
      videoEncoder: 'h264_videotoolbox',
      resolution: '1080p',
    );
    final filter = r.args[r.args.indexOf('-filter_complex') + 1];
    expect('color=c=0x181715'.allMatches(filter).length, 3);
    expect(r.args.where((x) => x == '-i'), isEmpty);
  });

  test('still images are looped and get a slow zoom, never audio mapping', () {
    final plan = EditPlan.fromJson({
      'schemaVersion': 1,
      'title': 'T',
      'summary': 'S',
      'durationSec': 6,
      'aspectRatio': '9:16',
      'shots': [
        {
          'id': 's1',
          'startSec': 0,
          'endSec': 3,
          'description': 'a',
          'sourceClipId': 'clip_01',
          'sourceIn': 0,
          'sourceOut': 3,
        },
        {
          'id': 's2',
          'startSec': 3,
          'endSec': 6,
          'description': 'b',
          'sourceClipId': 'clip_02',
          'sourceIn': 0,
          'sourceOut': 3,
        },
      ],
      'mediaSlots': <Map<String, dynamic>>[],
      'captions': <Map<String, dynamic>>[],
      'audioTracks': <Map<String, dynamic>>[],
      'export': {'resolution': '1080p', 'fps': 30},
    });
    final r = buildRenderArgs(
      plan: plan,
      clips: const [
        ProjectClip(id: 'clip_01', path: '/tmp/a.png', name: 'a'),
        ProjectClip(id: 'clip_02', path: '/tmp/b.jpg', name: 'b'),
      ],
      hasAudio: const {},
      fontPath: '/f.ttf',
      textDir: '/t',
      outputPath: '/o.mp4',
      videoEncoder: 'h264_videotoolbox',
      resolution: '1080p',
    );
    expect(r.args.where((x) => x == '-loop').length, 2);
    final filter = r.args[r.args.indexOf('-filter_complex') + 1];
    expect(filter, contains('zoompan='));
    expect(filter, isNot(contains('[0:a]')));
    expect(r.args, containsAllInOrder(['-t', '6.000']));
  });

  group('transitions, speed and motion', () {
    EditPlan fxPlan(
      Map<String, dynamic> second, {
      Map<String, dynamic> first = const {},
    }) => EditPlan.fromJson({
      'schemaVersion': 1,
      'title': 'T',
      'summary': 'S',
      'durationSec': 6,
      'aspectRatio': '9:16',
      'shots': [
        {
          'id': 's1',
          'startSec': 0,
          'endSec': 3,
          'description': 'a',
          'sourceClipId': 'clip_01',
          'sourceIn': 0,
          'sourceOut': 3,
          ...first,
        },
        {
          'id': 's2',
          'startSec': 3,
          'endSec': 6,
          'description': 'b',
          'sourceClipId': 'clip_01',
          'sourceIn': 4,
          'sourceOut': 7,
          ...second,
        },
      ],
      'mediaSlots': <Map<String, dynamic>>[],
      'captions': <Map<String, dynamic>>[],
      'audioTracks': <Map<String, dynamic>>[],
      'export': {'resolution': '720p', 'fps': 30},
    });
    String graph(EditPlan p) {
      final r = buildRenderArgs(
        plan: p,
        clips: const [ProjectClip(id: 'clip_01', path: '/a.mp4', name: 'a')],
        hasAudio: const {'clip_01'},
        fontPath: '/f.ttf',
        textDir: '/t',
        outputPath: '/o.mp4',
        videoEncoder: 'h264_videotoolbox',
        resolution: '720p',
      );
      return r.args[r.args.indexOf('-filter_complex') + 1];
    }

    test('crossfade overlaps without changing the timeline length', () {
      final g = graph(
        fxPlan({'transition': 'crossfade', 'transitionSec': 0.5}),
      );
      // outgoing shot runs 0.5 s longer under the transition
      expect(g, contains('[0:v]trim=start=0.000:duration=3.500'));
      expect(g, contains('xfade=transition=fade:duration=0.500:offset=3.000'));
      // audio still sums to the planned 6 s
      expect(g, contains('atrim=duration=3.000[a0]'));
    });

    test('each transition maps to an xfade effect', () {
      expect(xfadeName(ShotTransition.fadeBlack), 'fadeblack');
      expect(xfadeName(ShotTransition.slide), 'slideleft');
      expect(xfadeName(ShotTransition.zoom), 'zoomin');
      expect(
        graph(fxPlan({'transition': 'zoom'})),
        contains('xfade=transition=zoomin'),
      );
    });

    test('a long transition is limited to half of the shorter shot', () {
      final g = graph(fxPlan({'transition': 'crossfade', 'transitionSec': 2}));
      expect(g, contains('duration=1.500:offset=3.000'));
    });

    test('fade from black on the first shot becomes a fade-in', () {
      final g = graph(
        fxPlan(
          const {},
          first: {'transition': 'fadeBlack', 'transitionSec': 0.6},
        ),
      );
      expect(g, contains('[v0]fade=t=in:st=0:d=0.600[vin]'));
    });

    test('2x speed reads twice the source and speeds the audio up', () {
      final g = graph(fxPlan({'speed': 2.0}));
      expect(
        g,
        contains(
          '[0:v]trim=start=4.000:duration=6.000,setpts=(PTS-STARTPTS)/2.0000',
        ),
      );
      expect(
        g,
        contains(
          'atrim=start=4.000:duration=6.000,asetpts=PTS-STARTPTS,atempo=2.0000',
        ),
      );
    });

    test('atempo is chained outside 0.5–2.0', () {
      expect(atempoChain(4), 'atempo=2.0,atempo=2.0000');
      expect(atempoChain(0.25), 'atempo=0.5,atempo=0.5000');
      expect(atempoChain(1), '');
    });

    test('motion adds an oversampled zoompan', () {
      final g = graph(fxPlan({'motion': 'punchIn'}));
      expect(g, contains("scale=864:1536,zoompan=z='if(lt(on,9)"));
      expect(
        graph(fxPlan({'motion': 'slowZoom'})),
        contains('min(1.0+on*0.0015,1.18)'),
      );
    });

    test('unknown effect values are rejected', () {
      expect(
        () => fxPlan({'transition': 'explode'}),
        throwsA(isA<EditPlanFormatException>()),
      );
      expect(
        () => fxPlan({'speed': 10}),
        throwsA(isA<EditPlanFormatException>()),
      );
    });
  });
}
