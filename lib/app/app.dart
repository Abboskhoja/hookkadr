import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/home/home_shell.dart';
import 'app_controller.dart';

class HookkadrApp extends StatelessWidget {
  const HookkadrApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AppScope(
    controller: controller,
    child: MaterialApp(
      title: 'HOOKKADR',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // Light and warm: the user's explicit choice (re-confirmed 2026-10-15
      // over pasted "cinematic dark" briefs). Only the video editor is dark —
      // it wraps itself in its own dark theme (EditorTokens.palette).
      themeMode: ThemeMode.light,
      home: const HomeShell(),
    ),
  );
}
