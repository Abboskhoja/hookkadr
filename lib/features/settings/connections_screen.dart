import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../ai/ai_clients.dart';
import '../kadr_ai/model_catalog.dart';
import '../ai/openrouter.dart';
import 'connect_provider_sheet.dart';
import 'hookkadr_account_card.dart';
import 'login_card.dart';

String maskKey(String k) => k.length <= 8
    ? '••••'
    : '${k.substring(0, 4)}••••${k.substring(k.length - 4)}';

class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({super.key});

  static const _models = {
    ProviderKind.claude: ClaudeClient.defaultModel,
    ProviderKind.openai: OpenAiClient.defaultModel,
    ProviderKind.gemini: GeminiClient.defaultModel,
    ProviderKind.offline: 'Gemma 4 E2B (telefonda)',
    ProviderKind.openrouter: OpenRouterClient.planModel,
    ProviderKind.hookkadr: 'Server: Claude + Gemini',
  };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader('AI ulanishlari'),
            Expanded(child: _content(context, app, p)),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppController app, AppPalette p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          'Bir nechta AI ulang. Auto rejimida HOOKKADR har bir vazifaga '
          'mosini o‘zi tanlaydi.',
          style: AppText.caption(context),
        ),
        const SizedBox(height: 16),
        const HookkadrAccountCard(),
        const SizedBox(height: 10),
        const LoginCard(),
        const SizedBox(height: 10),
        const _OfflineCard(),
        const SectionTitle('API kalit (ilg‘or)'),
        for (final k in ProviderKind.values.where(
          (k) => k.needsKey && !k.usesLogin,
        )) ...[
          AppCard(
            child: Row(
              children: [
                IconBadge(switch (k) {
                  ProviderKind.hookkadr => LucideIcons.clapperboard,
                  ProviderKind.openrouter => LucideIcons.logIn,
                  ProviderKind.claude => LucideIcons.sparkles,
                  ProviderKind.openai => LucideIcons.brainCircuit,
                  ProviderKind.gemini => LucideIcons.eye,
                  ProviderKind.offline => LucideIcons.smartphone,
                }),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k.label,
                        style: AppText.body(context)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(k.role, style: AppText.caption(context)),
                      const SizedBox(height: 4),
                      Text(
                        app.isConnected(k)
                            ? 'Ulangan · ${maskKey(app.keyOf(k)!)}'
                            : 'Ulanmagan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: app.isConnected(k)
                              ? AppColors.success
                              : p.textSecondary,
                        ),
                      ),
                      Text(
                        'Model: ${_models[k]}',
                        style: AppText.caption(context).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                app.isConnected(k)
                    ? TextButton(
                        onPressed: () => app.disconnect(k),
                        child: const Text(
                          'Uzish',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      )
                    : TextButton(
                        onPressed: () => showConnectProviderSheet(context, k),
                        child: const Text('Ulash'),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SectionTitle('Maxfiylik'),
        Text(
          'Videolar faqat Gemini’ga (video tahlili uchun) yuboriladi, '
          'har safar avval ruxsat so‘raladi. Matn va tahlil natijalari '
          'tanlangan reja tuzuvchi AI’ga (Claude / OpenAI / Gemini) boradi. '
          'Kalitlar loyihalardan alohida, xavfsiz xotirada turadi.',
          style: AppText.caption(context),
        ),
        const SectionTitle('Muhim'),
        Text(
          'ChatGPT Plus/Pro yoki Claude Pro obunasi API ruxsatini bermaydi: '
          'ulanish API kaliti orqali. “ChatGPT bilan kirish” OpenAI’ning '
          'hamkorlik tasdig‘ini talab qiladi va hozircha mavjud emas.',
          style: AppText.caption(context),
        ),
      ],
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = context.palette;
    final progress = app.offlineProgress;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(LucideIcons.smartphone),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kadr AI (internetsiz)',
                      style: AppText.body(context)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ProviderKind.offline.role,
                      style: AppText.caption(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app.offlineInstalled
                          ? 'O‘rnatilgan · ${KadrModelPack.brain.baseModel}'
                          : '${KadrModelPack.brain.baseModel} · ${KadrModelPack.brain.sizeLabel} bir marta yuklanadi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: app.offlineInstalled
                            ? AppColors.success
                            : p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (progress == null)
                app.offlineInstalled
                    ? TextButton(
                        onPressed: app.removeOffline,
                        child: const Text(
                          'O‘chirish',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      )
                    : TextButton(
                        onPressed: app.installOffline,
                        child: const Text('Yuklab olish'),
                      ),
            ],
          ),
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
              'Yuklanmoqda… ${(progress * 100).round()}%',
              style: AppText.caption(context),
            ),
          ],
          if (app.offlineError != null) ...[
            const SizedBox(height: 8),
            Text(
              app.offlineError!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Internetsiz suhbat va montaj rejasi. Kichik model: bulutli AI’dan '
            'soddaroq javob beradi va videoni ko‘ra olmaydi (faqat izoh va '
            'davomiylik bo‘yicha reja tuzadi). Render har doim offline ishlaydi.',
            style: AppText.caption(context).copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
