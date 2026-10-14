import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/director/kart_production.dart';
import 'package:hookkadr/features/projects/project.dart';
import 'package:hookkadr/features/render/media_analyzer.dart';
import 'package:hookkadr/features/render/render_service.dart';
import 'package:hookkadr/features/render/render_verification.dart';
import 'package:hookkadr/features/vision/scene_quality_scanner.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'KART brief → measured source → timeline → verified MP4 → local model',
    (tester) async {
      final dir = await getApplicationDocumentsDirectory();
      final source = '${dir.path}/kart_test_source.mp4';
      final encoder = Platform.isIOS ? 'h264_videotoolbox' : 'h264_mediacodec';
      final generated = await FFmpegKit.executeWithArguments([
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc=size=640x360:rate=30:duration=16',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=16',
        '-c:v',
        encoder,
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-shortest',
        source,
      ]);
      expect(
        ReturnCode.isSuccess(await generated.getReturnCode()),
        isTrue,
        reason: await generated.getAllLogsAsString(),
      );
      final facts = await MediaAnalyzer().analyze('demo', source);
      final result = KartProduction.build(
        request: '10 soniyalik premium reklama yarat',
        title: 'TEST — KART render namoyishi',
        facts: [facts],
        aspectRatio: '16:9',
        resolution: '360p',
        fps: 25,
      );
      expect(result.readyForRender, isTrue, reason: '${result.metrics}');
      final plan = EditPlan.fromJson(result.plan);
      final output = await RenderService().render(
        plan: plan,
        clips: [
          ProjectClip(
            id: 'demo',
            path: source,
            name: 'TEST source',
            durationSec: facts.durationSec,
          ),
        ],
        resolution: '360p',
        name: 'kart_verified_demo',
      );
      final probe = (await FFprobeKit.getMediaInformation(output))
          .getMediaInformation()!
          .getAllProperties();
      expect(probe, isNotNull);
      final measured = RenderMeasurements.fromProbe(probe!);
      expect(
        verifyRender(
          measured: measured,
          expectedWidth: 640,
          expectedHeight: 360,
          expectedDurationSec: 10,
          expectedFps: 25,
        ),
        isEmpty,
      );
      final quality = await SceneQualityScanner().scan(output);
      expect(quality.modelVersion, '1.0.0');
      expect(quality.samples, greaterThanOrEqualTo(4));
      expect(quality.meanQuality, inInclusiveRange(0, 1));
      await File('${dir.path}/kart_verified_demo.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'fixture':
              'synthetic test pattern and sine tone, not generated advertising',
          'output': output,
          'sizeBytes': File(output).lengthSync(),
          'durationSec': measured.durationSec,
          'fps': measured.fps,
          'width': measured.width,
          'height': measured.height,
          'modelVersion': quality.modelVersion,
          'sampleCount': quality.samples,
          'technicalQuality': quality.meanQuality,
          'flags': quality.flags,
          'plan': result.plan,
        }),
      );
      // Optional local simulator evidence capture before flutter test uninstalls
      // its app. Never enabled in production or required on physical devices.
      const evidenceDir = String.fromEnvironment('KART_EVIDENCE_DIR');
      if (evidenceDir.isNotEmpty) {
        await Directory(evidenceDir).create(recursive: true);
        await File(output).copy('$evidenceDir/verified.mp4');
        await File('${dir.path}/kart_verified_demo.json')
            .copy('$evidenceDir/verified.json');
      }
    },
  );
}
