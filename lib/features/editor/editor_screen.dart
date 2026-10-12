import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/poster.dart';
import '../ai/ai_clients.dart';
import '../analysis/domain/edit_plan.dart';
import '../plan/plan_diff.dart';
import '../plan/plan_ops.dart';
import '../media/clip_importer.dart';
import '../render/beat_detector.dart';
import '../render/export_sheet.dart';
import '../projects/project.dart';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.projectId});
  final String projectId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const _minPps = 16.0;
  static const _maxPps = 240.0;
  double _pps = 64.0;

  // Pinch-to-zoom on the timeline via raw pointers (does not compete with
  // the horizontal scroll in the gesture arena).
  final _pointers = <int, Offset>{};
  double? _pinchStartDistance;
  double _pinchStartPps = 64.0;

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      final v = _pointers.values.toList();
      _pinchStartDistance = (v[0] - v[1]).distance;
      _pinchStartPps = _pps;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final start = _pinchStartDistance;
    if (_pointers.length == 2 && start != null && start > 0) {
      final v = _pointers.values.toList();
      final next = (_pinchStartPps * (v[0] - v[1]).distance / start)
          .clamp(_minPps, _maxPps)
          .toDouble();
      if ((next - _pps).abs() > 0.5) setState(() => _pps = next);
    }
  }

  void _onPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchStartDistance = null;
  }

  final _undo = <Map<String, dynamic>>[];
  final _redo = <Map<String, dynamic>>[];
  double _t = 0;
  bool _playing = false;
  Timer? _timer;
  String? _selected;
  final _vc = <String, VideoPlayerController>{};
  String? _playingShotId;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _vc.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Keeps the real clip in sync with the playhead (cuts only, no render).
  void _syncVideo(ProjectClip? clip, Shot shot) {
    for (final e in _vc.entries) {
      if (e.key != clip?.id && e.value.value.isPlaying) e.value.pause();
    }
    if (clip == null || shot.sourceIn == null) return;
    var ctl = _vc[clip.id];
    if (ctl == null) {
      if (!File(clip.path).existsSync()) return;
      ctl = VideoPlayerController.file(File(clip.path));
      _vc[clip.id] = ctl;
      ctl
          .initialize()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((Object _) {});
      return;
    }
    if (!ctl.value.isInitialized) return;
    if (shot.freeze) {
      // A freeze frame holds one picture: never play the clip here.
      if (ctl.value.isPlaying) ctl.pause();
      ctl.seekTo(Duration(milliseconds: ((shot.sourceIn ?? 0) * 1000).round()));
      return;
    }
    final maxMs = ctl.value.duration.inMilliseconds;
    final posMs = (((shot.sourceIn! + (_t - shot.startSec)) * 1000).round())
        .clamp(0, maxMs);
    final desired = Duration(milliseconds: posMs);
    if (_playing) {
      if (_playingShotId != shot.id) {
        _playingShotId = shot.id;
        ctl.seekTo(desired).then((_) => ctl!.play());
      } else if (!ctl.value.isPlaying && posMs < maxMs - 50) {
        ctl.play();
      }
    } else {
      _playingShotId = null;
      if (ctl.value.isPlaying) ctl.pause();
      ctl.seekTo(desired);
    }
  }

  void _stop() {
    _timer?.cancel();
    _playing = false;
  }

  void _togglePlay(double duration) {
    if (_playing) {
      setState(_stop);
      return;
    }
    if (_t >= duration - 0.05) _t = 0;
    setState(() => _playing = true);
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final next = _t + 0.04;
      setState(() {
        if (next >= duration) {
          _t = duration;
          _stop();
        } else {
          _t = next;
        }
      });
    });
  }

  Future<void> _apply(
    Map<String, dynamic> current,
    Map<String, dynamic> next,
  ) async {
    _undo.add(current);
    _redo.clear();
    await AppScope.of(context).updatePlan(widget.projectId, next);
  }

  Future<void> _undoStep(Map<String, dynamic> current) async {
    if (_undo.isEmpty) return;
    _redo.add(current);
    await AppScope.of(context).updatePlan(widget.projectId, _undo.removeLast());
  }

  Future<void> _redoStep(Map<String, dynamic> current) async {
    if (_redo.isEmpty) return;
    _undo.add(current);
    await AppScope.of(context).updatePlan(widget.projectId, _redo.removeLast());
  }

  /// Imports videos or photos into this project and appends them to the
  /// end of the timeline (one undoable change).
  Future<void> _addMedia(Map<String, dynamic> json) async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.video),
              title: const Text('Video'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Rasm'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final app = AppScope.of(context);
    final project = app.byId(widget.projectId);
    if (project == null) return;
    final importer = ClipImporter(startIndex: _maxClipIndex(project));
    final added = kind == 'video'
        ? await importer.pick(limit: 10)
        : await importer.pickImages(limit: 10);
    if (added.isEmpty || !mounted) return;
    for (final c in added) {
      await importer.measure(c);
    }
    final items = [
      for (final c in added)
        (
          clipId: c.id,
          seconds: c.isImage
              ? 3.0
              : (c.durationSec ?? 3.0).clamp(0.5, 6.0).toDouble(),
          still: c.isImage,
        ),
    ];
    await app.addClips(project.id, [
      for (final c in added)
        ProjectClip(
          id: c.id,
          path: c.path,
          name: c.name,
          durationSec: c.durationSec,
          sizeBytes: c.sizeBytes,
        ),
    ], PlanOps.appendShots(json, items));
    _undo.add(json);
    _redo.clear();
    if (mounted) setState(() {});
  }

  int _maxClipIndex(Project project) {
    var m = 0;
    for (final c in project.clips) {
      final n = int.tryParse(c.id.replaceFirst('clip_', '')) ?? 0;
      if (n > m) m = n;
    }
    return m;
  }

  Future<String?> _askText({String initial = '', required String title}) async {
    final ctl = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctl, autofocus: true, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    ctl.dispose();
    return v;
  }

  /// Adds a 2 s caption at the playhead.
  Future<void> _addCaption(Map<String, dynamic> json) async {
    final text = await _askText(title: 'Matn qo‘shish');
    if (text == null || text.isEmpty || !mounted) return;
    await _apply(
      json,
      PlanOps.addCaption(json, startSec: _t, endSec: _t + 2, text: text),
    );
  }

  Future<void> _editCaption(
    Map<String, dynamic> json,
    int index,
    String current,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.pencil),
              title: const Text('Tahrirlash'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: AppColors.danger),
              title: const Text('O‘chirish'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'delete') {
      await _apply(json, PlanOps.removeCaption(json, index));
    } else if (action == 'edit') {
      final text = await _askText(initial: current, title: 'Matn');
      if (text != null && text.isNotEmpty && mounted) {
        await _apply(json, PlanOps.updateCaption(json, index, text));
      }
    }
  }

  void _showEffects(String shotId) => showModalBottomSheet<void>(
    context: context,
    builder: (_) => _EffectsSheet(
      projectId: widget.projectId,
      shotId: shotId,
      onChanged: (next) {
        final current = AppScope.of(context).byId(widget.projectId)?.planJson;
        if (current != null) _apply(current, next);
      },
    ),
  );

  void _showMusic(Map<String, dynamic> json) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MusicSheet(
      projectId: widget.projectId,
      onChanged: (next) {
        final current = AppScope.of(context).byId(widget.projectId)?.planJson;
        if (current != null) _apply(current, next);
      },
    ),
  );

  Future<void> _beatSync(Map<String, dynamic> json, EditPlan plan) async {
    final beats = plan.music?.beats ?? const <double>[];
    if (beats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avval aniq ritmli musiqa qo‘shing.')),
      );
      return;
    }
    await _apply(json, PlanOps.snapToBeats(json, beats));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kesimlar musiqa zarbalariga moslandi.')),
      );
    }
  }

  void _showSlots(EditPlan plan) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text('Kerakli materiallar', style: AppText.title(ctx)),
          const SizedBox(height: 16),
          for (final m in plan.mediaSlots)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: IconBadge(switch (m.kind) {
                MediaKind.video => LucideIcons.video,
                MediaKind.image => LucideIcons.image,
                MediaKind.logo => LucideIcons.badgeCheck,
                MediaKind.text => LucideIcons.type,
                MediaKind.audio => LucideIcons.music,
              }),
              title: Text(m.description),
              subtitle: m.requiredDurationSec == null
                  ? null
                  : Text(seconds(m.requiredDurationSec!)),
            ),
        ],
      ),
    ),
  );

  void _showClaude(Map<String, dynamic> current) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ClaudeSheet(
      projectId: widget.projectId,
      onApplied: () {
        _undo.add(current);
        _redo.clear();
        if (mounted) setState(() {});
      },
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: buildTheme(Brightness.dark),
    child: Builder(builder: _buildEditor),
  );

  Widget _buildEditor(BuildContext context) {
    final app = AppScope.of(context);
    final project = app.byId(widget.projectId);
    final p = context.palette;
    if (project == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: LucideIcons.film,
          title: 'Loyiha topilmadi',
          message: 'U o‘chirilgan bo‘lishi mumkin.',
        ),
      );
    }
    final EditPlan plan;
    try {
      plan = EditPlan.fromJson(project.planJson);
    } on EditPlanFormatException catch (e) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: LucideIcons.triangleAlert,
          title: 'Reja buzilgan',
          message: e.message,
        ),
      );
    }
    final json = project.planJson;
    if (_t > plan.durationSec) _t = plan.durationSec;

    final idx = () {
      for (final (i, s) in plan.shots.indexed) {
        if (_t >= s.startSec && _t < s.endSec) return i;
      }
      return plan.shots.length - 1;
    }();
    final shot = plan.shots[idx];
    final clip = project.clip(shot.sourceClipId);
    final imageClip =
        clip != null && clip.isImage && File(clip.path).existsSync()
        ? clip
        : null;
    final vctl = clip == null || clip.isImage ? null : _vc[clip.id];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncVideo(clip != null && clip.isImage ? null : clip, shot);
    });
    final selIndex = plan.shots.indexWhere((s) => s.id == _selected);
    final selected = selIndex < 0 ? null : plan.shots[selIndex];
    final caption = plan.captions
        .where((c) => _t >= c.startSec && _t < c.endSec)
        .map((c) => c.text)
        .firstOrNull;
    final ratio = switch (plan.aspectRatio) {
      '16:9' => 16 / 9,
      '1:1' => 1.0,
      _ => 9 / 16,
    };
    final mono = TextStyle(
      color: p.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      LucideIcons.chevronDown,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        showExportSheet(context, project: project, plan: plan),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Eksport',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Preview
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 40,
                  ),
                  child: AspectRatio(
                    aspectRatio: ratio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              shotColor(idx).withValues(alpha: 0.75),
                              const Color(0xFF050507),
                            ],
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (imageClip != null)
                              Image.file(
                                File(imageClip.path),
                                fit: BoxFit.cover,
                              ),
                            if (vctl != null && vctl.value.isInitialized)
                              FittedBox(
                                fit: BoxFit.cover,
                                clipBehavior: Clip.hardEdge,
                                child: SizedBox(
                                  width: vctl.value.size.width,
                                  height: vctl.value.size.height,
                                  child: VideoPlayer(vctl),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: _PreviewOverlay(
                                index: idx,
                                description: shot.description,
                                caption: caption,
                                hasVideo:
                                    imageClip != null ||
                                    (vctl != null && vctl.value.isInitialized),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Transport
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Bekor qilish',
                    onPressed: _undo.isEmpty ? null : () => _undoStep(json),
                    icon: Icon(
                      LucideIcons.undo2,
                      color: _undo.isEmpty ? p.separator : Colors.white,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Qaytarish',
                    onPressed: _redo.isEmpty ? null : () => _redoStep(json),
                    icon: Icon(
                      LucideIcons.redo2,
                      color: _redo.isEmpty ? p.separator : Colors.white,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${timecode(_t)} / ${timecode(plan.durationSec)}',
                          style: mono.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _playing ? 'Pauza' : 'Ijro',
                    iconSize: 30,
                    onPressed: () => _togglePlay(plan.durationSec),
                    icon: Icon(
                      _playing
                          ? LucideIcons.circlePause
                          : LucideIcons.circlePlay,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ],
              ),
            ),
            // Timeline (pinch with two fingers to zoom)
            Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              child: _Timeline(
                plan: plan,
                t: _t,
                pps: _pps,
                selectedId: _selected,
                onSeek: (v) => setState(() {
                  _stop();
                  _t = v;
                }),
                onSelect: (s) => setState(() {
                  _stop();
                  _selected = s.id;
                  _t = s.startSec;
                }),
                onCaptionTap: (i, text) => _editCaption(json, i, text),
              ),
            ),
            // Inspector
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: selected == null
                  ? Padding(
                      key: const ValueKey('hint'),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'Tahrirlash uchun kadrni tanlang',
                        style: AppText.caption(context),
                      ),
                    )
                  : Padding(
                      key: ValueKey(selected.id),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 36,
                              decoration: BoxDecoration(
                                color: shotColor(selIndex),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kadr ${selIndex + 1}',
                                    style: TextStyle(
                                      color: p.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    [
                                      if (selected.camera != null)
                                        selected.camera!,
                                      if (selected.transitionIn != null)
                                        selected.transitionIn!,
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.caption(context)
                                        .copyWith(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            _Stepper(
                              value: selected.duration,
                              onMinus: () => _apply(
                                json,
                                PlanOps.resizeShot(
                                  json,
                                  selected.id,
                                  selected.duration - 0.5,
                                ),
                              ),
                              onPlus: () => _apply(
                                json,
                                PlanOps.resizeShot(
                                  json,
                                  selected.id,
                                  selected.duration + 0.5,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: plan.shots.length <= 1
                                  ? null
                                  : () {
                                      final next = PlanOps.removeShot(
                                        json,
                                        selected.id,
                                      );
                                      if (next != null) {
                                        setState(() => _selected = null);
                                        _apply(json, next);
                                      }
                                    },
                              icon: const Icon(
                                LucideIcons.trash2,
                                color: AppColors.danger,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            if (selected != null)
              _ShotTools(
                canSplit:
                    _t > selected.startSec + PlanOps.minShot &&
                    _t < selected.endSec - PlanOps.minShot,
                canMoveLeft: selIndex > 0,
                canMoveRight: selIndex < plan.shots.length - 1,
                canTrim:
                    selected.sourceIn != null &&
                    selected.duration > PlanOps.minShot + 0.25,
                onSplit: () {
                  final next = PlanOps.splitAt(json, _t);
                  if (next != null) _apply(json, next);
                },
                onDuplicate: () =>
                    _apply(json, PlanOps.duplicate(json, selected.id)),
                onLeft: () => _apply(json, PlanOps.move(json, selected.id, -1)),
                onRight: () => _apply(json, PlanOps.move(json, selected.id, 1)),
                onTrimHead: () =>
                    _apply(json, PlanOps.trimStart(json, selected.id, 0.25)),
                onEffects: () => _showEffects(selected.id),
                canFreeze:
                    selected.sourceClipId != null &&
                    !selected.freeze &&
                    project.clip(selected.sourceClipId)?.isImage != true,
                onFreeze: () {
                  final next = PlanOps.insertFreezeFrame(json, _t);
                  if (next != null) _apply(json, next);
                },
              ),
            // Tools (icons; long-press shows the name)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Video yoki rasm qo‘shish',
                    onPressed: () => _addMedia(json),
                    icon: const Icon(LucideIcons.plus, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Matn qo‘shish',
                    onPressed: () => _addCaption(json),
                    icon: const Icon(LucideIcons.type, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: 'Musiqa',
                    onPressed: () => _showMusic(json),
                    icon: Icon(
                      LucideIcons.music,
                      color: plan.music == null ? Colors.white : p.accent,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ritmga moslash',
                    onPressed: plan.music == null
                        ? null
                        : () => _beatSync(json, plan),
                    icon: const Icon(LucideIcons.audioLines),
                    color: Colors.white,
                  ),
                  IconButton(
                    tooltip: 'Materiallar',
                    onPressed: () => _showSlots(plan),
                    icon: const Icon(LucideIcons.layers, color: Colors.white),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => _showClaude(json),
                    icon: const Icon(LucideIcons.sparkles, size: 18),
                    label: const Text('AI'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });
  final double value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget b(IconData i, VoidCallback f) => GestureDetector(
      onTap: f,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          shape: BoxShape.circle,
        ),
        child: Icon(i, size: 16, color: p.textPrimary),
      ),
    );
    return Row(
      children: [
        b(LucideIcons.minus, onMinus),
        SizedBox(
          width: 52,
          child: Text(
            seconds(value),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        b(LucideIcons.plus, onPlus),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    this.onCaptionTap,
    required this.plan,
    required this.t,
    required this.pps,
    required this.selectedId,
    required this.onSeek,
    required this.onSelect,
  });
  final EditPlan plan;
  final double t;
  final double pps;
  final String? selectedId;
  final ValueChanged<double> onSeek;
  final ValueChanged<Shot> onSelect;
  final void Function(int index, String text)? onCaptionTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final width = plan.durationSec * pps;

    Widget seg(
      double s,
      double e,
      Widget child,
      Color color, {
      bool sel = false,
      VoidCallback? onTap,
    }) => Positioned(
      left: s * pps,
      width: math.max((e - s) * pps - 3, 6),
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(9),
            border: sel ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: child,
        ),
      ),
    );

    Widget lane(double h, List<Widget> kids) => SizedBox(
      height: h,
      width: width,
      child: Stack(children: kids),
    );

    return SizedBox(
      height: 196,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: width,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (d) =>
                onSeek((d.localPosition.dx / pps).clamp(0, plan.durationSec)),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    lane(22, [
                      for (var s = 0; s <= plan.durationSec.floor(); s++)
                        Positioned(
                          left: s * pps,
                          top: 4,
                          child: Text(
                            '$s',
                            style: TextStyle(
                              color: p.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ]),
                    lane(60, [
                      for (final (i, s) in plan.shots.indexed)
                        seg(
                          s.startSec,
                          s.endSec,
                          Row(
                            children: [
                              Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (s.speed != 1.0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    '${s.speed.toStringAsFixed(s.speed % 1 == 0 ? 0 : 1)}×',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              if (s.transition != ShotTransition.cut)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Icon(
                                    LucideIcons.blend,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              if (s.duration * pps > 70)
                                Flexible(
                                  child: Text(
                                    seconds(s.duration),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          shotColor(i).withValues(
                            alpha: selectedId == null || selectedId == s.id
                                ? 0.95
                                : 0.45,
                          ),
                          sel: selectedId == s.id,
                          onTap: () => onSelect(s),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    lane(30, [
                      for (final (i, c) in plan.captions.indexed)
                        seg(
                          c.startSec,
                          c.endSec,
                          Text(
                            c.text,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Color(0xFF3A3A3C),
                          onTap: onCaptionTap == null
                              ? null
                              : () => onCaptionTap!(i, c.text),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    lane(30, [
                      for (final a in plan.audioTracks)
                        seg(
                          a.startSec,
                          a.endSec,
                          Text(
                            '♪ ${a.kind}',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          AppColors.success.withValues(alpha: 0.7),
                        ),
                    ]),
                    if (plan.music != null) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 30,
                        width: width,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                ),
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  color: AppColors.blue.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  '♪ ${plan.music!.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _WaveformPainter(
                                  peaks: plan.music!.peaks,
                                  offsetSec: plan.music!.offsetSec,
                                  pps: pps,
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                            for (final b in plan.music!.beats)
                              if (b - plan.music!.offsetSec > 0 &&
                                  b - plan.music!.offsetSec < plan.durationSec)
                                Positioned(
                                  left: (b - plan.music!.offsetSec) * pps,
                                  top: 20,
                                  bottom: 2,
                                  child: Container(
                                    width: 1.5,
                                    color: Colors.white54,
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Positioned(
                  left: t * pps - 1,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(width: 2, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClaudeSheet extends StatefulWidget {
  const _ClaudeSheet({required this.projectId, required this.onApplied});
  final String projectId;
  final VoidCallback onApplied;

  @override
  State<_ClaudeSheet> createState() => _ClaudeSheetState();
}

class _ClaudeSheetState extends State<_ClaudeSheet> {
  final _c = TextEditingController();
  bool _busy = false;
  String? _error;

  /// AI proposal waiting for Apply/Cancel, with what it would change.
  Map<String, dynamic>? _proposal;
  String? _baseSignature;
  List<String> _changes = const [];

  static const _ideas = [
    'Hookni kuchliroq qil',
    'Videoni 20% qisqartir',
    'Subtitrlarni qisqa va zarbdor qil',
    'Oxiriga aniq chaqiriq qo‘sh',
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _run(String text) async {
    final app = AppScope.of(context);
    final gen = app.generator();
    final project = app.byId(widget.projectId);
    if (gen == null || project == null) {
      setState(() => _error = 'Avval AI ulang (menyu → AI ulanishlari).');
      return;
    }
    if (text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await gen.edit(
        current: project.planJson,
        instruction: text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _proposal = updated;
        _baseSignature = planSignature(project.planJson);
        _changes = describePlanDiff(project.planJson, updated);
      });
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final app = AppScope.of(context);
    final project = app.byId(widget.projectId);
    final plan = _proposal;
    if (project == null || plan == null) return;
    if (planSignature(project.planJson) != _baseSignature) {
      setState(() {
        _error = 'Loyiha bu taklifdan keyin o‘zgargan. Qayta so‘rang.';
        _proposal = null;
      });
      return;
    }
    widget.onApplied();
    await app.updatePlan(project.id, plan);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.of(context).viewInsets.bottom,
    ),
    child: _proposal != null ? _review(context) : _ask(context),
  );

  Widget _review(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('AI montajchi taklifi', style: AppText.title(context)),
      const SizedBox(height: 10),
      if (_changes.isEmpty)
        Text('O‘zgarish topilmadi.', style: AppText.body(context))
      else
        for (final c in _changes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.dot, size: 18),
                Expanded(
                  child: Text(
                    c,
                    style: AppText.body(context).copyWith(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _changes.isEmpty ? null : _apply,
              icon: const Icon(LucideIcons.check, size: 18),
              label: const Text('Qo‘llash'),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => setState(() => _proposal = null),
            child: const Text('Bekor qilish'),
          ),
        ],
      ),
    ],
  );

  Widget _ask(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(LucideIcons.sparkles, size: 18, color: context.palette.accent),
          const SizedBox(width: 8),
          Text('AI montajchi', style: AppText.title(context)),
        ],
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final i in _ideas)
            ActionChip(label: Text(i), onPressed: _busy ? null : () => _run(i)),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _c,
        enabled: !_busy,
        minLines: 1,
        maxLines: 3,
        textInputAction: TextInputAction.send,
        onSubmitted: _run,
        decoration: const InputDecoration(
          hintText: 'Videoda nimani o‘zgartiramiz?',
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: AppColors.danger)),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : () => _run(_c.text),
        child: _busy
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.palette.onAccent,
                ),
              )
            : const Text('Taklif olish'),
      ),
    ],
  );
}

class _PreviewOverlay extends StatelessWidget {
  const _PreviewOverlay({
    required this.index,
    required this.description,
    required this.caption,
    required this.hasVideo,
  });
  final int index;
  final String description;
  final String? caption;
  final bool hasVideo;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: hasVideo ? 0.55 : 0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(
            color: Colors.white,
            fontSize: hasVideo ? 15 : 44,
            fontWeight: FontWeight.w800,
            letterSpacing: hasVideo ? 0 : -1.5,
          ),
        ),
      ),
      if (!hasVideo) ...[
        const SizedBox(height: 4),
        Text(
          description,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
      const Spacer(),
      if (caption != null)
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              caption!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
    ],
  );
}

/// Tools for the selected shot: icon-only (tooltip = name for long press
/// and screen readers), disabled when the action is not possible.
class _ShotTools extends StatelessWidget {
  const _ShotTools({
    required this.canSplit,
    required this.canMoveLeft,
    required this.canMoveRight,
    required this.canTrim,
    required this.onSplit,
    required this.onDuplicate,
    required this.onLeft,
    required this.onRight,
    required this.onTrimHead,
    required this.onEffects,
    required this.canFreeze,
    required this.onFreeze,
  });

  final bool canFreeze;
  final VoidCallback onFreeze;

  final VoidCallback onEffects;
  final bool canSplit;
  final bool canMoveLeft;
  final bool canMoveRight;
  final bool canTrim;
  final VoidCallback onSplit;
  final VoidCallback onDuplicate;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onTrimHead;

  @override
  Widget build(BuildContext context) {
    Widget tool(IconData icon, String name, bool enabled, VoidCallback onTap) =>
        IconButton(
          tooltip: name,
          onPressed: enabled ? onTap : null,
          icon: Icon(icon),
          color: Colors.white,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          tool(LucideIcons.scissors, 'Playhead’da kesish', canSplit, onSplit),
          tool(
            LucideIcons.chevronsRight,
            'Boshidan 0.25 s kesish',
            canTrim,
            onTrimHead,
          ),
          tool(LucideIcons.copyPlus, 'Nusxa', true, onDuplicate),
          tool(
            LucideIcons.snowflake,
            'Freeze frame (1 s)',
            canFreeze,
            onFreeze,
          ),
          tool(LucideIcons.arrowLeft, 'Chapga', canMoveLeft, onLeft),
          tool(LucideIcons.arrowRight, 'O‘ngga', canMoveRight, onRight),
          tool(
            LucideIcons.wandSparkles,
            'Effekt: o‘tish, tezlik, harakat',
            true,
            onEffects,
          ),
        ],
      ),
    );
  }
}

/// Background music: pick a song, detect its beats offline, set volume.
class _MusicSheet extends StatefulWidget {
  const _MusicSheet({required this.projectId, required this.onChanged});
  final String projectId;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<_MusicSheet> createState() => _MusicSheetState();
}

class _MusicSheetState extends State<_MusicSheet> {
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

/// Per-shot effects: transition in, speed and camera motion.
class _EffectsSheet extends StatelessWidget {
  const _EffectsSheet({
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

/// Music waveform from the cached loudness envelope (computed once when the
/// song is added, never per frame).
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.peaks,
    required this.offsetSec,
    required this.pps,
    required this.color,
  });
  final List<double> peaks;
  final double offsetSec;
  final double pps;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = (0.1 * pps * 0.6).clamp(1.0, 6.0);
    final mid = size.height / 2;
    for (var i = 0; i < peaks.length; i++) {
      final x = (i * 0.1 - offsetSec) * pps;
      if (x < 0) continue;
      if (x > size.width) break;
      final h = peaks[i] * (size.height - 6) / 2;
      canvas.drawLine(Offset(x, mid - h), Offset(x, mid + h), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.peaks != peaks || old.pps != pps || old.offsetSec != offsetSec;
}
