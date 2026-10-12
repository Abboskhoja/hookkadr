import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/chat/chat_screen.dart';
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
      themeMode: ThemeMode.system,
      home: const ChatScreen(),
    ),
  );
}
