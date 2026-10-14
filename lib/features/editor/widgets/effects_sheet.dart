import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../analysis/domain/edit_plan.dart';
import '../../plan/plan_ops.dart';

/// Per-shot effects: transition in, speed and camera motion.
class EffectsSheet extends StatelessWidget {
  const EffectsSheet({
    super.key,
    required this.projectId,
    required this.shotId,
    required this.onChanged,
  });
  final String projectId;
  final String shotId;
  final ValueChanged<Map<String, dynamic>> onChanged;

  static const _transitions = [
    (ShotTransition.cut, 'Kesish', LucideIcons.scissors),
    (ShotTransition.crossfade, 'Crossfade', LucideIcons.blend),
    (ShotTransition.fadeBlack, 'Qora orqali', LucideIcons.moon),
    (ShotTransition.slide, 'Surish', LucideIcons.arrowLeftRight),
    (ShotTransition.zoom, 'Zoom', LucideIcons.zoomIn),
  ];
  static const _motions = [
    (ShotMotion.none, 'Yo‘q'),
    (ShotMotion.punchIn, 'Zoom-punch'),
    (ShotMotion.slowZoom, 'Sekin zoom'),
  ];
  static const _speeds = [0.5, 1.0, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final plan = AppScope.of(context).byId(projectId)?.planJson;
    if (plan == null) return const SizedBox.shrink();
    final parsed = EditPlan.fromJson(plan);
    final shot = parsed.shots.where((s) => s.id == shotId).firstOrNull;
    if (shot == null) return const SizedBox.shrink();
    final first = parsed.shots.first.id == shotId;
    Widget group(String title, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.caption(context)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Effekt', style: AppText.title(context)),
            const SizedBox(height: 14),
            group(first ? 'Boshlanish' : 'Oldingi kadrdan o‘tish', [
              for (final (t, name, icon) in _transitions)
                if (!first ||
                    t == ShotTransition.cut ||
                    t == ShotTransition.fadeBlack)
                  ChoiceChip(
                    avatar: Icon(icon, size: 16),
                    label: Text(
                      first && t == ShotTransition.fadeBlack
                          ? 'Qoradan chiqish'
                          : name,
                    ),
                    selected: shot.transition == t,
                    onSelected: (_) =>
                        onChanged(PlanOps.setTransition(plan, shotId, t.name)),
                  ),
            ]),
            if (!first)
              TextButton.icon(
                onPressed: () => onChanged(
                  PlanOps.setTransition(
                    plan,
                    null,
                    shot.transition.name,
                    seconds: shot.transitionSec,
                  ),
                ),
                icon: const Icon(LucideIcons.copyCheck, size: 16),
                label: const Text('Bu o‘tishni hamma kadrlarga qo‘llash'),
              ),
            group('Tezlik', [
              for (final sp in _speeds)
                ChoiceChip(
                  label: Text('${sp.toStringAsFixed(sp % 1 == 0 ? 0 : 1)}×'),
                  selected: shot.speed == sp,
                  onSelected: (_) =>
                      onChanged(PlanOps.setSpeed(plan, shotId, sp)),
                ),
            ]),
            group('Asl ovoz', [
              for (final (v, name) in const [
                (0.0, 'O‘chiq'),
                (0.5, '50%'),
                (1.0, '100%'),
                (1.5, '150%'),
              ])
                ChoiceChip(
                  avatar: v == 0
                      ? const Icon(LucideIcons.volumeX, size: 16)
                      : null,
                  label: Text(name),
                  selected: shot.volume == v,
                  onSelected: (_) =>
                      onChanged(PlanOps.setShotVolume(plan, shotId, v)),
                ),
            ]),
            group('Harakat', [
              for (final (m, name) in _motions)
                ChoiceChip(
                  label: Text(name),
                  selected: shot.motion == m,
                  onSelected: (_) =>
                      onChanged(PlanOps.setMotion(plan, shotId, m.name)),
                ),
            ]),
            Text(
              'Effektlar eksport qilingan videoda ko‘rinadi; muharrirdagi preview kesimlarni ko‘rsatadi.',
              style: AppText.caption(context).copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
