import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../chat/chat_screen.dart';
import '../projects/projects_screen.dart';
import '../settings/settings_screen.dart';
import 'home_screen.dart';
import 'templates_screen.dart';

/// App root: Home · AI Studio (Kadr AI) · Projects · Templates · Profile.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _home = 0, _studio = 1, _projects = 2, _profile = 4;
  int _tab = _home;
  final _requests = ValueNotifier<KadrRequest?>(null);

  @override
  void dispose() {
    _requests.dispose();
    super.dispose();
  }

  void _ask(KadrRequest r) {
    setState(() => _tab = _studio);
    // A fresh object each time so repeated taps still notify.
    _requests.value = KadrRequest(
      r.mode,
      text: r.text,
      aspect: r.aspect,
      seconds: r.seconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(
            onAsk: _ask,
            onOpenProfile: () => setState(() => _tab = _profile),
            onOpenProjects: () => setState(() => _tab = _projects),
          ),
          ChatScreen(
            onOpenProjects: () => setState(() => _tab = _projects),
            requests: _requests,
          ),
          const ProjectsScreen(),
          TemplatesScreen(onAsk: _ask),
          const SettingsScreen(asTab: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: p.surface,
        indicatorColor: p.selected,
        selectedIndex: _tab,
        height: 68,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.house),
            label: 'Bosh sahifa',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.sparkles),
            label: 'AI Studiya',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.folderOpen),
            label: 'Loyihalar',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.layoutTemplate),
            label: 'Shablonlar',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.circleUserRound),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
