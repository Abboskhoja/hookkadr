/// Kadr AI on-device painter: Stable Diffusion 1.x images and AnimateDiff
/// video through a small C surface (`src/kadr_sd.h`) over
/// stable-diffusion.cpp. Generation runs in its own isolate; images travel
/// as PNG files, never as pixel buffers between isolates.
library;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

class KadrDiffusionException implements Exception {
  const KadrDiffusionException(this.message);
  final String message;
  @override
  String toString() => 'KadrDiffusionException: $message';
}

// ------------------------------------------------------------------ bindings

typedef _LoadC =
    Pointer<Void> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Int32,
      Int32,
      Pointer<Int32>,
      Pointer<Utf8>,
      Int32,
    );
typedef _LoadD =
    Pointer<Void> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
      int,
      Pointer<Int32>,
      Pointer<Utf8>,
      int,
    );
typedef _ImageC =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Int32,
      Int32,
      Int32,
      Float,
      Int32,
      Int32,
      Int64,
      Pointer<Utf8>,
      Float,
      Pointer<Utf8>,
    );
typedef _ImageD =
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
      int,
      int,
      double,
      int,
      int,
      int,
      Pointer<Utf8>,
      double,
      Pointer<Utf8>,
    );
typedef _VideoC =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Int32,
      Int32,
      Int32,
      Int32,
      Float,
      Int32,
      Int32,
      Int64,
      Pointer<Utf8>,
      Float,
      Pointer<Utf8>,
    );
typedef _VideoD =
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
      int,
      int,
      int,
      double,
      int,
      int,
      int,
      Pointer<Utf8>,
      double,
      Pointer<Utf8>,
    );
typedef _PtrC = Void Function(Pointer<Void>);
typedef _PtrD = void Function(Pointer<Void>);
typedef _ConvertC = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _ConvertD = int Function(Pointer<Utf8>, Pointer<Utf8>, int);
typedef _InfoC = Int32 Function(Pointer<Utf8>, Int32);
typedef _InfoD = int Function(Pointer<Utf8>, int);

final class _Native {
  _Native(DynamicLibrary lib)
    : load = lib.lookupFunction<_LoadC, _LoadD>('kadr_sd_load'),
      image = lib.lookupFunction<_ImageC, _ImageD>('kadr_sd_image'),
      video = lib.lookupFunction<_VideoC, _VideoD>('kadr_sd_video'),
      cancel = lib.lookupFunction<_PtrC, _PtrD>('kadr_sd_cancel'),
      free = lib.lookupFunction<_PtrC, _PtrD>('kadr_sd_free'),
      convert = lib.lookupFunction<_ConvertC, _ConvertD>('kadr_sd_convert'),
      info = lib.lookupFunction<_InfoC, _InfoD>('kadr_sd_info');

  final _LoadD load;
  final _ImageD image;
  final _VideoD video;
  final _PtrD cancel;
  final _PtrD free;
  final _ConvertD convert;
  final _InfoD info;

  static _Native? _instance;
  static _Native get instance => _instance ??= _Native(_open());

  static DynamicLibrary _open() {
    if (Platform.isIOS || Platform.isMacOS) {
      return DynamicLibrary.open('KadrSd.framework/KadrSd');
    }
    if (Platform.isAndroid) return DynamicLibrary.open('libkadr_sd.so');
    throw const KadrDiffusionException(
      'Kadr AI rassomi faqat iOS va Androidda ishlaydi.',
    );
  }
}

/// Is the native painter linked into this build?
bool kadrDiffusionAvailable() {
  try {
    _Native.instance;
    return true;
  } catch (_) {
    return false;
  }
}

/// "version|commit|system info" of the linked runtime, or null.
String? kadrDiffusionInfo() {
  try {
    final buf = calloc<Uint8>(1024);
    _Native.instance.info(buf.cast(), 1024);
    final s = buf.cast<Utf8>().toDartString();
    calloc.free(buf);
    return s;
  } catch (_) {
    return null;
  }
}

/// Sampler and scheduler ids of the runtime (stable-diffusion.h).
abstract final class SdSampler {
  static const euler = 0;
  static const lcm = 9;
}

abstract final class SdScheduler {
  static const auto = -1;
  static const sgmUniform = 5;
}

/// Weight types for [KadrDiffusion.load] / [KadrDiffusion.convert].
abstract final class SdWeights {
  static const asFile = -1;
  static const f16 = 1;
  static const q8 = 8;
}

