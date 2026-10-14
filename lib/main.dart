import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Glass is glass from the first frame, not frosted while shaders compile.
  await LiquidGlassShaders.ensureLoaded();
  final controller = AppController(
    keys: const SecureKeyStore(),
    prefs: await SharedPreferences.getInstance(),
    // Kadr AI gets itself ready; the user installs nothing.
    autoSetup: true,
  );
  await controller.load();
  runApp(HookkadrApp(controller: controller));
}
