import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The header logo is there on the first frame, not a beat later.
    precacheImage(const AssetImage(kBrandLogoAsset), context);
  }

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

  static const _items = [
    LiquidGlassTabBarItem(
      icon: LucideIcons.house,
      label: 'Bosh sahifa',
      labelBuilder: _label,
    ),
    LiquidGlassTabBarItem(
      icon: LucideIcons.sparkles,
      label: 'AI Studiya',
      labelBuilder: _label,
    ),
    LiquidGlassTabBarItem(
      icon: LucideIcons.folderOpen,
      label: 'Loyihalar',
      labelBuilder: _label,
    ),
    LiquidGlassTabBarItem(
      icon: LucideIcons.layoutTemplate,
      label: 'Shablonlar',
      labelBuilder: _label,
    ),
    LiquidGlassTabBarItem(
      icon: LucideIcons.circleUserRound,
      label: 'Profil',
      labelBuilder: _label,
    ),
  ];

  /// One line, shrunk rather than wrapped, so a narrow phone or a large
  /// system font never pushes the label out of the bar.
  static Widget _label(BuildContext context, LiquidGlassLabel l) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(l.text ?? '', style: l.textStyle, maxLines: 1, softWrap: false),
  );

  /// The glass bar floats over the page: no background of its own, the
  /// screens show through it. They get this much extra bottom inset so
  /// their last row and the chat composer stay above the bar.
  static const _barHeight = 68.0, _barGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom > 0;
    final reserve = keyboard ? 0.0 : _barHeight + _barGap + 8;
    return Scaffold(
      body: Stack(
        children: [
          MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(bottom: mq.padding.bottom + reserve),
              viewPadding: mq.viewPadding.copyWith(
                bottom: mq.viewPadding.bottom + reserve,
              ),
            ),
            child: IndexedStack(
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
          ),
          LiquidGlassTabBar.withImpeller(
            items: _items,
            selectedIndex: _tab,
            onChanged: (i) => setState(() => _tab = i),
            // Hidden while typing so the chat composer has the room.
            visibility: !keyboard,
            width: (mq.size.width - 24).clamp(0, 520),
            height: _barHeight,
            margin: const EdgeInsets.only(bottom: _barGap),
            itemPadding: 4,
            itemStyle: LiquidGlassTabItemStyle(
              selectedColor: p.accent,
              unselectedColor: p.textSecondary,
              iconSize: 22,
              labelFontSize: 10.5,
            ),
            // Translucent: the selected icon is drawn under the pill.
            pillStyle: LiquidGlassTabPillStyle(
              color: p.accent.withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }
}
