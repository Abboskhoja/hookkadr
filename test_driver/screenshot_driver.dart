// Driver for integration_test/ui_tour_test.dart: saves each screenshot the
// test takes to build/screenshots/<name>.png.
//
//   flutter drive --driver=test_driver/screenshot_driver.dart \
//     --target=integration_test/ui_tour_test.dart -d <simulator>
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final f = File('build/screenshots/$name.png')..createSync(recursive: true);
    f.writeAsBytesSync(bytes);
    return true;
  },
);
