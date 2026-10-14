import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/render/render_verification.dart';

Map<String, dynamic> _probe() => {
  'format': {'format_name': 'mov,mp4,m4a,3gp,3g2,mj2', 'duration': '10.024'},
  'streams': [
    {
      'codec_type': 'video',
      'width': 720,
      'height': 1280,
      'duration': '10.000',
      'avg_frame_rate': '30/1',
    },
    {'codec_type': 'audio', 'duration': '10.024'},
  ],
};

Set<String> _issues(Map<String, dynamic> probe) => {
  for (final issue in verifyRender(
    measured: RenderMeasurements.fromProbe(probe),
    expectedWidth: 720,
    expectedHeight: 1280,
    expectedDurationSec: 10,
    expectedFps: 30,
  ))
    issue.code,
};

void main() {
  test('accepts measured MP4 facts with ordinary encoder rounding', () {
    final probe = _probe();
    (probe['streams'] as List)[0]['avg_frame_rate'] = '30000/1001';
    expect(_issues(probe), isEmpty);
  });

  test(
    'rejects truncated video even when audio preserves container duration',
    () {
      final probe = _probe();
      (probe['streams'] as List)[0]['duration'] = '7.0';
      expect(_issues(probe), {'duration'});
    },
  );

  test('rejects wrong dimensions, frame rate, and container type', () {
    final probe = _probe();
    (probe['format'] as Map)['format_name'] = 'matroska,webm';
    final video = (probe['streams'] as List)[0] as Map;
    video['width'] = 1280;
    video['height'] = 720;
    video['avg_frame_rate'] = '24/1';
    expect(_issues(probe), {'container', 'dimensions', 'frame_rate'});
  });

  test('an audio file or attached album cover is not a rendered video', () {
    final probe = _probe();
    (probe['streams'] as List)[0]['disposition'] = {'attached_pic': 1};
    expect(_issues(probe), {'video_stream'});
    (probe['streams'] as List).removeAt(0);
    expect(_issues(probe), {'video_stream'});
  });

  test(
    'missing measurements fail verification instead of assuming the plan',
    () {
      final probe = _probe();
      final video = (probe['streams'] as List)[0] as Map;
      video.remove('duration');
      video.remove('width');
      video['avg_frame_rate'] = '0/0';
      expect(_issues(probe), {'dimensions', 'duration', 'frame_rate'});
    },
  );

  test('container duration is checked independently of video duration', () {
    final probe = _probe();
    (probe['format'] as Map)['duration'] = '14';
    expect(_issues(probe), {'duration'});
  });

  test('untrusted numeric metadata cannot bypass verification', () {
    for (final invalid in ['NaN', 'Infinity', '-1', '0']) {
      final probe = _probe();
      final video = (probe['streams'] as List)[0] as Map;
      video['duration'] = invalid;
      video['avg_frame_rate'] = invalid;
      expect(_issues(probe), {'duration', 'frame_rate'}, reason: invalid);
    }
  });

  test(
    'rational frame rates are parsed without accepting invalid divisions',
    () {
      expect(parseFrameRate('60000/1001'), closeTo(59.94006, 0.00001));
      expect(parseFrameRate('60'), 60);
      for (final invalid in [null, '0/0', '30/0', 'NaN', '30/1/1', '-30/1']) {
        expect(parseFrameRate(invalid), isNull);
      }
    },
  );
}
