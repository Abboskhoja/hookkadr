import 'plan_ops.dart';

/// Which edge of a shot is being dragged.
enum TrimEdge {
  /// The in-point: footage is removed from (or revealed at) the head; the
  /// shot keeps its place on the timeline and everything after it ripples.
  head,

  /// The out-point: the shot gets longer or shorter at its end and
  /// everything after it ripples.
  tail,
}

/// One frame of a live trim: the whole plan as it would be if the finger
/// were lifted right now.
class TrimResult {
  const TrimResult({
    required this.plan,
    required this.duration,
    required this.edgeSec,
    required this.changed,
    this.snappedAt,
  });

  /// The rippled plan — exactly what gets committed (and exported) on
  /// release, because it comes from the same `PlanOps` call.
  final Map<String, dynamic> plan;

  /// The trimmed shot's new timeline length, in seconds.
  final double duration;

  /// The timeline time the preview should show for this edge: the first
  /// frame of the shot for a head trim, its last frame for a tail trim.
  final double edgeSec;

  /// False when the drag would leave the shot as it was (a tap, or a drag
  /// held against a limit) — nothing to commit.
  final bool changed;

  /// The snap target the edge is sitting on, if any (playhead, beat).
  final double? snappedAt;
}

/// CapCut-style live ripple trim on the magnetic timeline.
///
/// Every pointer move calls [apply] with the plan as it was when the drag
/// began and the total drag distance so far — never the previous preview —
/// so moving back and forth never accumulates rounding, and cancelling is
/// simply "throw the preview away".
///
/// Rules (single main video track — the plan has no other video tracks or
/// track locks to propagate to):
/// - Lengths move in whole frames of the export frame rate.
/// - A shot stays between [PlanOps.minShot] and [PlanOps.maxShot] and inside
///   its source clip (`sourceLimit`); a head trim can't reveal footage
///   before the clip's first frame.
/// - Shots after the trimmed one ripple (no gaps, no overlaps). Captions
///   follow their shots; music and audio beds keep absolute time; a shot's
///   own audio is part of the shot and moves with it.
/// - Transitions need no special case: the renderer limits a transition to
///   half of either neighbour, so a short shot can't be swallowed.
abstract final class RippleTrim {
  static TrimResult apply(
    Map<String, dynamic> start, {
    required String shotId,
    required TrimEdge edge,
    required double deltaSec,
    required int fps,
    double? sourceLimit,
    List<double> snapTargets = const [],
    double snapWindowSec = 0,
  }) {
    final shots = (start['shots'] as List).cast<Map<String, dynamic>>();
    final shot = shots.firstWhere((s) => s['id'] == shotId);
    final s0 = (shot['startSec'] as num).toDouble();
    final dur = (shot['endSec'] as num).toDouble() - s0;
    final speed = (shot['speed'] as num?)?.toDouble() ?? 1.0;
    final frame = 1 / fps;
    double frames(double sec) => (sec * fps).roundToDouble() / fps;

    if (edge == TrimEdge.head) {
      if (shot['sourceIn'] == null) {
        return TrimResult(
          plan: start,
          duration: dur,
          edgeSec: s0,
          changed: false,
        );
      }
      // Timeline seconds → source seconds (a 2× shot uses 2 s of source
      // per timeline second).
      final d = frames(deltaSec);
      final plan = PlanOps.trimStart(start, shotId, d * speed);
      final newDur = _duration(plan, shotId);
      return TrimResult(
        plan: plan,
        duration: newDur,
        edgeSec: s0,
        changed: (newDur - dur).abs() > frame / 2,
      );
    }

    // Tail: where the edge would be, snapped, in whole frames, clamped.
    var edgeAt = s0 + dur + deltaSec;
    double? snapped;
    var best = snapWindowSec;
    for (final t in snapTargets) {
      final dist = (t - edgeAt).abs();
      if (t > s0 && dist <= best) {
        best = dist;
        snapped = t;
      }
    }
    if (snapped != null) edgeAt = snapped;
    var newDur = frames(edgeAt - s0);
    var upper = PlanOps.maxShot;
    final sourceIn = (shot['sourceIn'] as num?)?.toDouble();
    if (sourceLimit != null && sourceIn != null) {
      upper = ((sourceLimit - sourceIn) / speed)
          .clamp(PlanOps.minShot, PlanOps.maxShot)
          .toDouble();
    }
    final lower = (PlanOps.minShot * fps).ceilToDouble() / fps;
    final upperFrames = (upper * fps).floorToDouble() / fps;
    if (newDur < lower) newDur = lower;
    if (newDur > upperFrames) newDur = upperFrames;
    if (snapped != null && (s0 + newDur - snapped).abs() > frame) {
      snapped = null; // a limit won over the snap
    }
    final plan = PlanOps.resizeShot(
      start,
      shotId,
      newDur,
      sourceLimit: sourceLimit,
    );
    final actual = _duration(plan, shotId);
    return TrimResult(
      plan: plan,
      duration: actual,
      edgeSec: s0 + actual - frame,
      changed: (actual - dur).abs() > frame / 2,
      snappedAt: snapped,
    );
  }

  static double _duration(Map<String, dynamic> plan, String shotId) {
    final s = (plan['shots'] as List).cast<Map<String, dynamic>>().firstWhere(
      (s) => s['id'] == shotId,
    );
    return (s['endSec'] as num).toDouble() - (s['startSec'] as num).toDouble();
  }
}
