import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/features/kadr_ai/model_catalog.dart';
import 'package:hookkadr/features/kadr_ai/model_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _gb = 1024 * 1024 * 1024;

/// A pack small enough to fake on disk.
const _tiny = KadrModelPack(
  id: 'tiny',
  title: 'tiny',
  baseModel: 'test',
  fileName: 'tiny.bin',
  url: 'https://example.invalid/tiny.bin',
  sha256: '0000000000000000000000000000000000000000000000000000000000000000',
  sizeBytes: 16,
  license: 'MIT',
  licenseUrl: 'https://example.invalid',
  minRamBytes: 0,
);

Future<AppController> _app({
  required int ram,
  required bool wifi,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final dir = Directory.systemTemp.createTempSync('kadr_root');
  return AppController(
    keys: MemoryKeyStore(),
    prefs: await SharedPreferences.getInstance(),
    unmeteredNetwork: () async => wifi,
    unmeteredChanges: () => const Stream.empty(),
    deviceRam: () => ram,
  )..models = KadrModelManager(root: () async => dir, bundled: () => null);
}

void main() {
  group('packs shipped inside the app', () {
    test('a bundled pack is ready in place and cannot be removed', () async {
      final bundle = Directory.systemTemp.createTempSync('kadr_bundle');
      final root = Directory.systemTemp.createTempSync('kadr_root');
      final shipped = File('${bundle.path}/tiny.bin')
        ..writeAsBytesSync(List.filled(16, 1));
      final m = KadrModelManager(root: () async => root, bundled: () => bundle);
      expect(m.isBundled(_tiny), isTrue);
      expect(await m.isInstalled(_tiny), isTrue);
      expect((await m.fileFor(_tiny)).path, shipped.path);
      expect(
        (await m.install(_tiny)).path,
        shipped.path,
        reason: 'no download',
      );
      await m.remove(_tiny);
      expect(shipped.existsSync(), isTrue);
    });

    test('a truncated bundled file is not trusted', () async {
      final bundle = Directory.systemTemp.createTempSync('kadr_bundle');
      final root = Directory.systemTemp.createTempSync('kadr_root');
      File('${bundle.path}/tiny.bin').writeAsBytesSync([1, 2, 3]);
      final m = KadrModelManager(root: () async => root, bundled: () => bundle);
      expect(m.isBundled(_tiny), isFalse);
      expect(await m.isInstalled(_tiny), isFalse);
      expect((await m.fileFor(_tiny)).path, startsWith(root.path));
    });

    test('the bundling script pins exactly the catalog files and hashes', () {
      final script = File('tool/bundle_kadr_models.sh').readAsStringSync();
      for (final p in KadrModelPack.all) {
        expect(
          script,
          contains('"${p.fileName}|${p.sha256}|${p.sizeBytes}"'),
          reason: p.id,
        );
      }
    });
  });

  group('automatic setup', () {
    test('the phone gets what its memory can run', () async {
      expect((await _app(ram: 4 * _gb, wifi: true)).wantedPacks, isEmpty);
      expect((await _app(ram: 6 * _gb, wifi: true)).wantedPacks, [
        KadrModelPack.brain,
        KadrModelPack.painter,
      ]);
      expect((await _app(ram: 8 * _gb, wifi: true)).wantedPacks, [
        KadrModelPack.brain,
        KadrModelPack.painter,
        KadrModelPack.motion,
      ]);
    });

    test('memory is judged by the class the phone is sold as', () async {
      // Real reported sizes: iPhone 15 Pro (8 GB), iPhone 13 Pro (6 GB),
      // a typical 8 GB and 4 GB Android phone.
      expect(
        (await _app(ram: 7994212352, wifi: true)).wantedPacks,
        contains(KadrModelPack.motion),
      );
      expect((await _app(ram: 6083182592, wifi: true)).wantedPacks, [
        KadrModelPack.brain,
        KadrModelPack.painter,
      ]);
      expect(
        (await _app(ram: 7700000000, wifi: true)).wantedPacks,
        contains(KadrModelPack.motion),
      );
      expect((await _app(ram: 3850000000, wifi: true)).wantedPacks, isEmpty);
      expect(ramClassAtLeast(0, 8 << 30), isTrue, reason: 'unknown memory');
    });

    test('big downloads wait for Wi-Fi and say so', () async {
      final app = await _app(ram: 8 * _gb, wifi: false);
      await app.autoSetupKadrAi();
      expect(app.setupState, KadrSetupState.waitingForWifi);
      expect(app.setupNote, contains('Wi-Fi'));
      expect(app.kadrReady, isFalse);
      expect(app.setupProgress, isNull);
    });

    test('nothing to do on a small phone: ready, no network used', () async {
      final app = await _app(ram: 4 * _gb, wifi: false);
      await app.autoSetupKadrAi();
      expect(app.setupState, KadrSetupState.ready);
      expect(app.kadrReady, isTrue);
    });

    test('packs the user removed are not downloaded again', () async {
      final app = await _app(
        ram: 8 * _gb,
        wifi: false,
        prefs: {
          for (final p in [
            KadrModelPack.brain,
            KadrModelPack.painter,
            KadrModelPack.motion,
          ])
            'kadr_skip_${p.id}': true,
        },
      );
      await app.autoSetupKadrAi();
      expect(app.setupState, KadrSetupState.ready);
    });

    test('the app never sets itself up in tests unless asked', () async {
      final app = await _app(ram: 8 * _gb, wifi: true);
      expect(app.autoSetup, isFalse);
    });
  });
}
