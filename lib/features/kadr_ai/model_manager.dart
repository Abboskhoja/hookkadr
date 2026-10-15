import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'model_catalog.dart';

class ModelInstallException implements Exception {
  const ModelInstallException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lets the user stop a running download; the partial file is kept so the
/// next attempt resumes where it stopped.
class DownloadToken {
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Installs model packs on the device: resumable download, SHA-256 check
/// against the catalog, then a `.verified` marker so later launches do not
/// rehash gigabytes. A file that fails the check is deleted, never used.
///
/// Packs shipped inside the app (iOS: `Runner.app/KadrModels`, prepared by
/// `tool/bundle_kadr_models.sh`, SHA-256 checked at build time; Android: the
/// app's own external files dir, pushed ahead of time by
/// `tool/push_kadr_models_android.sh` for a direct/sideloaded install — no
/// store size cap to route around, but nothing short enough to ship through
/// Play Store either) are used in place: nothing to download, copy or
/// install.
class KadrModelManager {
  KadrModelManager({
    Future<Directory> Function()? root,
    this.client,
    Directory? Function()? bundled,
  }) : _root = root ?? _defaultRoot,
       _bundled = bundled ?? _defaultBundled;

  final Future<Directory> Function() _root;
  final Directory? Function() _bundled;

  static Directory? _defaultBundled() {
    if (Platform.isIOS) {
      final app = File(Platform.resolvedExecutable).parent.path;
      return Directory('$app/KadrModels');
    }
    if (Platform.isAndroid) {
      // The app's own external files dir — no storage permission needed
      // (API 19+) and, unlike app-internal storage, reachable by `adb push`
      // before the app has ever run. Built from the well-known primary
      // external storage path and the app's own package name rather than
      // a path_provider call, so this stays the synchronous check every
      // other bundled-pack lookup in this class already is.
      return Directory(
        '/storage/emulated/0/Android/data/com.hookkadr.hookkadr/files/KadrModels',
      );
    }
    return null;
  }

  /// The pack's file inside the app bundle, if the build shipped it.
  File? bundledFile(KadrModelPack pack) {
    final dir = _bundled();
    if (dir == null) return null;
    final f = File('${dir.path}/${pack.fileName}');
    return f.existsSync() && f.lengthSync() == pack.sizeBytes ? f : null;
  }

  /// Shipped with the app: always ready, cannot be removed.
  bool isBundled(KadrModelPack pack) => bundledFile(pack) != null;

  /// Injected in tests; a fresh client per download otherwise.
  final http.Client? client;

  static Future<Directory> _defaultRoot() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/kadr_models');

  Future<File> fileFor(KadrModelPack pack) async =>
      bundledFile(pack) ?? _downloaded(pack);

  Future<File> _downloaded(KadrModelPack pack) async =>
      File('${(await _root()).path}/${pack.fileName}');

  static http.Client _newClient() => http.Client();

  Future<File> _marker(KadrModelPack pack) async =>
      File('${(await _root()).path}/${pack.fileName}.verified');

  Future<bool> isInstalled(KadrModelPack pack) async {
    if (isBundled(pack)) return true;
    final f = await _downloaded(pack);
    final m = await _marker(pack);
    return f.existsSync() &&
        f.lengthSync() == pack.sizeBytes &&
        m.existsSync() &&
        m.readAsStringSync().trim() == pack.sha256;
  }

  /// Downloads [pack] (resuming a partial file) and verifies it.
  /// [onProgress] gets 0..1 of the total size.
  Future<File> install(
    KadrModelPack pack, {
    void Function(double progress)? onProgress,
    DownloadToken? token,
  }) async {
    final shipped = bundledFile(pack);
    if (shipped != null) return shipped;
    final dir = await _root();
    dir.createSync(recursive: true);
    final target = await _downloaded(pack);
    final part = File('${target.path}.part');
    final web = client ?? _newClient();
    try {
      var have = part.existsSync() ? part.lengthSync() : 0;
      if (have > pack.sizeBytes) {
        part.deleteSync();
        have = 0;
      }
      if (have < pack.sizeBytes) {
        final req = http.Request('GET', Uri.parse(pack.url));
        if (have > 0) req.headers['Range'] = 'bytes=$have-';
        final res = await web.send(req);
        if (res.statusCode == 200 && have > 0) {
          have = 0; // server ignored the range: start over
        } else if (res.statusCode != 200 && res.statusCode != 206) {
          throw ModelInstallException(
            'Modelni yuklab bo‘lmadi (server javobi ${res.statusCode}).',
          );
        }
        final sink = part.openWrite(
          mode: have > 0 ? FileMode.append : FileMode.write,
        );
        var got = have;
        try {
          await for (final chunk in res.stream) {
            if (token?.cancelled ?? false) {
              throw const ModelInstallException('Yuklash to‘xtatildi.');
            }
            sink.add(chunk);
            got += chunk.length;
            onProgress?.call((got / pack.sizeBytes).clamp(0, 1).toDouble());
          }
        } finally {
          await sink.close();
        }
      }
      if (part.lengthSync() != pack.sizeBytes) {
        throw const ModelInstallException(
          'Yuklash tugamadi — internet uzilgan bo‘lishi mumkin. Qayta urinib ko‘ring, '
          'yuklangan qismi saqlanadi.',
        );
      }
      final digest = (await sha256.bind(part.openRead()).first).toString();
      if (digest != pack.sha256) {
        part.deleteSync();
        throw const ModelInstallException(
          'Yuklangan fayl tekshiruvdan o‘tmadi (SHA-256 mos emas) va o‘chirildi.',
        );
      }
      part.renameSync(target.path);
      (await _marker(pack)).writeAsStringSync(pack.sha256);
      return target;
    } on SocketException {
      throw const ModelInstallException(
        'Internet yo‘q. Model bir marta yuklab olinadi, keyin internetsiz ishlaydi.',
      );
    } finally {
      if (client == null) web.close();
    }
  }

  /// Registers a file that is already on the device (e.g. copied by a
  /// developer) after verifying it against the catalog.
  Future<bool> adoptExisting(KadrModelPack pack) async {
    if (isBundled(pack)) return true;
    final f = await _downloaded(pack);
    if (!f.existsSync() || f.lengthSync() != pack.sizeBytes) return false;
    final digest = (await sha256.bind(f.openRead()).first).toString();
    if (digest != pack.sha256) return false;
    (await _marker(pack)).writeAsStringSync(pack.sha256);
    return true;
  }

  Future<void> remove(KadrModelPack pack) async {
    for (final f in [
      await _downloaded(pack),
      await _marker(pack),
      File('${(await _downloaded(pack)).path}.part'),
    ]) {
      if (f.existsSync()) f.deleteSync();
    }
  }
}
