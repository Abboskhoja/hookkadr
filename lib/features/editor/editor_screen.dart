import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/poster.dart';
import '../analysis/domain/edit_plan.dart';
import '../media/clip_importer.dart';
import '../plan/plan_ops.dart';
import '../projects/project.dart';
import '../render/export_sheet.dart';
import '../render/grade_preview.dart';

import 'package:video_player/video_player.dart';

import 'widgets/duration_stepper.dart';
import 'widgets/editor_timeline.dart';
import 'widgets/effects_sheet.dart';
import 'widgets/kadr_ai_sheet.dart';
import 'widgets/look_sheet.dart';
import 'widgets/music_sheet.dart';
import 'widgets/preview_overlay.dart';
import 'widgets/shot_tools_bar.dart';
import 'widgets/tool_button.dart';

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

  /// Preview colour grade (same look the export applies).
  Widget _graded(ColorGrade? g, Widget child) => g == null || g.isNeutral
      ? child
      : ColorFiltered(
          colorFilter: ColorFilter.matrix(gradeColorMatrix(g)),
          child: child,
        );

  /// Logo end card in the preview: fades in over the last seconds.
  List<Widget> _logoPreview(EditPlan plan, Project project) {
    final logo = plan.logo;
    final clip = project.clip(logo?.clipId);
    if (logo == null || clip == null || !clip.isImage) return const [];
    final start = plan.durationSec - logo.durationSec;
    if (_t < start) return const [];
    final a = logo.fadeSec <= 0
        ? 1.0
        : ((_t - start) / logo.fadeSec).clamp(0.0, 1.0);
    return [
      Center(
        child: Opacity(
          opacity: a,
          child: FractionallySizedBox(
            widthFactor: logo.scale,
            child: Image.file(File(clip.path), fit: BoxFit.contain),
          ),
        ),
      ),
    ];
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
    builder: (_) => EffectsSheet(
      projectId: widget.projectId,
      shotId: shotId,
      onChanged: (next) {
        final current = AppScope.of(context).byId(widget.projectId)?.planJson;
        if (current != null) _apply(current, next);
      },
    ),
  );

  void _showLook() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => LookSheet(
      projectId: widget.projectId,
      onChanged: (next) {
        final current = AppScope.of(context).byId(widget.projectId)?.planJson;
        if (current != null) _apply(current, next);
      },
      onPickLogo: _pickLogo,
    ),
  );

  /// Imports one image and makes it the logo end card (one undoable change).
  Future<void> _pickLogo() async {
    final app = AppScope.of(context);
    final project = app.byId(widget.projectId);
    if (project == null) return;
    final importer = ClipImporter(startIndex: _maxClipIndex(project));
    final added = await importer.pickImages(limit: 1);
    if (added.isEmpty || !mounted) return;
    final c = added.first;
    await importer.measure(c);
    final before = project.planJson;
    await app.addClips(project.id, [
      ProjectClip(
        id: c.id,
        path: c.path,
        name: c.name,
        durationSec: c.durationSec,
        sizeBytes: c.sizeBytes,
      ),
    ], PlanOps.setLogo(before, c.id));
    _undo.add(before);
    _redo.clear();
    if (mounted) setState(() {});
  }

  void _showMusic(Map<String, dynamic> json) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => MusicSheet(
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
    builder: (_) => KadrAiSheet(
      projectId: widget.projectId,
      playheadSec: _t,
      selectedShotId: _selected,
      // [before] is the plan right before this change (the sheet can apply
      // several commands in a row, each one undoable).
      onApplied: (before) {
        _undo.add(before);
        _redo.clear();
        if (mounted) setState(() {});
      },
      onUndo: () async {
        final now = AppScope.of(context).byId(widget.projectId)?.planJson;
        if (now != null) await _undoStep(now);
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
        body: const SafeArea(
          child: Column(
            children: [
              PageHeader('Loyiha'),
              Expanded(
                child: EmptyState(
                  icon: LucideIcons.film,
                  title: 'Loyiha topilmadi',
                  message: 'U o‘chirilgan bo‘lishi mumkin.',
                ),
              ),
            ],
          ),
        ),
      );
    }
    final EditPlan plan;
    try {
      plan = EditPlan.fromJson(project.planJson);
    } on EditPlanFormatException catch (e) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const PageHeader('Loyiha'),
              Expanded(
                child: EmptyState(
                  icon: LucideIcons.triangleAlert,
                  title: 'Reja buzilgan',
                  message: e.message,
                ),
              ),
            ],
          ),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.download,
                            size: 16,
                            color: p.onAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Saqlash',
                            style: TextStyle(
                              color: p.onAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
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
                              _graded(
                                plan.grade,
                                Image.file(
                                  File(imageClip.path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            if (vctl != null && vctl.value.isInitialized)
                              _graded(
                                plan.grade,
                                FittedBox(
                                  fit: BoxFit.cover,
                                  clipBehavior: Clip.hardEdge,
                                  child: SizedBox(
                                    width: vctl.value.size.width,
                                    height: vctl.value.size.height,
                                    child: VideoPlayer(vctl),
                                  ),
                                ),
                              ),
                            ..._logoPreview(plan, project),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: PreviewOverlay(
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
              child: EditorTimeline(
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
                                  if (app.proMode)
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
                            DurationStepper(
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
              ShotToolsBar(
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
            // Kadr AI: say what to change, in your own words.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Material(
                color: p.surface,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _showClaude(json),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: p.separator, width: 0.8),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.sparkles, size: 18, color: p.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Kadr AI’ga ayting: “15 soniyaga qisqartir”',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Tools, each with its name under the icon.
            SizedBox(
              height: 74,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  ToolButton(
                    icon: LucideIcons.plus,
                    label: 'Qo‘shish',
                    onTap: () => _addMedia(json),
                  ),
                  ToolButton(
                    icon: LucideIcons.type,
                    label: 'Matn',
                    onTap: () => _addCaption(json),
                  ),
                  ToolButton(
                    icon: LucideIcons.music,
                    label: 'Musiqa',
                    active: plan.music != null,
                    onTap: () => _showMusic(json),
                  ),
                  ToolButton(
                    icon: LucideIcons.palette,
                    label: 'Rang',
                    active: plan.grade != null || plan.logo != null,
                    onTap: _showLook,
                  ),
                  ToolButton(
                    icon: LucideIcons.audioLines,
                    label: 'Ritm',
                    onTap: plan.music == null
                        ? null
                        : () => _beatSync(json, plan),
                  ),
                  if (app.proMode)
                    ToolButton(
                      icon: LucideIcons.layers,
                      label: 'Materiallar',
                      onTap: () => _showSlots(plan),
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
