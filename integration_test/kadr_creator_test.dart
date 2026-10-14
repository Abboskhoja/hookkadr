// Kadr AI as a creator, end to end on the device with the network forbidden:
// Uzbek request → brain writes the English picture description → painter
// draws it; Uzbek idea → storyboard → painted scenes → music → render →
// probe checks; one painted scene → AnimateDiff clip.
//
//   flutter test integration_test/kadr_creator_test.dart -d <simulator> \
//     --dart-define=KADR_MODEL_SRC=$PWD/ai/data/llm/gemma-4-E2B-it-Q4_K_M.gguf \
//     --dart-define=KADR_PAINTER_SRC=<dir with the painter/decoder/motion files>
//
// The simulator build is CPU-only, so timings here are far slower than a
// phone's GPU; they are printed, not asserted.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/features/ai/plan_generator.dart';
import 'package:hookkadr/features/kadr_ai/kadr_painter.dart';
import 'package:hookkadr/features/kadr_ai/kadr_video_maker.dart';
import 'package:hookkadr/features/kadr_ai/model_catalog.dart';
import 'package:hookkadr/features/product_ad/data/ad_output_check.dart';
import 'package:hookkadr/features/product_ad/data/music_synth.dart';
import 'package:hookkadr/features/render/render_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('network used during offline Kadr AI creation');
}

void _log(String s) {
  // ignore: avoid_print
  print('KADR $s');
}

Future<Map<String, dynamic>> _probe(String path) async =>
    (await FFprobeKit.getMediaInformation(path))
        .getMediaInformation()!
        .getAllProperties()!
        .cast<String, dynamic>();

Future<Uint8List> _gray(String media, {double? at}) async {
  final dir = await getTemporaryDirectory();
  final out = '${dir.path}/g_${DateTime.now().microsecondsSinceEpoch}.gray';
  await FFmpegKit.executeWithArguments([
    '-y',
    if (at != null) ...['-ss', '$at'],
    '-i',
    media,
    '-frames:v',
    '1',
    '-vf',
    'scale=72:128,format=gray',
    '-f',
    'rawvideo',
    out,
  ]);
  return File(out).readAsBytes();
}

double _meanDiff(Uint8List a, Uint8List b) {
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    d += (a[i] - b[i]).abs();
  }
  return d / a.length;
}

double _stdDev(Uint8List a) {
  final mean = a.fold<int>(0, (s, v) => s + v) / a.length;
  var v = 0.0;
  for (final x in a) {
    v += (x - mean) * (x - mean);
  }
  return math.sqrt(v / a.length);
}