String _codeError(int code) => switch (code) {
  -1 => 'Rasm chizilmadi (to‘xtatildi yoki xotira yetmadi).',
  -2 => 'Natijani saqlab bo‘lmadi.',
  -3 => 'Boshlang‘ich rasmni o‘qib bo‘lmadi.',
  -4 => 'Video moduli o‘rnatilmagan.',
  _ => 'Noma’lum xato ($code).',
};

/// One drawing job. [initImage] turns it into image-to-image (or
/// image-to-video) with [strength] = how far it may move away (0..1).
class PaintJob {
  const PaintJob({
    required this.prompt,
    this.negative = '',
    this.width = 512,
    this.height = 512,
    this.steps = 4,
    this.cfg = 1.5,
    this.sampler = SdSampler.lcm,
    this.scheduler = SdScheduler.auto,
    this.seed = 42,
    this.initImage,
    this.strength = 0.75,
  });

  final String prompt;
  final String negative;
  final int width;
  final int height;
  final int steps;
  final double cfg;
  final int sampler;
  final int scheduler;
  final int seed;
  final String? initImage;
  final double strength;
}

// ------------------------------------------------------------------ isolate

final class _ImageReq {
  const _ImageReq(this.job, this.out);
  final PaintJob job;
  final String out;
}

final class _VideoReq {
  const _VideoReq(this.job, this.frames, this.outDir);
  final PaintJob job;
  final int frames;
  final String outDir;
}

final class _Close {
  const _Close();
}

final class _Ok {
  const _Ok(this.value);
  final int value;
}

final class _Fail {
  const _Fail(this.message);
  final String message;
}

void _worker((SendPort, String, String?, String?, int, int, int) args) {
  final (reply, model, motion, decoder, threads, weights, progressAddr) = args;
  final n = _Native.instance;
  final err = calloc<Uint8>(512);
  final m = model.toNativeUtf8();
  final mm = motion?.toNativeUtf8();
  final dec = decoder?.toNativeUtf8();
  final handle = n.load(
    m,
    mm ?? nullptr,
    dec ?? nullptr,
    threads,
    weights,
    Pointer<Int32>.fromAddress(progressAddr),
    err.cast(),
    512,
  );
  calloc.free(m);
  if (mm != null) calloc.free(mm);
  if (dec != null) calloc.free(dec);
  if (handle == nullptr) {
    reply.send(_Fail(err.cast<Utf8>().toDartString()));
    calloc.free(err);
    return;
  }
  calloc.free(err);
  final inbox = ReceivePort();
  reply.send((inbox.sendPort, handle.address));
  inbox.listen((msg) {
    if (msg is _Close) {
      n.free(handle);
      inbox.close();
      return;
    }
    final job = switch (msg) {
      _ImageReq(:final job) => job,
      _VideoReq(:final job) => job,
      _ => null,
    };
    if (job == null) return;
    final prompt = job.prompt.toNativeUtf8();
    final negative = job.negative.toNativeUtf8();
    final init = job.initImage?.toNativeUtf8();
    final out = (msg is _ImageReq ? msg.out : (msg as _VideoReq).outDir)
        .toNativeUtf8();
    final rc = msg is _VideoReq
        ? n.video(
            handle,
            prompt,
            negative,
            job.width,
            job.height,
            msg.frames,
            job.steps,
            job.cfg,
            job.sampler,
            job.scheduler,
            job.seed,
            init ?? nullptr,
            job.strength,
            out,
          )
        : n.image(
            handle,
            prompt,
            negative,
            job.width,
            job.height,
            job.steps,
            job.cfg,
            job.sampler,
            job.scheduler,
            job.seed,
            init ?? nullptr,
            job.strength,
            out,
          );
    for (final p in [prompt, negative, out, ?init]) {
      calloc.free(p);
    }
    reply.send(rc < 0 ? _Fail(_codeError(rc)) : _Ok(rc));
  });
}

Object? _asEvent(Object? m) {
  if (m == null) {
    return const _Fail('Kadr AI rassomi kutilmaganda to‘xtadi.');
  }
  if (m is List && m.length == 2 && m.first is String) {
    return _Fail('Kadr AI rassomida xato: ${m.first}');
  }
  return m;
}

/// Sampling progress of the running job: [step] of [steps].
class PaintProgress {
  const PaintProgress(this.step, this.steps);
  final int step;
  final int steps;
  double get fraction => steps <= 0 ? 0 : (step / steps).clamp(0, 1);
}

