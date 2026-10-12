import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:path_provider/path_provider.dart';

/// Tempo and beat grid of a song.
class BeatAnalysis {
  const BeatAnalysis({
    required this.bpm,
    required this.beats,
    this.envelope = const [],
  });

  /// Loudness every [envelopeStep] seconds, 0..1 (for the waveform view).
  final List<double> envelope;
  static const envelopeStep = 0.1;

  /// Estimated tempo; 0 when no steady rhythm was found.
  final double bpm;

  /// Beat times in seconds from the start of the song.
  final List<double> beats;
}

/// Offline beat tracking (no AI, no network).
///
/// Method: short-time energy → onset strength (energy rise over a local
/// average) → tempo by autocorrelation of the onset envelope (60–180 BPM)
/// → phase that best lines up with the onsets → evenly spaced beat grid.
/// Good for music with a clear pulse; free-time music yields bpm 0.
abstract final class BeatDetector {
  static const sampleRate = 11025;
  static const _hop = 256; // ≈23 ms

  /// Analyses mono 16-bit PCM. Pure function (unit-testable).
  static BeatAnalysis fromPcm(Int16List pcm, {int rate = sampleRate}) {
    final frames = pcm.length ~/ _hop;
    if (frames < 16) return const BeatAnalysis(bpm: 0, beats: []);
    final hopSec = _hop / rate;

    // 1) energy per hop
    final energy = Float64List(frames);
    for (var f = 0; f < frames; f++) {
      var sum = 0.0;
      final base = f * _hop;
      for (var i = 0; i < _hop; i++) {
        final v = pcm[base + i] / 32768.0;
        sum += v * v;
      }
      energy[f] = sum / _hop;
    }

    // Waveform: loudest hop in each 0.1 s window. Windows are cut by time,
    // not by a rounded hop count, so the drawing never drifts from the song.
    final buckets = <double>[];
    final totalSec = frames * hopSec;
    for (var b = 0; b * BeatAnalysis.envelopeStep < totalSec; b++) {
      final from = (b * BeatAnalysis.envelopeStep / hopSec).floor();
      final to = math.min(
        frames,
        ((b + 1) * BeatAnalysis.envelopeStep / hopSec).floor(),
      );
      var m = 0.0;
      for (var f = from; f < math.max(to, from + 1) && f < frames; f++) {
        if (energy[f] > m) m = energy[f];
      }
      buckets.add(math.sqrt(m));
    }
    final peak = buckets.fold<double>(0, math.max);
    final envelope = [
      for (final v in buckets)
        peak <= 0 ? 0.0 : ((v / peak) * 100).round() / 100,
    ];

    // 2) onset strength: positive rise of log-energy vs the previous frame
    final onset = Float64List(frames);
    for (var f = 1; f < frames; f++) {
      final d = math.log(energy[f] + 1e-9) - math.log(energy[f - 1] + 1e-9);
      onset[f] = d > 0 ? d : 0;
    }
    final mean = onset.reduce((a, b) => a + b) / frames;
    if (mean <= 1e-6) {
      return BeatAnalysis(bpm: 0, beats: const [], envelope: envelope);
    }

    // 3) tempo: autocorrelation over 60–180 BPM lags, weighted by a
    // log-normal prior around 120 BPM (avoids picking half/double tempo).
    final minLag = (60 / 180 / hopSec).floor();
    final maxLag = math.min((60 / 60 / hopSec).ceil(), frames - 1);
    final raw = <int, double>{};
    for (var lag = minLag; lag <= maxLag; lag++) {
      var s = 0.0;
      for (var f = lag; f < frames; f++) {
        s += onset[f] * onset[f - lag];
      }
      raw[lag] = s / (frames - lag);
    }
    var bestLag = 0;
    var bestScore = 0.0;
    raw.forEach((lag, s) {
      final bpm = 60 / (lag * hopSec);
      final octaves = math.log(bpm / 120) / math.ln2;
      final weighted = s * math.exp(-0.5 * octaves * octaves);
      if (weighted > bestScore) {
        bestScore = weighted;
        bestLag = lag;
      }
    });
    // If half the period is almost as strong, the true beat is the faster one.
    final half = (bestLag / 2).round();
    if (half >= minLag && (raw[half] ?? 0) >= 0.6 * (raw[bestLag] ?? 0)) {
      bestLag = half;
    }
    if (bestLag == 0) {
      return BeatAnalysis(bpm: 0, beats: const [], envelope: envelope);
    }

    // 4) Refine to a fractional period and find the phase. Real tempos are
    // rarely a whole number of hops (0.5 s ≈ 21.5 hops), so an integer grid
    // drifts off the beats over a long song. Onsets are matched within ±1
    // hop to tolerate small timing jitter.
    double peakNear(double pos) {
      final c = pos.round();
      var m = 0.0;
      for (var k = c - 1; k <= c + 1; k++) {
        if (k >= 0 && k < frames && onset[k] > m) m = onset[k];
      }
      return m;
    }

    var bestPeriod = bestLag.toDouble();
    var bestPhase = 0.0;
    var phaseScore = -1.0;
    for (var period = bestLag - 1.0; period <= bestLag + 1.0; period += 0.05) {
      if (period < minLag) continue;
      for (var ph = 0; ph < period; ph++) {
        var sc = 0.0;
        for (var pos = ph.toDouble(); pos < frames; pos += period) {
          sc += peakNear(pos);
        }
        if (sc > phaseScore) {
          phaseScore = sc;
          bestPhase = ph.toDouble();
          bestPeriod = period;
        }
      }
    }

    // A steady pulse puts clearly more energy on the grid than average.
    final hits = (frames - bestPhase) / bestPeriod;
    if (phaseScore / hits < mean * 2) {
      return BeatAnalysis(bpm: 0, beats: const [], envelope: envelope);
    }

    final period = bestPeriod * hopSec;
    final beats = <double>[
      for (var t = bestPhase * hopSec; t < frames * hopSec; t += period)
        (t * 1000).round() / 1000,
    ];
    return BeatAnalysis(
      bpm: (60 / period * 10).round() / 10,
      beats: beats,
      envelope: envelope,
    );
  }

  /// Decodes up to [maxSeconds] of the file with FFmpeg and analyses it.
  static Future<BeatAnalysis> analyzeFile(
    String path, {
    int maxSeconds = 240,
  }) async {
    final tmp = await getTemporaryDirectory();
    final out = File(
      '${tmp.path}/beats_${DateTime.now().microsecondsSinceEpoch}.pcm',
    );
    try {
      final session = await FFmpegKit.executeWithArguments([
        '-y',
        '-hide_banner',
        '-i',
        path,
        '-t',
        '$maxSeconds',
        '-ac',
        '1',
        '-ar',
        '$sampleRate',
        '-f',
        's16le',
        out.path,
      ]);
      if (!ReturnCode.isSuccess(await session.getReturnCode()) ||
          !out.existsSync()) {
        return const BeatAnalysis(bpm: 0, beats: []);
      }
      final bytes = await out.readAsBytes();
      final pcm = bytes.buffer.asInt16List(
        bytes.offsetInBytes,
        bytes.lengthInBytes ~/ 2,
      );
      return fromPcm(pcm);
    } finally {
      if (out.existsSync()) out.deleteSync();
    }
  }
}
