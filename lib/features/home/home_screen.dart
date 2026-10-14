import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/poster.dart';
import '../chat/chat_screen.dart';
import '../editor/editor_screen.dart';
import '../product_ad/presentation/product_ad_flow.dart';

/// Home: one place to start anything, in plain words.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onAsk,
    required this.onOpenProfile,
    required this.onOpenProjects,
  });

  /// Opens AI Studio with a mode/text.
  final ValueChanged<KadrRequest> onAsk;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenProjects;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = context.palette;
    final actions = <_QuickAction>[
      _QuickAction(
        LucideIcons.images,
        'Rasmlardan reklama',
        'Internetsiz · musiqa bilan',
        true,
        () => startProductAd(context),
      ),
      _QuickAction(
        LucideIcons.clapperboard,
        'AI video',
        app.painterInstalled
            ? 'Kadr AI chizadi va yig‘adi'
            : 'Ssenariydan video',
        false,
        () => onAsk(const KadrRequest(KadrMode.video)),
      ),
      _QuickAction(
        LucideIcons.palette,
        'Rasm yaratish',
        app.painterInstalled
            ? 'Telefonda, internetsiz'
            : 'Kadr AI tayyorlanmoqda',
        false,
        () => onAsk(const KadrRequest(KadrMode.image)),
      ),
      _QuickAction(
        LucideIcons.scissors,
        'Videodan montaj',
        'Pauza va sahnalar avtomatik',
        true,
        () => onAsk(const KadrRequest(KadrMode.montage)),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const BrandLogo(key: ValueKey('brand-logo'), size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HOOKKADR', style: AppText.title(context)),
                          Text('Kadr AI bilan', style: AppText.micro(context)),
                        ],
                      ),
                    ),
                    _AiStatus(onTap: onOpenProfile),
                  ],
                ),
              ),
            ),
            if (!app.kadrReady)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _SetupBanner(onOpenProfile: onOpenProfile),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(child: _Hero(onAsk: onAsk)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Text('Tez boshlash', style: AppText.title(context)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverLayoutBuilder(
                builder: (context, c) => SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: c.crossAxisExtent >= 600 ? 4 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 142,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _QuickCard(action: actions[i]),
                    childCount: actions.length,
                  ),
                ),
              ),
            ),
            if (app.projects.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 26, 8, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Oxirgi loyihalar',
                          style: AppText.title(context),
                        ),
                      ),
                      TextButton(
                        onPressed: onOpenProjects,
                        child: const Text('Hammasi'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 190,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: app.projects.length.clamp(0, 10),
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final pr = app.projects[i];
                      return SizedBox(
                        width: 140,
                        child: ProjectPosterCard(
                          title: pr.name,
                          plan: pr.planJson,
                          onTap: () => Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) => EditorScreen(projectId: pr.id),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                // Scrolls under the glass tab bar, but the last line can
                // always be brought above it.
                padding: EdgeInsets.fromLTRB(
                  16,
                  22,
                  16,
                  28 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.shieldCheck,
                      size: 15,
                      color: AppColors.brown,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        app.painterInstalled
                            ? 'Suhbat, rasm, video va montaj telefonda — internetsiz.'
                            : 'Montaj, kesish va saqlash internetsiz ishlaydi.',
                        textAlign: TextAlign.center,
                        style: AppText.caption(context)
                            .copyWith(color: p.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.icon, this.title, this.hint, this.warm, this.onTap);
  final IconData icon;
  final String title;
  final String hint;

  /// Light-brown accent (otherwise blue), so the grid alternates calmly.
  final bool warm;
  final VoidCallback onTap;
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.action});
  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tint = action.warm ? AppColors.brown : AppColors.blue;
    final bubble = action.warm ? AppColors.sand : AppColors.sky;
    return Semantics(
      button: true,
      label: action.title,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: action.onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: p.separator, width: 0.8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F5A4632),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bubble,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(action.icon, color: tint, size: 22),
                ),
                const Spacer(),
                Text(
                  action.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  action.hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(context).copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onAsk});
  final ValueChanged<KadrRequest> onAsk;

  static const _ideas = [
    ('Kafe uchun reklama video', KadrMode.video),
    ('Tog‘ manzarasi rasmi', KadrMode.image),
    ('Reels uchun 5 ta g‘oya', KadrMode.question),
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    decoration: BoxDecoration(
      gradient: AppColors.brandGradient,
      borderRadius: BorderRadius.circular(26),
      boxShadow: const [
        BoxShadow(
          color: Color(0x332563C9),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nima yaratamiz?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Kadr AI’ga o‘z so‘zingiz bilan yozing.',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        const SizedBox(height: 16),
        Semantics(
          button: true,
          label: 'Kadr AI bilan boshlash',
          child: GestureDetector(
            onTap: () => onAsk(const KadrRequest(null)),
            child: Container(
              height: 54,
              padding: const EdgeInsets.only(left: 16, right: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(27),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.sparkles,
                    size: 18,
                    color: AppColors.blue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'G‘oyangizni yozing…',
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.arrowRight,
                      size: 17,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (text, mode) in _ideas)
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: () => onAsk(KadrRequest(mode, text: text)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: AppColors.brown,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

/// Kadr AI preparing itself: honest progress, no install buttons.
class _SetupBanner extends StatelessWidget {
  const _SetupBanner({required this.onOpenProfile});
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = context.palette;
    final progress = app.setupProgress;
    final (title, body) = switch (app.setupState) {
      KadrSetupState.running => (
        'Kadr AI tayyorlanmoqda… ${((progress ?? 0) * 100).round()}%',
        'Bir martalik. Keyin suhbat, rasm va video internetsiz ishlaydi.',
      ),
      KadrSetupState.waitingForWifi => (
        'Kadr AI Wi-Fi’ni kutmoqda',
        app.setupNote ?? 'Wi-Fi’ga ulanganda o‘zi tayyorlanadi.',
      ),
      KadrSetupState.failed => (
        'Kadr AI tayyorlanmadi',
        app.setupNote ?? 'Internetni tekshirib qayta urinib ko‘ring.',
      ),
      _ => (
        'Kadr AI tayyorlanmoqda',
        'Bir martalik. Keyin hammasi internetsiz ishlaydi.',
      ),
    };
    final waiting = app.setupState == KadrSetupState.waitingForWifi;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.warmGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.separator, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 18,
                color: AppColors.brown,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppText.body(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(body, style: AppText.caption(context)),
          if (app.setupState == KadrSetupState.running) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (progress ?? 0) == 0 ? null : progress,
                minHeight: 6,
                backgroundColor: Colors.white,
                color: AppColors.blue,
              ),
            ),
          ],
          if (waiting || app.setupState == KadrSetupState.failed) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => app.autoSetupKadrAi(allowCellular: waiting),
                  child: Text(
                    waiting ? 'Mobil internet orqali' : 'Qayta urinish',
                  ),
                ),
                TextButton(
                  onPressed: onOpenProfile,
                  child: const Text('Batafsil'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AiStatus extends StatelessWidget {
  const _AiStatus({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = context.palette;
    final ready = app.offlineInstalled;
    final progress = app.setupProgress;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: ready ? AppColors.sky : AppColors.sand,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ready ? LucideIcons.circleCheck : LucideIcons.loader,
                size: 15,
                color: ready ? AppColors.blue : AppColors.brown,
              ),
              const SizedBox(width: 6),
              Text(
                ready
                    ? 'Kadr AI tayyor'
                    : progress != null
                    ? 'Kadr AI ${(progress * 100).round()}%'
                    : 'Kadr AI',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