Future<void> _install(AppController app, KadrModelPack pack, String src) async {
  final f = await app.models.fileFor(pack);
  if (!await app.models.isInstalled(pack)) {
    if (!f.existsSync() && src.isNotEmpty && File(src).existsSync()) {
      f.parent.createSync(recursive: true);
      await File(src).copy(f.path);
    }
    if (f.existsSync()) await app.models.adoptExisting(pack);
  }
  _log('${pack.id} installed: ${await app.models.isInstalled(pack)}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppController app;
  const brainSrc = String.fromEnvironment('KADR_MODEL_SRC');
  const painterDir = String.fromEnvironment('KADR_PAINTER_SRC');

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    app = AppController(
      keys: MemoryKeyStore(),
      prefs: await SharedPreferences.getInstance(),
    );
    await app.load();
    await _install(app, KadrModelPack.brain, brainSrc);
    for (final p in [
      KadrModelPack.painter,
      KadrModelPack.decoder,
      KadrModelPack.motion,
    ]) {
      await _install(app, p, '$painterDir/${p.fileName}');
    }
    await app.refreshModelState();
    HttpOverrides.global = _NoNetwork();
  });

  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('Uzbek request → English description → painted 9:16 image', (
    tester,
  ) async {
    expect(app.painterInstalled, isTrue, reason: 'painter pack missing');
    expect(app.localModel, isNotNull, reason: 'brain pack missing');
    final sw = Stopwatch()..start();
    final prompt = await PlanGenerator(planner: app.localModel!)
        .writeGenerationPrompt(
          request:
              'Qor yog‘ayotgan tog‘ qishlog‘i, kechqurun, derazalarda chiroq',
          video: false,
          aspectRatio: '9:16',
        );
    _log('prompt ${sw.elapsedMilliseconds} ms: $prompt');
    expect(prompt, matches(RegExp(r"^[A-Za-z0-9 ,.'()-]+$")));
    expect(prompt.split(' ').length, greaterThan(4));

    sw.reset();
    final png = await app.painter!.paint(prompt, aspectRatio: '9:16', seed: 7);
    _log('painted ${sw.elapsedMilliseconds} ms: ${png.path}');
    final info = await _probe(png.path);
    final v = (info['streams'] as List).cast<Map>().first;
    expect(v['width'], 448);
    expect(v['height'], 768);
    // A real picture, not a flat or broken frame.
    final g = await _gray(png.path);
    _log('image contrast σ = ${_stdDev(g).toStringAsFixed(1)}');
    expect(_stdDev(g), greaterThan(12));
  }, timeout: const Timeout(Duration(minutes: 20)));

  testWidgets('Uzbek idea → painted scenes → verified 9 s video with music', (
    tester,
  ) async {
    final stages = <String>[];
    final sw = Stopwatch()..start();
    final gen = PlanGenerator(planner: app.localModel!);
    final res =
        await KadrVideoMaker(
          repository: app,
          renderer: RenderService(),
          music: MusicSynth(),
          painter: KadrPainterScenes(app.painter!),
          storyboard: (req, sec, n) => gen.writeStoryboard(
            request: req,
            durationSec: sec,
            aspectRatio: '9:16',
            scenes: n,
          ),
          verify: checkAdOutput,
        ).create(
          request: 'Choyxona reklamasi: issiq choy, non va do‘stlar',
          durationSec: 9,
          seed: 11,
          onStage: (s) => stages.add(
            '${(sw.elapsedMilliseconds / 1000).toStringAsFixed(0)}s $s',
          ),
        );
    _log('stages: ${stages.join(' | ')} | done ${sw.elapsed.inSeconds}s');
    for (final (i, s) in res.scenes.indexed) {
      _log('scene ${i + 1}: ${s.prompt} | ${s.caption ?? '-'}');
    }
    expect(res.scenes.length, 3);
    final info = await _probe(res.outputPath);
    final streams = (info['streams'] as List).cast<Map>();
    final video = streams.firstWhere((s) => s['codec_type'] == 'video');
    expect(video['width'], 1080);
    expect(video['height'], 1920);
    expect(double.parse('${info['format']['duration']}'), closeTo(9, 0.15));
    expect(streams.where((s) => s['codec_type'] == 'audio'), isNotEmpty);
    // Different scenes really differ.
    final a = await _gray(res.outputPath, at: 1.5);
    final b = await _gray(res.outputPath, at: 7.5);
    final d = _meanDiff(a, b);
    _log('scene 1 vs 3: mean |Δ| = ${d.toStringAsFixed(1)}');
    expect(d, greaterThan(8));
  }, timeout: const Timeout(Duration(minutes: 40)));

  testWidgets('one painted scene → moving AnimateDiff clip', (tester) async {
    expect(app.motionInstalled, isTrue, reason: 'motion pack missing');
    final painter = app.painter!;
    final sw = Stopwatch()..start();
    await painter.prepare(motion: true);
    _log('motion loaded ${sw.elapsedMilliseconds} ms');
    sw.reset();
    const scene =
        'a lighthouse on a rocky coast at sunset, waves crashing, windy';
    final key = await painter.paint(scene, aspectRatio: '9:16', seed: 3);
    _log('keyframe ${sw.elapsedMilliseconds} ms');
    sw.reset();
    final (clip, sec) = await painter.animate(
      scene,
      aspectRatio: '9:16',
      keyframe: key.path,
      seed: 3,
    );
    _log('clip ${sw.elapsedMilliseconds} ms: ${clip.path} ($sec s)');
    expect(sec, closeTo(16 / 6, 0.05));
    final info = await _probe(clip.path);
    final v = (info['streams'] as List).cast<Map>().first;
    expect(v['width'], 320);
    expect(v['height'], 576);
    final first = await _gray(clip.path, at: 0.05);
    final last = await _gray(clip.path, at: sec - 0.2);
    final d = _meanDiff(first, last);
    _log(
      'clip motion first vs last: mean |Δ| = ${d.toStringAsFixed(2)}, '
      'contrast σ = ${_stdDev(first).toStringAsFixed(1)}',
    );
    expect(_stdDev(first), greaterThan(12), reason: 'not a flat/broken frame');
    expect(d, greaterThan(1), reason: 'the clip moves');
  }, timeout: const Timeout(Duration(minutes: 40)));
}
