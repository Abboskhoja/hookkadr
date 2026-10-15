import 'package:flutter_test/flutter_test.dart';

import 'package:hookkadr/features/media/clip_importer.dart';

void main() {
  test('missing picked image is reported as unavailable, not thrown', () async {
    final clip = ImportedClip(
      id: 'clip_01',
      path: '/tmp/hookkadr-image-that-does-not-exist.jpg',
      name: 'yo‘q.jpg',
    );

    await expectLater(ClipImporter().measure(clip), completes);
    expect(clip.sizeBytes, isNull);
    expect(clip.thumb, isNull);
  });
}
