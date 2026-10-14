// Vertical slice 1, end to end on the device with the network forbidden:
// 5 product photos → Kadr AI copy → synthesised music → beat-locked plan →
// FFmpeg render → probe checks (size, length, audio) → visible motion.
//
//   flutter test integration_test/product_ad_test.dart -d <simulator> \
//     --dart-define=KADR_MODEL_SRC=$PWD/ai/data/llm/gemma-4-E2B-it-Q4_K_M.gguf
// Without KADR_MODEL_SRC (and no installed model) the copy is the template.
import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/kadr_ai/model_catalog.dart';
import 'package:hookkadr/features/product_ad/application/ad_copy_writer.dart';
import 'package:hookkadr/features/product_ad/application/product_ad_service.dart';
import 'package:hookkadr/features/product_ad/data/ad_output_check.dart';
import 'package:hookkadr/features/product_ad/data/music_synth.dart';
import 'package:hookkadr/features/projects/project.dart';
import 'package:hookkadr/features/render/render_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('network used during the offline product ad');
}

Future<Uint8List> _grayFrame(String video, double t) async {
  final dir = await getTemporaryDirectory();
  final out = '${dir.path}/frame_${t.toStringAsFixed(2)}.gray';
  await FFmpegKit.executeWithArguments([
    '-y',
    '-ss',
    '$t',
    '-i',
    video,
    '-frames:v',
    '1',
    '-vf',
    'scale=90:160,format=gray',
    '-f',
    'rawvideo',
    out,
  ]);
  return File(out).readAsBytes();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('5 photos become a verified 20 s 9:16 ad with music, offline', (
    tester,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final photos = <ProjectClip>[];
    for (var i = 0; i < 5; i++) {
      final path = '${dir.path}/product_$i.jpg';
      await FFmpegKit.executeWithArguments([
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=1600x1200:rate=1',
        '-frames:v',
        '1',
        '-vf',
        'hue=h=${i * 70}',
        path,
      ]);
      expect(File(path).existsSync(), isTrue);
      photos.add(
        ProjectClip(id: 'clip_0${i + 1}', path: path, name: 'product_$i.jpg'),
      );
    }

    // ignore: avoid_print
    print('AD step photos ready');
    SharedPreferences.setMockInitialValues({});
    final app = AppController(
      keys: MemoryKeyStore(),
      prefs: await SharedPreferences.getInstance(),
    );
    await app.load();
    final model = await app.models.fileFor(KadrModelPack.brain);
    const src = String.fromEnvironment('KADR_MODEL_SRC');
    if (!model.existsSync() && src.isNotEmpty && File(src).existsSync()) {
      model.parent.createSync(recursive: true);
      await File(src).copy(model.path);
    }
    // ignore: avoid_print
    print('AD step model copied: ${model.existsSync()}');
    if (model.existsSync()) await app.models.adoptExisting(KadrModelPack.brain);
    // ignore: avoid_print
    print('AD step model verified');
    await app.refreshModelState();

    final stages = <String>[];
    final sw = Stopwatch()..start();
    HttpOverrides.global = _NoNetwork();
    final ProductAdResult r;
    try {
      r =
          await ProductAdService(
            repository: app,
            renderer: RenderService(),
            music: MusicSynth(),
            copyWriter: AdCopyWriter(app.localModel),
            verify: checkAdOutput,
          ).create(
            images: photos,
            brief: 'Charm sumka, qo‘lda tikilgan',
            onStage: (s) {
              stages.add(
                '${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s $s',
              );
            },
          );
    } finally {
      HttpOverrides.global = null;
    }
    // ignore: avoid_print
    print(
      'AD stages: ${stages.join(' | ')} | done ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
    );
    // ignore: avoid_print
    print(
      'AD copy by ${r.copyByAi ? 'Kadr AI' : 'template'}: '
      '${[r.copy.hook, ...r.copy.lines, r.copy.cta].join(' / ')}',
    );
    expect(r.copyByAi, app.localModel != null);

    final info = (await FFprobeKit.getMediaInformation(r.outputPath))
        .getMediaInformation()!
        .getAllProperties()!;
    final streams = (info['streams'] as List).cast<Map>();
    final video = streams.firstWhere((s) => s['codec_type'] == 'video');
    final audio = streams.where((s) => s['codec_type'] == 'audio');
    // ignore: avoid_print
    print(
      'AD file: ${video['width']}x${video['height']}, '
      '${info['format']['duration']} s, audio ${audio.length}, '
      '${(File(r.outputPath).lengthSync() / 1e6).toStringAsFixed(1)} MB',
    );
    expect(video['width'], 1080);
    expect(video['height'], 1920);
    expect(double.parse('${info['format']['duration']}'), closeTo(20, 0.15));
    expect(audio, isNotEmpty);

    // The photos really move: two moments inside shot 2 differ.
    final plan = EditPlan.fromJson(app.byId(r.projectId)!.planJson);
    final s2 = plan.shots[1];
    final a = await _grayFrame(r.outputPath, s2.startSec + 0.7);
    final b = await _grayFrame(r.outputPath, s2.endSec - 0.3);
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff += (a[i] - b[i]).abs();
    }
    final mean = diff / a.length;
    // ignore: avoid_print
    print(
      'AD motion inside shot 2: mean |Δ| = ${mean.toStringAsFixed(2)} gray levels',
    );
    expect(mean, greaterThan(2));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
