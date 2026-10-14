import 'dart:typed_data';

import '../render/media_analyzer.dart';
import '../render/thumbnailer.dart';
import 'ai_clients.dart';

/// One sampled picture of a clip.
class SampledFrame {
  const SampledFrame(this.timeSec, this.jpeg);
  final double timeSec;
  final Uint8List jpeg;
}

/// Everything Claude is shown about one clip: pictures plus measured facts.
class ClipEvidence {
  const ClipEvidence({required this.facts, required this.frames});
  final ClipFacts facts;
  final List<SampledFrame> frames;
}

/// Picks which moments of a clip to show the model: the opening, just after
/// every detected scene cut (each shot gets looked at), then evenly spaced
/// fill, capped at [maxFrames]. Pure, so it is unit-tested.
List<double> sampleTimes(
  double durationSec,
  List<double> sceneCuts, {
  int maxFrames = 12,
}) {
  if (durationSec <= 0) return const [];
  double clamp(double t) => t.clamp(0.1, (durationSec - 0.2).clamp(0.1, 1e9));
  const minGap = 0.8;
  bool far(List<double> xs, double t) =>
      xs.every((x) => (x - t).abs() >= minGap);

  // Opening and the frame right after every scene cut come first: each shot
  // must be looked at, so they are never displaced by even-spaced fill.
  final out = <double>[clamp(0.3)];
  for (final c in sceneCuts) {
    final t = clamp(c + 0.25);
    if (far(out, t)) out.add(t);
  }
  // Even fill so long takes without cuts are still covered.
  final fill = (durationSec / 2.5).ceil().clamp(3, maxFrames);
  for (var i = 0; i < fill; i++) {
    final t = clamp(durationSec * (i + 0.5) / fill);
    if (far(out, t)) out.add(t);
  }
  out.sort();
  // Too many: thin out evenly but always keep the first and last.
  while (out.length > maxFrames) {
    var worst = 1;
    var gap = double.infinity;
    for (var i = 1; i < out.length - 1; i++) {
      final g = out[i + 1] - out[i - 1];
      if (g < gap) {
        gap = g;
        worst = i;
      }
    }
    out.removeAt(worst);
  }
  return out;
}

/// "Eyes" for Claude: watches a clip by looking at frames FFmpeg extracts on
/// the phone (no upload size limit, original video never leaves the device)
/// and at measured scene cuts / silences, then describes it like a Gemini
/// video analysis so [PlanGenerator] can plan from it unchanged.
class ClaudeFrameAnalyst implements VideoAnalyst {
  ClaudeFrameAnalyst(
    this._claude, {
    Future<ClipEvidence> Function(String)? load,
  }) : _load = load ?? _loadFromDevice;

  final ClaudeClient _claude;
  final Future<ClipEvidence> Function(String path) _load;

  static Future<ClipEvidence> _loadFromDevice(String path) async {
    final facts = await MediaAnalyzer().analyze('clip', path);
    final frames = <SampledFrame>[];
    for (final t in sampleTimes(facts.durationSec, facts.sceneCuts)) {
      final jpeg = await Thumbnailer.jpeg(path, atSec: t, maxWidth: 512);
      if (jpeg != null) frames.add(SampledFrame(t, jpeg));
    }
    return ClipEvidence(facts: facts, frames: frames);
  }

  static const system =
      'You are the eyes of a professional video editor. You are shown frames '
      'sampled from ONE clip, each labelled with its timestamp, plus measured '
      'facts (duration, scene cuts, silent pauses). Audio itself is not '
      'available: never invent speech or music; only use the measured silence '
      'data for sound. Describe only what is visible. Use only the labelled '
      'timestamps; give ranges in seconds that stay inside the clip duration.';

  static const task =
      'Report as a plain list: (1) one-line summary of what the clip is; '
      '(2) shots with start–end seconds, framing and camera movement you can '
      'infer between frames; (3) subject/product details and any on-screen '
      'text; (4) lighting, colour and image quality problems (blur, dark, '
      'shaky, overexposed); (5) the strongest 2–4 usable moments with '
      'second ranges and why; (6) the best opening hook frame; (7) parts to '
      'avoid (dead time, blur, repeated content). Be factual and concise.';

  @override
  Future<String> analyzeVideo(String path) async {
    final ev = await _load(path);
    if (ev.frames.isEmpty) {
      throw const AiException(
        'Videodan kadr olib bo‘lmadi. Fayl buzilgan yoki qo‘llab-quvvatlanmaydi.',
      );
    }
    final text = await _claude.describeImages(
      system: system,
      images: [
        for (final f in ev.frames)
          (label: 'Frame at ${f.timeSec.toStringAsFixed(1)} s', jpeg: f.jpeg),
      ],
      prompt: '${ev.facts.hint}\n\n$task',
      maxTokens: 1400,
    );
    return '${ev.facts.hint}\n$text';
  }
}
