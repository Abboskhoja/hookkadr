/// Kadr AI on-device language model runtime.
///
/// A GGUF model runs inside its own isolate through a small C surface
/// (`src/kadr_llm.h`) over llama.cpp, so generation never blocks the UI.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

class KadrLlmException implements Exception {
  const KadrLlmException(this.message);
  final String message;
  @override
  String toString() => 'KadrLlmException: $message';
}

// ------------------------------------------------------------------ bindings

typedef _LoadC =
    Pointer<Void> Function(
      Pointer<Utf8>,
      Int32,
      Int32,
      Int32,
      Pointer<Utf8>,
      Int32,
    );
typedef _LoadD =
    Pointer<Void> Function(Pointer<Utf8>, int, int, int, Pointer<Utf8>, int);
typedef _StartC =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Float,
      Int32,
      Pointer<Utf8>,
      Uint32,
    );
typedef _StartD =
    int Function(Pointer<Void>, Pointer<Utf8>, double, int, Pointer<Utf8>, int);
typedef _BufC = Int32 Function(Pointer<Void>, Pointer<Uint8>, Int32);
typedef _BufD = int Function(Pointer<Void>, Pointer<Uint8>, int);
typedef _GenC = Int32 Function(Pointer<Void>);
typedef _GenD = int Function(Pointer<Void>);
typedef _FreeC = Void Function(Pointer<Void>);
typedef _FreeD = void Function(Pointer<Void>);
typedef _RamC = Int64 Function();
typedef _RamD = int Function();

final class _Native {
  _Native(DynamicLibrary lib)
    : load = lib.lookupFunction<_LoadC, _LoadD>('kadr_llm_load'),
      start = lib.lookupFunction<_StartC, _StartD>('kadr_llm_start'),
      next = lib.lookupFunction<_BufC, _BufD>('kadr_llm_next'),
      generated = lib.lookupFunction<_GenC, _GenD>('kadr_llm_generated'),
      info = lib.lookupFunction<_BufC, _BufD>('kadr_llm_info'),
      free = lib.lookupFunction<_FreeC, _FreeD>('kadr_llm_free'),
      ram = lib.lookupFunction<_RamC, _RamD>('kadr_device_ram_bytes');

  final _LoadD load;
  final _StartD start;
  final _BufD next;
  final _GenD generated;
  final _BufD info;
  final _FreeD free;
  final _RamD ram;

  static _Native? _instance;
  static _Native get instance => _instance ??= _Native(_open());

  static DynamicLibrary _open() {
    if (Platform.isIOS || Platform.isMacOS) {
      return DynamicLibrary.open('KadrLlm.framework/KadrLlm');
    }
    if (Platform.isAndroid) return DynamicLibrary.open('libkadr_llm.so');
    throw const KadrLlmException(
      'Kadr AI runtime faqat iOS va Androidda ishlaydi.',
    );
  }
}

/// Is the native runtime linked into this build?
bool kadrLlmAvailable() {
  try {
    _Native.instance;
    return true;
  } catch (_) {
    return false;
  }
}

/// Physical memory of the device in bytes, 0 when unknown.
int kadrDeviceRamBytes() {
  try {
    return _Native.instance.ram();
  } catch (_) {
    return 0;
  }
}

String _startError(int code) => switch (code) {
  -1 => 'So‘rov model xotirasiga sig‘madi (juda uzun).',
  -2 => 'Matnni tokenlarga ajratib bo‘lmadi.',
  -3 => 'Model hisoblashda xato berdi.',
  -4 => 'Javob formati (grammatika) noto‘g‘ri.',
  _ => 'Noma’lum xato ($code).',
};

// ------------------------------------------------------------------ isolate

sealed class _Req {}

final class _Gen extends _Req {
  _Gen(this.prompt, this.temperature, this.maxTokens, this.grammar, this.seed);
  final String prompt;
  final double temperature;
  final int maxTokens;
  final String? grammar;
  final int seed;
}

final class _Close extends _Req {}

/// Messages from the worker: String chunk, `_Done`, or `_Fail`.
final class _Done {
  const _Done(this.tokens);
  final int tokens;
}

final class _Fail {
  const _Fail(this.message);
  final String message;
}

