// Fast device check of the motion-clip encoder: 16 synthetic frames at
// 6 fps must become a 30 fps H.264 clip of exactly 16/6 s.
//
//   flutter test integration_test/kadr_clip_encode_test.dart -d <simulator>
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/kadr_ai/kadr_painter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('painted frames become an exact-length 30 fps clip', (
    tester,
  ) async {
    final tmp = await getTemporaryDirectory();
    final frames = Directory(
      '${tmp.path}/frames_${DateTime.now().millisecondsSinceEpoch}',
    )..createSync(recursive: true);
    // 16 distinct frames, like AnimateDiff's output.
    final gen = await FFmpegKit.executeWithArguments([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=320x576:rate=6',
      '-frames:v',
      '16',
      '${frames.path}/f_%03d.png',
    ]);
    expect(ReturnCode.isSuccess(await gen.getReturnCode()), isTrue);
    final out = '${tmp.path}/clip.mp4';
    final enc = await FFmpegKit.executeWithArguments(
      framesToClipArgs(
        framesDir: frames.path,
        frames: 16,
        fps: 6,
        outPath: out,
        encoder: 'h264_videotoolbox',
      ),
    );
    expect(
      ReturnCode.isSuccess(await enc.getReturnCode()),
      isTrue,
      reason: await enc.getAllLogsAsString(),
    );
    final info = (await FFprobeKit.getMediaInformation(out))
        .getMediaInformation()!
        .getAllProperties()!;
    final v = (info['streams'] as List).cast<Map>().first;
    final dur = double.parse('${info['format']['duration']}');
    // ignore: avoid_print
    print(
      'CLIP ${v['width']}x${v['height']} ${v['r_frame_rate']} $dur s '
      '${v['nb_frames']} frames',
    );
    expect(v['width'], 320);
    expect(v['height'], 576);
    expect(v['r_frame_rate'], '30/1');
    expect(dur, closeTo(16 / 6, 0.05));
  });
}
