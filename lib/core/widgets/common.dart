import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surface,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

/// A round liquid-glass control that floats over the page: it bends what
/// is behind it (Impeller) or frosts it (Skia), swells under the finger.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 44,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: LiquidGlassLens(
          touch: const LiquidGlassTouch(flex: LiquidGlassFlex.subtle()),
          style: LiquidGlassStyle(
            shape: LiquidGlassShape.roundedRectangle(cornerRadius: size / 2),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: Icon(icon, size: 20, color: context.palette.textPrimary),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// An icon on a small tinted glass tile. Lite glass — frost, tint and a lit
/// rim, no shader — so every card in a long list can have one for free.
class GlassIcon extends StatelessWidget {
  const GlassIcon(
    this.icon, {
    super.key,
    this.color,
    this.tint,
    this.size = 44,
    this.radius = 14,
    this.iconSize = 22,
  });
  final IconData icon;
  final Color? color;

  /// Glass tint when it should differ from the icon colour (a dark brown
  /// icon reads best on caramel glass).
  final Color? tint;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.accent;
    return SizedBox.square(
      dimension: size,
      child: LiquidGlassLite(
        shape: LiquidGlassShape.roundedRectangle(
          cornerRadius: radius,
          borderWidth: 1.2,
          lightIntensity: 1.2,
        ),
        pickup: LiquidGlassLitePickup.surface,
        color: (tint ?? c).withValues(alpha: tint == null ? 0.16 : 0.24),
        child: Center(
          child: Icon(icon, color: c, size: iconSize),
        ),
      ),
    );
  }
}

/// A screen without an app bar: the large title scrolls away with the
/// content and only what can be tapped — back and [actions], as glass —
/// stays on top, over a soft fade that keeps it legible.
class GlassPage extends StatelessWidget {
  const GlassPage({
    super.key,
    required this.title,
    required this.slivers,
    this.actions = const [],
  });
  final String title;
  final List<Widget> slivers;
  final List<Widget> actions;

  static const _controls = 60.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mq = MediaQuery.of(context);
    final canPop = Navigator.of(context).canPop();
    final floating = canPop || actions.isNotEmpty;
    final top = mq.padding.top;
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  top + (floating ? _controls : 12),
                  20,
                  8,
                ),
                sliver: SliverToBoxAdapter(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AppText.display(context, size: 30),
                    ),
                  ),
                ),
              ),
              ...slivers,
              SliverToBoxAdapter(
                child: SizedBox(height: mq.padding.bottom + 24),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + (floating ? _controls : 0) + 12,
            child: LiquidGlassScrollEdge(
              edge: LiquidGlassEdge.top,
              color: p.background.withValues(alpha: 0.92),
              blur: 6,
            ),
          ),
          if (floating)
            Positioned(
              top: top + 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  if (canPop)
                    GlassIconButton(
                      icon: LucideIcons.chevronLeft,
                      tooltip: 'Orqaga',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  const Spacer(),
                  for (final a in actions)
                    Padding(padding: const EdgeInsets.only(left: 8), child: a),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The page heading. Screens have no app bar: the title sits in the page
/// itself, pushed screens get a round back button, and nothing is painted
/// across the top of the screen.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.actions = const []});
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          if (canPop) ...[
            GlassIconButton(
              icon: LucideIcons.chevronLeft,
              tooltip: 'Orqaga',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.display(context, size: 28),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 12),
    child: Row(
      children: [
        Expanded(child: Text(text, style: AppText.title(context))),
        ?trailing,
      ],
    ),
  );
}

class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color});
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GlassIcon(icon, color: color, size: 40, radius: 12);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: context.palette.textSecondary),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppText.title(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppText.caption(context),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}
