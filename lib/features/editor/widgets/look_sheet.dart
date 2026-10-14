import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../analysis/domain/edit_plan.dart';
import '../../plan/plan_ops.dart';

/// Whole-video look (colour grade presets + fine sliders), output format and
/// the logo end card. Everything shown here is rendered into the MP4.
class LookSheet extends StatefulWidget {
  const LookSheet({
    super.key,
    required this.projectId,
    required this.onChanged,
    required this.onPickLogo,
  });
  final String projectId;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final Future<void> Function() onPickLogo;

  @override
  State<LookSheet> createState() => _LookSheetState();
}

class _LookSheetState extends State<LookSheet> {
  ColorGrade? _grade;
  bool _loaded = false;

  static const _presetNames = {
    'kino': 'Kino',
    'iliq': 'Iliq',
    'sovuq': 'Sovuq',
    'jonli': 'Jonli',
  };

  @override
  Widget build(BuildContext context) {
    final json = AppScope.of(context).byId(widget.projectId)?.planJson;
    if (json == null) return const SizedBox.shrink();
    final plan = EditPlan.fromJson(json);
    if (!_loaded) {
      _grade = plan.grade;
      _loaded = true;
    }
    final g = _grade ?? const ColorGrade();
    final project = AppScope.of(context).byId(widget.projectId)!;
    final logoClip = project.clip(plan.logo?.clipId);

    void setGrade(ColorGrade? next) {
      setState(() => _grade = next);
      widget.onChanged(PlanOps.setGrade(json, next));
    }

    Widget slider(
      String label,
      double value,
      double min,
      double max,
      ColorGrade Function(double) build,
    ) => Row(
      children: [
        SizedBox(width: 92, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            onChanged: (v) => setState(() => _grade = build(v)),
            onChangeEnd: (v) => setGrade(build(v)),
          ),
        ),
      ],
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ko‘rinish', style: AppText.title(context)),
            const SizedBox(height: 14),
            Text('Rang uslubi', style: AppText.caption(context)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Asl'),
                  selected: _grade == null || _grade!.isNeutral,
                  onSelected: (_) => setGrade(null),
                ),
                for (final e in ColorGrade.presets.entries)
                  ChoiceChip(
                    label: Text(_presetNames[e.key] ?? e.key),
                    selected: _grade != null && _same(_grade!, e.value),
                    onSelected: (_) => setGrade(e.value),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            slider(
              'Yorug‘lik',
              g.exposure,
              -0.5,
              0.5,
              (v) => ColorGrade(
                exposure: v,
                contrast: g.contrast,
                saturation: g.saturation,
                temperature: g.temperature,
              ),
            ),
            slider(
              'Kontrast',
              g.contrast,
              0.5,
              2,
              (v) => ColorGrade(
                exposure: g.exposure,
                contrast: v,
                saturation: g.saturation,
                temperature: g.temperature,
              ),
            ),
            slider(
              'To‘yinganlik',
              g.saturation,
              0,
              2.5,
              (v) => ColorGrade(
                exposure: g.exposure,
                contrast: g.contrast,
                saturation: v,
                temperature: g.temperature,
              ),
            ),
            slider(
              'Harorat',
              g.temperature,
              -1,
              1,
              (v) => ColorGrade(
                exposure: g.exposure,
                contrast: g.contrast,
                saturation: g.saturation,
                temperature: v,
              ),
            ),
            const SizedBox(height: 10),
            Text('Format', style: AppText.caption(context)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in kAspectRatios)
                  ChoiceChip(
                    label: Text(a),
                    selected: plan.aspectRatio == a,
                    onSelected: (_) => widget.onChanged(
                      PlanOps.setFormat(json, aspectRatio: a),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Logotip (oxirida)', style: AppText.caption(context)),
            const SizedBox(height: 6),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onPickLogo,
                  icon: const Icon(LucideIcons.image, size: 18),
                  label: Text(
                    logoClip == null ? 'Rasm tanlash' : 'Boshqasini tanlash',
                  ),
                ),
                if (logoClip != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${logoClip.name} · oxirgi '
                      '${plan.logo!.durationSec.toStringAsFixed(1)} s',
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption(context),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Logotipni olib tashlash',
                    onPressed: () =>
                        widget.onChanged(PlanOps.setLogo(json, null)),
                    icon: const Icon(
                      LucideIcons.trash2,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Rang va logotip eksport qilingan videoda ko‘rinadi; muharrirdagi '
              'preview kesimlarni ko‘rsatadi.',
              style: AppText.caption(context).copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  static bool _same(ColorGrade a, ColorGrade b) =>
      (a.exposure - b.exposure).abs() < 0.01 &&
      (a.contrast - b.contrast).abs() < 0.01 &&
      (a.saturation - b.saturation).abs() < 0.01 &&
      (a.temperature - b.temperature).abs() < 0.01;
}
