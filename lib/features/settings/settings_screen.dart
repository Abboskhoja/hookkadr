import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kadr_llm/kadr_llm.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/poster.dart';
import '../ai/hookkadr_cloud.dart';
import '../kadr_ai/model_catalog.dart';
import 'connections_screen.dart';
import 'hookkadr_account_card.dart';
import 'login_card.dart';

/// Profile and settings in plain words. Technical controls live behind the
/// "Pro rejim" switch so everyday users never meet API keys or model names.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.asTab = false});

  /// Shown as the Profile tab (no back button) rather than a pushed page.
  final bool asTab;

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(CupertinoPageRoute<void>(builder: (_) => const SettingsScreen()));

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = context.palette;
    return Scaffold(
      // Lists run under the floating glass tab bar; their own bottom
      // padding keeps the last row reachable above it.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PageHeader('Profil va sozlamalar'),
            Expanded(child: _content(context, app, p)),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppController app, AppPalette p) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              StatusDot(on: app.aiReady),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  app.offlineInstalled
                      ? 'Kadr AI telefonda tayyor: ${app.onDeviceSkills.join(', ')}.'
                            '${app.painterInstalled ? '' : ' Rasm va video uchun “Rassom”ni o‘rnating.'}'
                      : app.aiReady
                      ? 'Kadr AI ulangan hisob orqali ishlaydi. Internetsiz ishlashi '
                            'uchun pastdan “Miya”ni yuklab oling.'
                      : 'Kadr AI hali yoqilmagan. Uni telefoningizga bir marta '
                            'yuklab oling — keyin internetsiz ishlaydi.',
                  style: AppText.body(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Kadr AI telefonda', style: AppText.caption(context)),
        const SizedBox(height: 8),
        const _OnDeviceCard(KadrModelPack.brain),
        const SizedBox(height: 10),
        const _OnDeviceCard(KadrModelPack.painter),
        const SizedBox(height: 10),
        const _OnDeviceCard(KadrModelPack.motion),
        const SizedBox(height: 20),
        Text('Kadr AI xotirasi', style: AppText.caption(context)),
        const SizedBox(height: 8),
        const _MemoryCard(),
        const SizedBox(height: 20),
        Text('Hisob (ixtiyoriy)', style: AppText.caption(context)),
        const SizedBox(height: 8),
        if (kHookkadrApiUrl.isNotEmpty) ...[
          const HookkadrAccountCard(),
          const SizedBox(height: 12),
        ],
        const LoginCard(),
        const SizedBox(height: 12),
        Text(
          'Videolarni montaj qilish, kesish va eksport hisobsiz, internetsiz ham ishlaydi.',
          style: AppText.caption(context),
        ),
        const SizedBox(height: 24),
        Text('Professional', style: AppText.caption(context)),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              SwitchListTile.adaptive(
                value: app.proMode,
                onChanged: app.setProMode,
                title: const Text('Pro rejim'),
                subtitle: const Text(
                  'AI modelini tanlash, aniq sifat (720p–4K), token va prompt '
                  'ko‘rinadi, muharrirda to‘liq timeline asboblari.',
                ),
              ),
              if (app.proMode)
                ListTile(
                  leading: Icon(LucideIcons.keyRound, color: p.textSecondary),
                  title: const Text('AI ulanishlari'),
                  subtitle: const Text(
                    'O‘z API kalitingiz yoki internetsiz model',
                  ),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const ConnectionsScreen(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Ilova', style: AppText.caption(context)),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(LucideIcons.info, color: p.textSecondary),
            title: const Text('Litsenziyalar'),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () =>
                showLicensePage(context: context, applicationName: 'HOOKKADR'),
          ),
        ),
      ],
    );
  }
}

/// Kadr AI's own model on this phone: what it is, whether the phone can run
/// it, and one button to install, stop or remove it.
class _OnDeviceCard extends StatelessWidget {
  const _OnDeviceCard(this.pack);
  final KadrModelPack pack;

