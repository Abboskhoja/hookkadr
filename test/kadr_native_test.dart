import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kadr_diffusion/kadr_diffusion.dart' as sd;
import 'package:kadr_llm/kadr_llm.dart' as llm;

const _modern = '''
processor\t: 0
Features\t: fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm lrcpc dcpop asimddp
processor\t: 7
Features\t: fp asimd evtstrm aes pmull sha1 sha2 crc32 atomics fphp asimdhp cpuid asimdrdm lrcpc dcpop asimddp i8mm
''';

const _cortexA53 = '''
processor\t: 0
Features\t: fp asimd evtstrm aes pmull sha1 sha2 crc32 cpuid
''';

void main() {
  group('Android CPU build choice', () {
    test('dot-product cores get the fast build', () {
      expect(llm.armDotProd(_modern), isTrue);
      expect(sd.armDotProd(_modern), isTrue);
    });

    test('old cores, mixed cores and unreadable info get the safe build', () {
      expect(llm.armDotProd(_cortexA53), isFalse);
      expect(sd.armDotProd('$_modern$_cortexA53'), isFalse);
      expect(llm.armDotProd(''), isFalse);
    });
  });

  test('both Android builds of each runtime ship in the plugins', () {
    for (final lib in [
      'kadr_llm/android/src/main/jniLibs/arm64-v8a/libkadr_llm',
      'kadr_diffusion/android/src/main/jniLibs/arm64-v8a/libkadr_sd',
    ]) {
      for (final variant in ['$lib.so', '${lib}_compat.so']) {
        final f = File('packages/$variant');
        expect(f.existsSync(), isTrue, reason: variant);
        // ELF, 64-bit, little-endian, AArch64 (e_machine 183).
        final head = f.openSync()..setPositionSync(0);
        final b = head.readSync(20);
        head.closeSync();
        expect(b.sublist(0, 4), [0x7f, 0x45, 0x4c, 0x46], reason: variant);
        expect(b[4], 2);
        expect(b[18] | b[19] << 8, 183, reason: variant);
      }
    }
  });
}