void _worker((SendPort, String, int, int, int, int) args) {
  final (reply, path, ctx, threads, gpu, cancelAddr) = args;
  final n = _Native.instance;
  final cancel = Pointer<Int32>.fromAddress(cancelAddr);
  final err = calloc<Uint8>(256);
  final p = path.toNativeUtf8();
  final handle = n.load(p, ctx, threads, gpu, err.cast(), 256);
  calloc.free(p);
  if (handle == nullptr) {
    reply.send(_Fail(err.cast<Utf8>().toDartString()));
    calloc.free(err);
    return;
  }
  calloc.free(err);
  final infoBuf = calloc<Uint8>(256);
  n.info(handle, infoBuf, 256);
  final info = infoBuf.cast<Utf8>().toDartString();
  calloc.free(infoBuf);

  final inbox = ReceivePort();
  reply.send((inbox.sendPort, info));
  final buf = calloc<Uint8>(4096);
  inbox.listen((msg) {
    if (msg is _Close) {
      n.free(handle);
      calloc.free(buf);
      inbox.close();
      return;
    }
    if (msg is! _Gen) return;
    final prompt = msg.prompt.toNativeUtf8();
    final grammar = msg.grammar?.toNativeUtf8();
    final rc = n.start(
      handle,
      prompt,
      msg.temperature,
      msg.maxTokens,
      grammar ?? nullptr,
      msg.seed,
    );
    calloc.free(prompt);
    if (grammar != null) calloc.free(grammar);
    if (rc < 0) {
      reply.send(_Fail(_startError(rc)));
      return;
    }
    while (true) {
      if (cancel.value != 0) break;
      final len = n.next(handle, buf, 4096);
      if (len == -1) break;
      if (len < 0) {
        reply.send(_Fail(_startError(len)));
        return;
      }
      // The C side only hands out complete UTF-8 characters.
      if (len > 0) {
        reply.send(utf8.decode(Uint8List.fromList(buf.asTypedList(len))));
      }
    }
    reply.send(_Done(n.generated(handle)));
  });
}

/// Worker messages, plus isolate error ([message, stack] list) and exit
/// (null) notifications turned into failures.
Object? _asEvent(Object? m) {
  if (m == null) return const _Fail('Kadr AI jarayoni kutilmaganda to‘xtadi.');
  if (m is List && m.length == 2 && m.first is String) {
    return _Fail('Kadr AI jarayonida xato: ${m.first}');
  }
  return m;
}

/// A loaded model. One generation at a time; [cancel] stops the current one.
class KadrLlm {
  KadrLlm._(this._send, this._events, this._cancel, this.info);

  final SendPort _send;
  final Stream<Object?> _events;
  final Pointer<Int32> _cancel;

  /// llama.cpp description: "arch size quant|params|bytes|context".
  final String info;
  bool _busy = false;
  bool _closed = false;

  static Future<KadrLlm> load(
    String path, {
    int contextSize = 4096,
    int threads = 4,
    int gpuLayers = 99,
  }) async {
    if (!File(path).existsSync()) {
      throw KadrLlmException('Model fayli topilmadi: $path');
    }
    final port = ReceivePort();
    final events = port.asBroadcastStream();
    final cancel = calloc<Int32>()..value = 0;
    // If the worker dies (native crash in Dart code, missing library), its
    // error and exit arrive here as _Fail instead of leaving callers waiting.
    await Isolate.spawn(
      _worker,
      (port.sendPort, path, contextSize, threads, gpuLayers, cancel.address),
      onError: port.sendPort,
      onExit: port.sendPort,
      errorsAreFatal: true,
    );
    final first = _asEvent(await events.first);
    if (first is _Fail) {
      port.close();
      calloc.free(cancel);
      throw KadrLlmException('Modelni yuklab bo‘lmadi: ${first.message}');
    }
    final (send, info) = first as (SendPort, String);
    return KadrLlm._(send, events, cancel, info);
  }

  /// Streams the reply to a prompt that is already in the model's chat format.
  Stream<String> generate(
    String prompt, {
    double temperature = 0.4,
    int maxTokens = 512,
    String? grammar,
    int seed = 42,
  }) async* {
    if (_closed) throw const KadrLlmException('Model yopilgan.');
    if (_busy) {
      throw const KadrLlmException('Model band: avvalgi javob tugamagan.');
    }
    _busy = true;
    _cancel.value = 0;
    try {
      _send.send(_Gen(prompt, temperature, maxTokens, grammar, seed));
      await for (final raw in _events) {
        final e = _asEvent(raw);
        if (e is String) {
          yield e;
        } else if (e is _Done) {
          return;
        } else if (e is _Fail) {
          throw KadrLlmException(e.message);
        }
      }
    } finally {
      _busy = false;
    }
  }

  void cancel() => _cancel.value = 1;

  /// Frees the model. The 4-byte cancel flag is intentionally kept: the
  /// worker may still read it while it finishes the current token.
  void dispose() {
    if (_closed) return;
    _closed = true;
    _send.send(_Close());
  }
}
