import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';
import '../analysis/domain/edit_plan.dart';
import '../../app/app_controller.dart';
import '../projects/project.dart';
import 'export_presets.dart';
import 'render_service.dart';

Future<void> showExportSheet(
  BuildContext context, {
  required Project project,
  required EditPlan plan,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  builder: (_) => _ExportSheet(project: project, plan: plan),
);

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.project, required this.plan});
  final Project project;
  final EditPlan plan;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  final _service = RenderService();
  String _resolution = '1080p';
  double _progress = 0;
  bool _running = false;
  String? _error;
  String? _output;
  bool _saved = false;
  VideoPlayerController? _player;

  @override
  void initState() {
    super.initState();
    final r = widget.plan.export.resolution;
    _resolution = const ['360p', '720p', '1080p', '4K'].contains(r)
        ? r
        : '1080p';
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  int get _missing => widget.plan.shots
      .where((s) => widget.project.clip(s.sourceClipId) == null)
      .length;

  Future<void> _start() async {
    setState(() {
      _running = true;
      _error = null;
      _progress = 0;
    });
    try {
      final out = await _service.render(
        plan: widget.plan,
        clips: widget.project.clips,
        resolution: _resolution,
        name: widget.project.name,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) {
        await AppScope.of(context).setLastRender(
          widget.project.id,
          RenderInfo(
            path: out,
            sizeBytes: File(out).lengthSync(),
            resolution: _resolution,
            aspectRatio: widget.plan.aspectRatio,
            durationSec: widget.plan.durationSec,
            fps: 30,
            createdAt: DateTime.now(),
            planSignature: planSignature(widget.project.planJson),
          ),
        );
      }
      final player = VideoPlayerController.file(File(out));
      await player.initialize();
      await player.setLooping(true);
      await player.play();
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _output = out;
        _player = player;
      });
    } on RenderException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Kutilmagan xato: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _save() async {
    final path = _output;
    if (path == null) return;
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putVideo(path, album: 'HOOKKADR');
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Galereyaga saqlab bo‘lmadi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final player = _player;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Eksport', style: AppText.title(context)),
                  ),
                  if (!_running)
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Video shu qurilmaning o‘zida (internet kerak emas) MP4 ga '
                'aylantiriladi.',
                style: AppText.caption(context),
              ),
              if (_missing > 0) ...[
                const SizedBox(height: 10),
                Text(
                  '$_missing ta kadr uchun material yo‘q — ular matnli karta '
                  'bo‘lib chiqadi. Klip qo‘shsangiz, haqiqiy kadr bo‘ladi.',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (player != null && player.value.isInitialized) ...[
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: AspectRatio(
                      aspectRatio: player.value.aspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: VideoPlayer(player),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${widget.plan.aspectRatio} · $_resolution · ${widget.plan.durationSec.toStringAsFixed(0)} s · 30 FPS · '
                  'MP4 H.264 · ${FileSizeEstimator.formatBytes(File(_output!).lengthSync())}',
                  textAlign: TextAlign.center,
                  style: AppText.caption(context),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saved ? null : _save,
                  icon: Icon(_saved ? LucideIcons.check : LucideIcons.download),
                  label: Text(
                    _saved ? 'Galereyaga saqlandi' : 'Galereyaga saqlash',
                  ),
                ),
              ] else ...[
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in const ['360p', '720p', '1080p', '4K'])
                      ChoiceChip(
                        label: Text(r),
                        selected: _resolution == r,
                        onSelected: _running
                            ? null
                            : (_) => setState(() => _resolution = r),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Taxminiy hajm: ${FileSizeEstimator.estimateLabel(_resolution, widget.plan.durationSec)}'
                  ' · ${ExportPreset.of(_resolution).uiName} · 30 FPS · MP4 H.264',
                  style: AppText.caption(context),
                ),
                Text(
                  'Haqiqiy hajm kodlashdan keyin farq qilishi mumkin.',
                  style: AppText.caption(context).copyWith(fontSize: 11.5),
                ),
                if (_resolution == '4K')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '4K eksport: manba 4K bo‘lmasa, bu upscale (sifat manbadan oshmaydi).',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                if (_running) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress == 0 ? null : _progress,
                      minHeight: 8,
                      backgroundColor: p.surfaceRaised,
                      color: p.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Render qilinmoqda… ${(_progress * 100).round()}%',
                    style: AppText.caption(context),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _service.cancel(),
                    child: const Text('Bekor qilish'),
                  ),
                ] else
                  FilledButton(
                    onPressed: _start,
                    child: const Text('Render boshlash'),
                  ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
