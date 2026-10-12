import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../ai/hookkadr_cloud.dart';

/// The primary connection ("Cursor model"): sign in to HOOKKADR, the
/// server holds the AI keys and spends the user's credits.
class HookkadrAccountCard extends StatelessWidget {
  const HookkadrAccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final connected = app.cloud != null;
    final configured = kHookkadrApiUrl.isNotEmpty;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(LucideIcons.clapperboard),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'HOOKKADR hisobi',
                  style: AppText.title(context).copyWith(fontSize: 17),
                ),
              ),
              if (connected)
                const Icon(LucideIcons.circleCheck, color: AppColors.success),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Kalitsiz: kirasiz va AI ishlaydi. To‘lov HOOKKADR kreditlari bilan.',
            style: AppText.caption(context),
          ),
          const SizedBox(height: 12),
          if (connected)
            Row(
              children: [
                const Icon(LucideIcons.coins, size: 18),
                const SizedBox(width: 8),
                Text(
                  app.credits == null ? 'Kredit: …' : 'Kredit: ${app.credits}',
                  style: AppText.body(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Yangilash',
                  onPressed: app.refreshCredits,
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                ),
              ],
            )
          else if (!configured)
            Text(
              'Bu build’da HOOKKADR serveri ulanmagan.',
              style: AppText.caption(context)
                  .copyWith(color: AppColors.warning),
            )
          else
            Text(
              'Google / Apple bilan kirish Firebase loyihasi sozlangach yoqiladi.',
              style: AppText.caption(context)
                  .copyWith(color: AppColors.warning),
            ),
        ],
      ),
    );
  }
}
