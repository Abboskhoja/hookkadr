import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:kadr_diffusion/kadr_diffusion.dart';
import 'package:kadr_llm/kadr_llm.dart';
import 'package:path_provider/path_provider.dart';

import '../ai/ai_clients.dart';
import 'kadr_local_model.dart';
import 'kadr_video_composer.dart';
import 'kadr_video_maker.dart';
import 'model_catalog.dart';
import 'model_manager.dart';

/// Looks the painter can draw in. The model only understands English, so
/// every style is an English suffix added to the scene description.
enum PaintStyle {
  photo(
    'Foto',
    'professional photograph, natural light, sharp focus, highly detailed',
  ),
  product(
    'Mahsulot',
    'commercial product photography, studio lighting, clean background, premium look, highly detailed',
  ),
  cinematic(
    'Kino',
    'cinematic film still, dramatic lighting, shallow depth of field, color graded, 35mm',
  ),
  illustration(
    'Rasm',
    'digital illustration, vibrant colors, clean shapes, detailed',
  ),
  anime(
    'Anime',
    'anime style illustration, cel shading, vibrant colors, detailed background',
  );

  const PaintStyle(this.label, this.suffix);
  final String label;
  final String suffix;

  static const negative =
      'lowres, blurry, deformed, disfigured, bad anatomy, extra fingers, '
      'extra limbs, text, watermark, logo, signature, jpeg artifacts, ugly';

  String apply(String scene) {
    final s = scene.trim().replaceAll(RegExp(r'[.\s]+$'), '');
    return '$s, $suffix';
  }

  static PaintStyle byName(String? name) => PaintStyle.values.firstWhere(
    (s) => s.name == name,
    orElse: () => PaintStyle.photo,
  );
}

/// Canvas sizes the SD 1.5 model draws well: about 512² pixels, both sides
/// multiples of 64.
(int, int) paintSizeFor(String aspect) => switch (aspect) {
  '9:16' => (448, 768),
  '16:9' => (768, 448),
  '4:5' => (512, 640),
  '3:4' => (448, 576),
  _ => (512, 512),
};

/// Motion clips are smaller: AnimateDiff holds all frames in memory at once.
(int, int) motionSizeFor(String aspect) => switch (aspect) {
  '9:16' => (320, 576),
  '16:9' => (576, 320),
  '4:5' || '3:4' => (384, 448),
  _ => (384, 384),
};

/// FFmpeg arguments that turn [frames] painted frames `f_000.png…` (at
/// [fps]) into an H.264 clip smoothed to 30 fps by motion interpolation.
/// `minterpolate` stops early (16 frames at 6 fps gave 71 frames = 2.37 s
/// instead of 80, measured on device), so the input's last frame is cloned
/// twice and the result cut to exactly frames/fps seconds.
List<String> framesToClipArgs({
  required String framesDir,
  required int frames,
  required int fps,
  required String outPath,
  required String encoder,
}) => [
  '-y',
  '-framerate',
  '$fps',
  '-i',
  '$framesDir/f_%03d.png',
  '-vf',
  'tpad=stop_mode=clone:stop=2,'
      'minterpolate=fps=30:mi_mode=mci:mc_mode=aobmc:vsbmc=1,format=yuv420p',
  '-t',
  (frames / fps).toStringAsFixed(3),
  '-c:v',
  encoder,
  '-b:v',
  '6M',
  '-movflags',
  '+faststart',
  outPath,
];

/// Kadr AI's painter running on the phone: no API, no internet once the
/// pack is installed. Implements [ImageGenerator] so every flow that needs
/// an image (chat, storyboard videos) can use it.
class KadrPainter implements ImageGenerator {
  KadrPainter(this.manager, {this.style = PaintStyle.photo, this.seed});

  final KadrModelManager manager;
  final PaintStyle style;

  /// Fixed seed (e.g. to keep a storyboard's look); random when null.
  final int? seed;

  static KadrDiffusion? _sd;
  static bool _sdHasMotion = false;
  static Future<KadrDiffusion>? _loading;

  /// Steps/guidance of the LCM-distilled checkpoint (model card: LCM
  /// sampler, 4–8 steps, CFG 1–2). 4 steps were checked by eye on the
  /// host benchmark (512² and 448×768): sharp, no artefacts.
  static const steps = 4;
  static const cfg = 1.5;

  /// Below this, the brain and the painter never stay loaded together.
  static const _sharedRamBytes = 8 * 1024 * 1024 * 1024;

  Future<bool> get installed => manager.isInstalled(KadrModelPack.painter);
  Future<bool> get motionInstalled => manager.isInstalled(KadrModelPack.motion);

  Future<KadrDiffusion> _engine({required bool motion}) async {
    final current = _sd;
    if (current != null && (!motion || _sdHasMotion)) return current;
    if (!await installed) {
      throw const AiException(
        'Kadr AI rassomi hali o‘rnatilmagan. Profil → Kadr AI telefonda → Rassom.',
      );
    }
    if (motion && !await motionInstalled) {
      throw const AiException(
        'Jonli harakat moduli o‘rnatilmagan. Profil → Kadr AI telefonda → Harakat.',
      );
    }
    final pending = _loading;
    if (pending != null) {
      final sd = await pending;
      if (!motion || _sdHasMotion) return sd;
    }
    return _loading = () async {
      try {
        final ram = kadrDeviceRamBytes();
        if (ram > 0 && ram < _sharedRamBytes) KadrLocalModel.unload();
        _sd?.dispose();
        _sd = null;
        final model = await manager.fileFor(KadrModelPack.painter);
        final decoder = await manager.fileFor(KadrModelPack.decoder);
        final mm = motion ? await manager.fileFor(KadrModelPack.motion) : null;
        final sd = await KadrDiffusion.load(
          model.path,
          motion: mm?.path,
          decoder: await manager.isInstalled(KadrModelPack.decoder)
              ? decoder.path
              : null,
          // Q8 weights halve memory and keep SD 1.5 quality.
          weights: SdWeights.q8,
        );
        _sd = sd;
        _sdHasMotion = motion;
        return sd;
      } on KadrDiffusionException catch (e) {
        throw AiException(e.message);
      } finally {
        _loading = null;
      }
    }();
  }

