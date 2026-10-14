import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../plan/plan_ops.dart';
import '../../render/beat_detector.dart';

/// Background music: pick a song, detect its beats offline, set volume.
class MusicSheet extends StatefulWidget {
  const MusicSheet({
    super.key,
    required this.projectId,
    required this.onChanged,
  });
  final String projectId;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<MusicSheet> createState() => _MusicSheetState();
}

class _MusicSheetState extends State<MusicSheet> {
  bool _busy = false;
  String? _error;
  double? _volume;

  Map<String, dynamic>? get _plan =>
      AppScope.of(context).byId(widget.projectId)?.planJson;

  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    final picked = files.isEmpty ? null : files.first;
    final src = picked?.path;
    if (src == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/music')..createSync(recursive: true);
      final dest =
          '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${picked!.name}';
      await File(src).copy(dest);
      final beats = await BeatDetector.analyzeFile(dest);
      final plan = _plan;
      if (plan == null || !mounted) return;
      widget.onChanged(
        PlanOps.setMusic(plan, {
          'path': dest,
          'name': picked.name,
          'volume': 0.35,
          'offsetSec': 0,
          'fadeOutSec': 1.5,
          'beats': beats.beats,
          'peaks': beats.envelope,
          if (beats.bpm > 0) 'bpm': beats.bpm,
        }),
      );
      if (beats.beats.isEmpty) {
        setState(
          () => _error = 'Aniq ritm topilmadi — musiqa qo‘shildi, lekin ritmga moslash ishlamaydi.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Musiqani qo‘shib bo‘lmadi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final music = plan?['music'] as Map<String, dynamic>?;
    final beats = (music?['beats'] as List?)?.length ?? 0;
    final bpm = music?['bpm'];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Musiqa', style: AppText.title(context)),
            const SizedBox(height: 12),
            if (music != null) ...[
              Row(
                children: [
                  const Icon(LucideIcons.music, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      music['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(context),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Olib tashlash',
                    onPressed: plan == null
                        ? null
                        : () => widget.onChanged(PlanOps.setMusic(plan, null)),
                    icon: const Icon(
                      LucideIcons.trash2,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
              Text(
                beats > 0
                    ? '${bpm ?? '?'} BPM · $beats zarba aniqlandi'
                    : 'Ritm aniqlanmadi',
                style: AppText.caption(context),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(LucideIcons.volume2, size: 18),
                  Expanded(
                    child: Slider(
                      value: _volume ?? (music['volume'] as num).toDouble(),
                      onChanged: (v) => setState(() => _volume = v),
                      onChangeEnd: (v) {
                        if (plan != null) {
                          widget.onChanged(PlanOps.setMusicVolume(plan, v));
                        }
                      },
                    ),
                  ),
                  Text(
                    '${(((_volume ?? (music['volume'] as num).toDouble())) * 100).round()}%',
                  ),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Asta kirish (1 s)'),
                value: ((music['fadeInSec'] as num?) ?? 0) > 0,
                onChanged: plan == null
                    ? null
                    : (on) => widget.onChanged(
                        PlanOps.setMusicFadeIn(plan, on ? 1.0 : 0),
                      ),
              ),
              Text(
                'Gap bo‘lgan joylarda musiqa avtomatik pasayadi, oxirida so‘nadi.',
                style: AppText.caption(context).copyWith(fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _busy ? null : _pick,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.music, size: 18),
              label: Text(
                _busy
                    ? 'Ritm aniqlanmoqda…'
                    : (music == null ? 'Musiqa tanlash' : 'Almashtirish'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.warning, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
