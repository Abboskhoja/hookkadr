import 'package:flutter/material.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FlutterEdgeAi.initialize(inferenceEngines: const [LiteRtLmEngine()]);
  } catch (_) {
    // Offline AI stays unavailable; cloud providers keep working.
  }
  final controller = AppController(
    keys: const SecureKeyStore(),
    prefs: await SharedPreferences.getInstance(),
  );
  await controller.load();
  runApp(HookkadrApp(controller: controller));
}