  static Future<Directory> _outDir(String sub) async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/$sub')..createSync(recursive: true);
  }

  int _seed() => seed ?? DateTime.now().microsecondsSinceEpoch & 0x7fffffff;

  /// Draws [scene] (English) and returns the PNG file.
  Future<File> paint(
    String scene, {
    String aspectRatio = '1:1',
    PaintStyle? style,
    int? seed,
    String? initImage,
    double strength = 0.6,
    void Function(PaintProgress)? onProgress,
  }) async {
    final sd = await _engine(motion: false);
    final (w, h) = paintSizeFor(aspectRatio);
    final dir = await _outDir('images');
    final out = '${dir.path}/kadr_${DateTime.now().millisecondsSinceEpoch}.png';
    try {
      return await sd.paint(
        PaintJob(
          prompt: (style ?? this.style).apply(scene),
          negative: PaintStyle.negative,
          width: w,
          height: h,
          steps: steps,
          cfg: cfg,
          sampler: SdSampler.lcm,
          seed: seed ?? _seed(),
          initImage: initImage,
          strength: strength,
        ),
        out,
        onProgress: onProgress,
      );
    } on KadrDiffusionException catch (e) {
      throw AiException(e.message);
    }
  }

  @override
  Future<Uint8List> generateImage(
    String prompt, {
    String aspectRatio = '1:1',
  }) async => (await paint(prompt, aspectRatio: aspectRatio)).readAsBytes();

  /// Animates [scene] into a short 30 fps MP4 clip. With [keyframe] the
  /// clip starts from that picture (same look as the storyboard image).
  /// Returns the clip and its duration in seconds.
  Future<(File, double)> animate(
    String scene, {
    String aspectRatio = '9:16',
    String? keyframe,
    int frames = KadrVideoComposer.motionFrames,
    int fps = KadrVideoComposer.motionFps,
    int? seed,
    void Function(PaintProgress)? onProgress,
  }) async {
    final sd = await _engine(motion: true);
    final (w, h) = motionSizeFor(aspectRatio);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final tmp = await _outDir('kadr_frames/$stamp');
    try {
      final files = await sd.animate(
        PaintJob(
          prompt: style.apply(scene),
          negative: PaintStyle.negative,
          width: w,
          height: h,
          // AnimateDiff-Lightning 4-step: Euler + SGM uniform, no guidance.
          steps: 4,
          cfg: 1,
          sampler: SdSampler.euler,
          scheduler: SdScheduler.sgmUniform,
          seed: seed ?? _seed(),
          initImage: keyframe,
          strength: 0.7,
        ),
        frames,
        tmp.path,
        onProgress: onProgress,
      );
      if (files.length < 2) {
        throw const AiException(
          'Harakatli klip chiqmadi. Qayta urinib ko‘ring.',
        );
      }
      final clips = await _outDir('clips');
      final out = '${clips.path}/kadr_motion_$stamp.mp4';
      final session = await FFmpegKit.executeWithArguments(
        framesToClipArgs(
          framesDir: tmp.path,
          frames: files.length,
          fps: fps,
          outPath: out,
          encoder: Platform.isIOS ? 'h264_videotoolbox' : 'h264_mediacodec',
        ),
      );
      if (!ReturnCode.isSuccess(await session.getReturnCode())) {
        throw const AiException('Klip videoga yig‘ilmadi.');
      }
      // The real length of the file, not the intended one.
      final probed = double.tryParse(
        '${(await FFprobeKit.getMediaInformation(out)).getMediaInformation()?.getDuration()}',
      );
      return (File(out), probed ?? files.length / fps);
    } on KadrDiffusionException catch (e) {
      throw AiException(e.message);
    } finally {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    }
  }

  /// Loads the painter (with the motion module for [motion]) ahead of a job.
  Future<void> prepare({required bool motion}) => _engine(motion: motion);

  /// Stops the image or clip being drawn now, if any.
  static void cancel() => _sd?.cancel();

  /// Frees the painter's memory.
  static void unload() {
    _sd?.dispose();
    _sd = null;
    _sdHasMotion = false;
  }
}

/// [ScenePainter] backed by the on-device painter.
class KadrPainterScenes implements ScenePainter {
  KadrPainterScenes(this.painter);
  final KadrPainter painter;

  @override
  Future<void> prepare({required bool live}) => painter.prepare(motion: live);

  @override
  Future<String> paintScene(
    String prompt, {
    required String aspectRatio,
    required int seed,
    void Function(double progress)? onProgress,
  }) async => (await painter.paint(
    prompt,
    aspectRatio: aspectRatio,
    seed: seed,
    onProgress: onProgress == null ? null : (p) => onProgress(p.fraction),
  )).path;

  @override
  Future<(String, double)> animateScene(
    String prompt, {
    required String aspectRatio,
    required String keyframe,
    required int seed,
    void Function(double progress)? onProgress,
  }) async {
    final (file, sec) = await painter.animate(
      prompt,
      aspectRatio: aspectRatio,
      keyframe: keyframe,
      seed: seed,
      onProgress: onProgress == null ? null : (p) => onProgress(p.fraction),
    );
    return (file.path, sec);
  }
}