/// A loaded painter. One job at a time; [cancel] stops the current one.
class KadrDiffusion {
  KadrDiffusion._(this._send, this._events, this._progress, this._handle);

  final SendPort _send;
  final Stream<Object?> _events;
  final Pointer<Int32> _progress;
  final int _handle;
  bool _busy = false;
  bool _closed = false;

  /// Loads [model] (and an AnimateDiff [motion] module for video). A TAESD
  /// [decoder] replaces the slow full VAE decoder. [weights] converts
  /// weights while loading, see [SdWeights].
  static Future<KadrDiffusion> load(
    String model, {
    String? motion,
    String? decoder,
    int threads = 0,
    int weights = SdWeights.asFile,
  }) async {
    for (final f in [model, ?motion, ?decoder]) {
      if (!File(f).existsSync()) {
        throw KadrDiffusionException('Model fayli topilmadi: $f');
      }
    }
    final port = ReceivePort();
    final events = port.asBroadcastStream();
    final progress = calloc<Int32>(2);
    await Isolate.spawn(
      _worker,
      (
        port.sendPort,
        model,
        motion,
        decoder,
        threads,
        weights,
        progress.address,
      ),
      onError: port.sendPort,
      onExit: port.sendPort,
      errorsAreFatal: true,
    );
    final first = _asEvent(await events.first);
    if (first is _Fail) {
      port.close();
      calloc.free(progress);
      throw KadrDiffusionException(
        'Rasm modelini yuklab bo‘lmadi: ${first.message}',
      );
    }
    final (send, handle) = first as (SendPort, int);
    return KadrDiffusion._(send, events, progress, handle);
  }

  PaintProgress get progress => PaintProgress(_progress[0], _progress[1]);

  Future<int> _run(Object req, void Function(PaintProgress)? onProgress) async {
    if (_closed) throw const KadrDiffusionException('Model yopilgan.');
    if (_busy) {
      throw const KadrDiffusionException('Rassom band: avvalgi ish tugamagan.');
    }
    _busy = true;
    _progress[0] = 0;
    _progress[1] = 0;
    final ticker = onProgress == null
        ? null
        : Timer.periodic(
            const Duration(milliseconds: 250),
            (_) => onProgress(progress),
          );
    try {
      _send.send(req);
      await for (final raw in _events) {
        final e = _asEvent(raw);
        if (e is _Ok) return e.value;
        if (e is _Fail) throw KadrDiffusionException(e.message);
      }
      throw const KadrDiffusionException('Rassom javob bermadi.');
    } finally {
      ticker?.cancel();
      _busy = false;
    }
  }

  /// Draws [job] into the PNG file [out].
  Future<File> paint(
    PaintJob job,
    String out, {
    void Function(PaintProgress)? onProgress,
  }) async {
    await _run(_ImageReq(job, out), onProgress);
    return File(out);
  }

  /// Animates [job] into [frames] PNG frames `f_000.png…` inside [outDir].
  /// Returns the frame files in order.
  Future<List<File>> animate(
    PaintJob job,
    int frames,
    String outDir, {
    void Function(PaintProgress)? onProgress,
  }) async {
    Directory(outDir).createSync(recursive: true);
    final count = await _run(_VideoReq(job, frames, outDir), onProgress);
    return [
      for (var i = 0; i < count; i++)
        File('$outDir/f_${i.toString().padLeft(3, '0')}.png'),
    ];
  }

  /// Stops the running job as soon as the runtime allows.
  void cancel() {
    if (_closed) return;
    _Native.instance.cancel(Pointer<Void>.fromAddress(_handle));
  }

  /// Frees the model. The progress slots stay allocated: the worker may
  /// still write them while it finishes.
  void dispose() {
    if (_closed) return;
    _closed = true;
    _send.send(const _Close());
  }

  /// Rewrites a checkpoint as GGUF with [weights] (in a background isolate).
  static Future<void> convert(String input, String output, int weights) async {
    final rc = await Isolate.run(() {
      final i = input.toNativeUtf8();
      final o = output.toNativeUtf8();
      try {
        return _Native.instance.convert(i, o, weights);
      } finally {
        calloc.free(i);
        calloc.free(o);
      }
    });
    if (rc != 0) {
      throw const KadrDiffusionException(
        'Modelni telefon uchun moslab bo‘lmadi.',
      );
    }
  }
}
