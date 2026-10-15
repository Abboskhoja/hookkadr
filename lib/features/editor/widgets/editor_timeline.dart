import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/poster.dart';
import '../../analysis/domain/edit_plan.dart';
import '../../plan/ripple_trim.dart';
import 'music_waveform_painter.dart';

/// The multi-lane scrubber: ruler, shots, captions, audio tracks and the
/// music waveform, with a draggable playhead. Pinch-to-zoom is handled by
/// the caller (it wraps this widget in a `Listener`) via [pps].
///
/// Shots support direct manipulation, CapCut-style:
/// - a grip handle at each shot's left/right edge is a live ripple trim
///   ([RippleTrim]): while the finger moves, the shot and everything after
///   it (shots, captions) re-lay out in whole frames, the right edge snaps
///   to the playhead and music beats with a light haptic, and the shot
///   can't run past its source footage. Raw pointer tracking, so it never
///   competes with the horizontal scroll gesture. Only this widget rebuilds
///   per move; the editor sees one [onTrimCommit] on release (one undo
///   step) and nothing at all if the gesture is cancelled;
/// - a long-press on a shot's body picks it up (elevated, follows the
///   finger) and dropping it over another shot reorders the timeline.
class EditorTimeline extends StatefulWidget {
  const EditorTimeline({
    super.key,
    this.onCaptionTap,
    this.planJson,
    this.sourceSeconds = const {},
    this.onTrimCommit,
    this.onReorder,
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

  /// The plan's own JSON (what the editor persists). Trims are computed
  /// from it, never from [plan] re-serialized, so no field is ever lost.
  /// Trimming is off without it.
  final Map<String, dynamic>? planJson;

  /// Source clip lengths by clip id; a trim never reaches past them.
  final Map<String, double> sourceSeconds;

  /// A trim was released: the rippled plan and the timeline time the
  /// preview should jump to (the trimmed edge).
  final void Function(Map<String, dynamic> plan, double edgeSec)? onTrimCommit;

  /// A shot was long-pressed, dragged and dropped at [targetIndex].
  final void Function(String shotId, int targetIndex)? onReorder;

  @override
  State<EditorTimeline> createState() => _EditorTimelineState();
}

class _EditorTimelineState extends State<EditorTimeline> {
  static const _handleWidth = 16.0;

  // Trim (left/right handle), tracked via raw pointer events so the
  // scrollable timeline never steals the gesture mid-drag.
  String? _trimShotId;
  bool _trimIsLeft = false;
  double _trimDeltaPx = 0;
  // The plan as it was when the drag began; every move is computed from it
  // (never from the last preview), so nothing accumulates and a cancel is
  // just dropping [_preview].
  Map<String, dynamic>? _trimStart;
  TrimResult? _trim;
  EditPlan? _preview;
  double? _lastSnap;
  // A finger on a trim handle must not also seek: the timeline's own
  // tap-to-seek would otherwise jump the playhead to the handle — moving the
  // very playhead the user placed to snap the edge to.
  bool _handleDown = false;

  // Reorder (long-press the shot body and drag).
  String? _dragShotId;
  double _dragDx = 0;

  bool get _gestureActive => _trimShotId != null || _dragShotId != null;

  @override
  void didUpdateWidget(EditorTimeline old) {
    super.didUpdateWidget(old);
    // The committed plan arrived: the preview has done its job. (Kept until
    // now so the timeline doesn't flash back to the old layout meanwhile.)
    if (_trimShotId == null && !identical(old.planJson, widget.planJson)) {
      _preview = null;
      _trim = null;
    }
  }

  void _startTrim(String shotId, bool isLeft) {
    final start = widget.planJson;
    if (start == null) return;
    setState(() {
      _trimShotId = shotId;
      _trimIsLeft = isLeft;
      _trimDeltaPx = 0;
      _trimStart = start;
      _trim = null;
      _preview = null;
      _lastSnap = null;
    });
  }

  void _updateTrim(String shotId, double deltaPx) {
    final start = _trimStart;
    if (_trimShotId != shotId || start == null) return;
    _trimDeltaPx += deltaPx;
    final plan = widget.plan;
    final shot = plan.shots.firstWhere((s) => s.id == shotId);
    final music = plan.music;
    final r = RippleTrim.apply(
      start,
      shotId: shotId,
      edge: _trimIsLeft ? TrimEdge.head : TrimEdge.tail,
      deltaSec: _trimDeltaPx / widget.pps,
      fps: plan.export.fps,
      sourceLimit: shot.sourceClipId == null
          ? null
          : widget.sourceSeconds[shot.sourceClipId],
      snapTargets: [
        widget.t,
        if (music != null)
          for (final b in music.beats)
            if (b - music.offsetSec > 0) b - music.offsetSec,
      ],
      // ~10 px either side, whatever the zoom.
      snapWindowSec: 10 / widget.pps,
    );
    final EditPlan preview;
    try {
      preview = EditPlan.fromJson(r.plan);
    } on EditPlanFormatException {
      return; // keep showing the last valid preview
    }
    if (r.snappedAt != null && r.snappedAt != _lastSnap) {
      HapticFeedback.selectionClick();
    }
    _lastSnap = r.snappedAt;
    setState(() {
      _trim = r;
      _preview = preview;
    });
  }

  void _commitTrim(String shotId) {
    if (_trimShotId != shotId) return;
    final r = _trim;
    final commit = r != null && r.changed;
    setState(() {
      _trimShotId = null;
      _trimDeltaPx = 0;
      _trimStart = null;
      _lastSnap = null;
      if (!commit) {
        _preview = null;
        _trim = null;
      }
    });
    if (commit) widget.onTrimCommit?.call(r.plan, r.edgeSec);
  }

  /// The OS took the pointer (call, gesture arena, finger left the screen
  /// oddly): nothing is committed and the timeline snaps back.
  void _cancelTrim() => setState(() {
    _trimShotId = null;
    _trimDeltaPx = 0;
    _trimStart = null;
    _trim = null;
    _preview = null;
    _lastSnap = null;
  });

  void _startReorder(String shotId) => setState(() {
    _dragShotId = shotId;
    _dragDx = 0;
  });

  void _updateReorder(double dx) => setState(() => _dragDx = dx);

  void _endReorder(Shot shot) {
    if (_dragShotId != shot.id) return;
    final draggedCenter =
        shot.startSec + shot.duration / 2 + _dragDx / widget.pps;
    var targetIndex = 0;
    var bestDist = double.infinity;
    for (final (j, other) in widget.plan.shots.indexed) {
      final center = other.startSec + other.duration / 2;
      final d = (center - draggedCenter).abs();
      if (d < bestDist) {
        bestDist = d;
        targetIndex = j;
      }
    }
    setState(() {
      _dragShotId = null;
      _dragDx = 0;
    });
    final currentIndex = widget.plan.shots.indexWhere((s) => s.id == shot.id);
    if (targetIndex != currentIndex) {
      widget.onReorder?.call(shot.id, targetIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // While trimming (and until the committed plan arrives), draw the live
    // ripple preview instead of the saved plan.
    final plan = _preview ?? widget.plan;
    final pps = widget.pps;
    final t = widget.t;
    final selectedId = widget.selectedId;
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

    // One handle: a grip strip at a shot's edge. Raw pointer tracking
    // (not a GestureDetector drag recognizer) so it is immune to the
    // ancestor `SingleChildScrollView`'s own horizontal drag recognizer —
    // the two would otherwise fight over the same gesture.
    Widget trimHandle(Shot shot, bool isLeft) {
      final active = _trimShotId == shot.id && _trimIsLeft == isLeft;
      final trimmable =
          widget.planJson != null && (!isLeft || shot.sourceIn != null);
      return Positioned(
        left: isLeft ? 0 : null,
        right: isLeft ? null : 0,
        top: 4,
        bottom: 4,
        width: _handleWidth,
        child: Listener(
          key: ValueKey('trim-${isLeft ? 'left' : 'right'}-${shot.id}'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) {
            _handleDown = true;
            if (trimmable) _startTrim(shot.id, isLeft);
          },
          onPointerMove: trimmable
              ? (e) => _updateTrim(shot.id, e.delta.dx)
              : null,
          onPointerUp: (_) {
            if (trimmable) _commitTrim(shot.id);
            // Cleared after the tap recognizer has seen this same event.
            scheduleMicrotask(() => _handleDown = false);
          },
          onPointerCancel: (_) {
            if (trimmable) _cancelTrim();
            scheduleMicrotask(() => _handleDown = false);
          },
          child: Semantics(
            button: true,
            label: trimmable
                ? '${isLeft ? 'Boshlanish' : 'Tugash'} nuqtasini o‘zgartirish'
                : 'Trim mavjud emas',
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: active ? 0.95 : 0.5),
                borderRadius: BorderRadius.horizontal(
                  left: isLeft ? const Radius.circular(7) : Radius.zero,
                  right: isLeft ? Radius.zero : const Radius.circular(7),
                ),
              ),
              child: Icon(
                LucideIcons.gripVertical,
                size: 11,
                color: Colors.black.withValues(alpha: trimmable ? 0.75 : 0.3),
              ),
            ),
          ),
        ),
      );
    }

    // Live readout while a handle is being dragged: the shot's length as it
    // will be saved (the preview is already clamped and frame-rounded), with
    // a magnet when the edge is snapped.
    Widget? trimReadout(Shot shot) {
      if (_trimShotId != shot.id) return null;
      final snapped = _trim?.snappedAt != null;
      return Positioned(
        top: -26,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (snapped) ...[
                  const Icon(LucideIcons.magnet, size: 11, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Text(
                  seconds(shot.duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget shotBody(int i, Shot s) {
      // The shot under a trim reads as selected: its frame shows clearly.
      final isSelected = selectedId == s.id || _trimShotId == s.id;
      final content = Row(
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
              child: Icon(LucideIcons.blend, size: 12, color: Colors.white),
            ),
          if (s.duration * pps > 70)
            Flexible(
              child: Text(
                seconds(s.duration),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
        ],
      );
      return GestureDetector(
        key: ValueKey('shot-${s.id}'),
        onTap: () => widget.onSelect(s),
        onLongPressStart: (_) => _startReorder(s.id),
        onLongPressMoveUpdate: (LongPressMoveUpdateDetails d) =>
            _updateReorder(d.offsetFromOrigin.dx),
        onLongPressEnd: (_) => _endReorder(s),
        onLongPressCancel: () => _endReorder(s),
        child: Container(
          // Content starts clear of the trim handles reserved at both
          // edges, so the index/duration labels never sit under a handle's
          // hit zone (which would otherwise steal taps meant to select).
          padding: EdgeInsets.symmetric(horizontal: 7 + _handleWidth),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: shotColor(
              i,
            ).withValues(alpha: selectedId == null || isSelected ? 0.95 : 0.45),
            borderRadius: BorderRadius.circular(9),
            border: isSelected
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
          child: content,
        ),
      );
    }

    Widget shotSegment(int i, Shot s) {
      final left = s.startSec * pps;
      final segWidth = math.max(s.duration * pps - 3, 6.0);
      final dragging = _dragShotId == s.id;
      final body = Stack(
        clipBehavior: Clip.none,
        children: [
          shotBody(i, s),
          trimHandle(s, true),
          trimHandle(s, false),
          if (trimReadout(s) != null) trimReadout(s)!,
        ],
      );
      // The wrapper widgets (Transform.scale, Material) are always present,
      // varying only their parameters with `dragging` — not whether they
      // exist. Swapping the widget TYPE at this slot when a drag starts
      // would make Flutter tear down and rebuild the subtree, destroying
      // the long-press recognizer that is mid-gesture inside `body`. The
      // explicit key matters too: the dragged shot is moved to the end of
      // the stacking order below (so it paints on top), and without a key
      // Flutter would match children by list position, not identity.
      return Positioned(
        key: ValueKey('seg-${s.id}'),
        left: left + (dragging ? _dragDx : 0),
        width: segWidth,
        top: 0,
        bottom: 0,
        child: Transform.scale(
          scale: dragging ? 1.05 : 1.0,
          child: Material(
            elevation: dragging ? 10 : 0,
            color: Colors.transparent,
            shadowColor: Colors.black,
            borderRadius: BorderRadius.circular(9),
            child: body,
          ),
        ),
      );
    }

    // Shots painted in a stable order, except the one being reordered is
    // moved last so it draws above its neighbours while it follows the
    // finger.
    final shotOrder = [for (final (i, s) in plan.shots.indexed) (i, s)]
      ..sort((a, b) {
        final aDrag = a.$2.id == _dragShotId;
        final bDrag = b.$2.id == _dragShotId;
        if (aDrag == bDrag) return 0;
        return aDrag ? 1 : -1;
      });

    return SizedBox(
      height: 196,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: _gestureActive ? const NeverScrollableScrollPhysics() : null,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: width,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (d) {
              if (_handleDown) return;
              widget.onSeek(
                (d.localPosition.dx / pps).clamp(0, plan.durationSec),
              );
            },
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
                      for (final (i, s) in shotOrder) shotSegment(i, s),
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
                          onTap: widget.onCaptionTap == null
                              ? null
                              : () => widget.onCaptionTap!(i, c.text),
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
                                painter: MusicWaveformPainter(
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
                // Snap guide: where the trimmed edge is magnetized to.
                if (_trimShotId != null && _trim?.snappedAt != null)
                  Positioned(
                    left: _trim!.snappedAt! * pps - 1,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(width: 2, color: p.accent),
                    ),
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
