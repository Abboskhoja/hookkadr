import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/vision/scene_quality_scanner.dart';

void main() {
  test('P6 preserves whitespace and comment-valued pixel bytes', () {
    final pixels = [10, 32, 35, ...List.filled(429, 128)];
    final frame = decodeAnalysisPpm(
      Uint8List.fromList([...'P6\n# frame\n12 12\n255\n'.codeUnits, ...pixels]),
    );
    expect(frame.width, 12);
    expect(frame.height, 12);
    expect(frame.rgb, pixels);
  });
  test('P6 rejects truncated, oversized and incompatible frames', () {
    for (final data in [
      [...'P6\n12 12\n255\n'.codeUnits, ...List.filled(431, 0)],
      [...'P6\n12 12\n255\n'.codeUnits, ...List.filled(433, 0)],
      'P6\n400 12\n255\n'.codeUnits,
      'P6\n12 12\n65535\n'.codeUnits,
      'P3\n12 12\n255\n'.codeUnits,
      'P6\n-1 12\n255\n'.codeUnits,
    ]) {
      expect(
        () => decodeAnalysisPpm(Uint8List.fromList(data)),
        throwsFormatException,
      );
    }
  });
}