  IconData get _icon => switch (pack.role) {
    KadrPackRole.brain => LucideIcons.brain,
    KadrPackRole.painter || KadrPackRole.decoder => LucideIcons.palette,
    KadrPackRole.motion => LucideIcons.clapperboard,
  };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = context.palette;
    final installed = app.isPackInstalled(pack);
    final bundled = app.models.isBundled(pack);
    final progress = app.progressOf(pack);
    final error = app.errorOf(pack);
    final ram = kadrDeviceRamBytes();
    final tooSmall = !pack.fitsRam(ram);
    // Motion animates the painter's pictures; the painter needs the brain
    // to turn Uzbek requests into what it understands.
    final needs = switch (pack.role) {
      KadrPackRole.brain || KadrPackRole.decoder => null,
      KadrPackRole.painter =>
        app.offlineInstalled ? null : 'Avval “Miya”ni o‘rnating.',
      KadrPackRole.motion =>
        app.painterInstalled ? null : 'Avval “Rassom”ni o‘rnating.',
    };
    String gb(int b) => (b / (1024 * 1024 * 1024)).toStringAsFixed(0);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(_icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.title,
                      style: AppText.body(context)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(pack.purpose, style: AppText.caption(context)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${pack.baseModel} · ${pack.sizeLabel} · litsenziya ${pack.license}',
            style: AppText.caption(context).copyWith(fontSize: 12),
          ),
          if (tooSmall) ...[
            const SizedBox(height: 8),
            Text(
              'Telefoningiz xotirasi ${gb(ram)} GB — bu qism uchun kamida '
              '${gb(pack.minRamBytes)} GB kerak. Montaj va tahrir baribir ishlaydi.',
              style: const TextStyle(color: AppColors.warning, fontSize: 13),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress == 0 ? null : progress,
                minHeight: 6,
                backgroundColor: p.surfaceRaised,
                color: p.accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Yuklanmoqda… ${(progress * 100).round()}% — Wi-Fi tavsiya etiladi. '
              'To‘xtatsangiz, keyingi safar shu joydan davom etadi.',
              style: AppText.caption(context),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
          if (!installed && progress == null && needs != null) ...[
            const SizedBox(height: 8),
            Text(needs, style: AppText.caption(context)),
          ],
          const SizedBox(height: 12),
          if (bundled)
            const _StatusLine(
              LucideIcons.package,
              'Ilova ichida — o‘rnatish shart emas',
            )
          else if (installed) ...[
            const _StatusLine(
              LucideIcons.circleCheck,
              'Tayyor — internetsiz ishlaydi',
            ),
            if (app.proMode)
              TextButton(
                onPressed: () => app.removePack(pack),
                child: const Text(
                  'Telefondan o‘chirish',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
          ] else if (progress != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => app.cancelPackInstall(pack),
                child: const Text('To‘xtatish'),
              ),
            )
          else ...[
            Text(
              tooSmall
                  ? 'Bu telefonda ishlamaydi.'
                  : 'Kadr AI buni o‘zi tayyorlaydi (Wi-Fi’da, bir marta).',
              style: AppText.caption(context),
            ),
            if (!tooSmall && needs == null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => app.installPack(pack),
                  child: Text('Hozir tayyorlash (${pack.sizeLabel})'),
                ),
              ),
            ],
          ],
          TextButton(
            onPressed: () => launchUrl(Uri.parse(pack.licenseUrl)),
            child: const Text('Model va litsenziya haqida'),
          ),
        ],
      ),
    );
  }
}

/// What Kadr AI learned about the user: visible, editable, erasable.
class _MemoryCard extends StatelessWidget {
  const _MemoryCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final mem = app.memory;
    final learned = mem.learned();
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(LucideIcons.sparkles),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Kadr AI siz bilan o‘sadi: “Eslab qol: …” deb yozganlaringizni, '
                  'tanlagan uslub va formatlaringizni hamda 👍/👎 baholaringizni '
                  'eslab qoladi. Hammasi faqat shu telefonda saqlanadi.',
                  style: AppText.caption(context),
                ),
              ),
            ],
          ),
          if (mem.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Hozircha hech narsa eslab qolinmagan.',
              style: AppText.body(context),
            ),
          ],
          for (final f in mem.facts.reversed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(LucideIcons.bookmark, size: 18),
              title: Text(f),
              trailing: IconButton(
                tooltip: 'Unutish',
                icon: const Icon(LucideIcons.x, size: 18),
                onPressed: () => app.forgetFact(f),
              ),
            ),
          for (final l in learned)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l, style: AppText.body(context)),
            ),
          if (!mem.isEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: app.clearMemory,
              child: const Text(
                'Hammasini unutish',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: AppColors.success),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: AppText.body(context).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}
