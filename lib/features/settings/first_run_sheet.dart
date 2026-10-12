import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../ai/ai_clients.dart';
import 'connect_provider_sheet.dart';
import 'hookkadr_account_card.dart';
import 'login_card.dart';

Future<void> showFirstRunSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      builder: (_) => const _FirstRun(),
    );

class _FirstRun extends StatelessWidget {
  const _FirstRun();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = context.palette;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Qaysi AI bilan ishlaymiz?', style: AppText.title(context)),
            const SizedBox(height: 6),
            const SizedBox(height: 4),
            const HookkadrAccountCard(),
            const SizedBox(height: 10),
            const LoginCard(),
            const SizedBox(height: 12),
            Text('Yoki API kalit bilan', style: AppText.caption(context)),
            for (final k in ProviderKind.values.where((k) => !k.usesLogin))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  k.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  k == ProviderKind.offline && app.offlineProgress != null
                      ? 'Yuklanmoqda… ${(app.offlineProgress! * 100).round()}%'
                      : k.role,
                ),
                trailing: app.isConnected(k)
                    ? const Icon(
                        LucideIcons.circleCheck,
                        color: AppColors.success,
                      )
                    : Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: p.textSecondary,
                      ),
                onTap: () => k.needsKey
                    ? showConnectProviderSheet(context, k)
                    : app.installOffline(),
              ),
            const SizedBox(height: 8),
            Center(
              child: app.aiReady
                  ? FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Davom etish'),
                    )
                  : TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Keyinroq ulayman'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
