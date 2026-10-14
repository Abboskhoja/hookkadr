import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/poster.dart';
import '../../analysis/domain/edit_plan.dart';
import 'music_waveform_painter.dart';

/// The multi-lane scrubber: ruler, shots, captions, audio tracks and the
/// music waveform, with a draggable playhead. Pinch-to-zoom is handled by
/// the caller (it wraps this widget in a `Listener`) via [pps].
class EditorTimeline extends StatelessWidget {
  const EditorTimeline({
    super.key,
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
