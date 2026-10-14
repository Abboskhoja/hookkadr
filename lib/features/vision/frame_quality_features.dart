import 'dart:math' as math;
import 'dart:typed_data';

/// Versioned numerical features shared with Python's frame_quality.py.
///
/// Input must be packed RGB24, already prepared using the model's analysis
/// filter. These measurements describe technical image quality, not subjects,
/// creative merit, brand identity, or product fidelity.
abstract final class FrameQualityFeatures {
  static const version = 1;
  static const minSide = 12;
  static const names = <String>[
    'lap_var_log',
    'tenengrad_log',
    'detail_ratio',
    'edge_density',
    'y_mean',
    'y_std',
    'p05',
    'p50',
    'p95',
    'dark_frac',
    'bright_frac',
    'noise_log',
    'colorfulness',
    'sat_mean',
    'entropy',
  ];

  static List<double> extract(
    Uint8List rgb, {
    required int width,
    required int height,
  }) {
    if (width < minSide || height < minSide) {
      throw ArgumentError('Frame must be at least ${minSide}x$minSide.');
    }
    final n = width * height;
    if (rgb.length != n * 3) {
      throw ArgumentError('Expected exactly ${n * 3} packed RGB24 bytes.');
    }
    final y = Float64List(n);
    final histogram = List<int>.filled(256, 0);
    var ySum = 0.0;
    var rgSum = 0.0;
    var ybSum = 0.0;
    var saturationSum = 0.0;
    for (var i = 0; i < n; i++) {
      final r = rgb[i * 3];
      final g = rgb[i * 3 + 1];
      final b = rgb[i * 3 + 2];
      final yi = 299 * r + 587 * g + 114 * b;
      y[i] = yi / 1000.0;
      ySum += y[i];
      histogram[(yi + 500) ~/ 1000]++;
      rgSum += r - g;
      ybSum += 0.5 * (r + g) - b;
      final mx = math.max(math.max(r, g), b);
      final mn = math.min(math.min(r, g), b);
      saturationSum += mx > 0 ? (mx - mn) / mx : 0.0;
    }
    final yMean = ySum / n;
    final rgMean = rgSum / n;
    final ybMean = ybSum / n;
    var yVarianceSum = 0.0;
    var rgVarianceSum = 0.0;
    var ybVarianceSum = 0.0;
    for (var i = 0; i < n; i++) {
      final r = rgb[i * 3];
      final g = rgb[i * 3 + 1];
      final b = rgb[i * 3 + 2];
      final dy = y[i] - yMean;
      final drg = r - g - rgMean;
      final dyb = 0.5 * (r + g) - b - ybMean;
      yVarianceSum += dy * dy;
      rgVarianceSum += drg * drg;
      ybVarianceSum += dyb * dyb;
    }
    var darkCount = 0;
    var brightCount = 0;
    var entropy = 0.0;
    for (var code = 0; code < histogram.length; code++) {
      final count = histogram[code];
      if (code < 20) darkCount += count;
      if (code > 235) brightCount += count;
      if (count > 0) {
        final p = count / n;
        entropy -= p * (math.log(p) / math.ln2);
      }
    }

    final interiorCount = (width - 2) * (height - 2);
    final laplacian = Float64List(interiorCount);
    var lapSum = 0.0;
    var gradientSum = 0.0;
    var edgeCount = 0;
    var noiseSum = 0.0;
    var k = 0;
    for (var row = 1; row < height - 1; row++) {
      for (var col = 1; col < width - 1; col++) {
        final p = row * width + col;
        final c = y[p];
        final tl = y[p - width - 1];
        final tc = y[p - width];
        final tr = y[p - width + 1];
        final ml = y[p - 1];
        final mr = y[p + 1];
        final bl = y[p + width - 1];
        final bc = y[p + width];
        final br = y[p + width + 1];
        final lap = tc + bc + ml + mr - 4.0 * c;
        laplacian[k++] = lap;
        lapSum += lap;
        final gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
        final gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
        final mag2 = gx * gx + gy * gy;
        gradientSum += mag2;
        if (mag2 > 10000.0) edgeCount++;
        final m =
            tl -
            2.0 * tc +
            tr -
            2.0 * ml +
            4.0 * c -
            2.0 * mr +
            bl -
            2.0 * bc +
            br;
        noiseSum += m.abs();
      }
    }
    final lapMean = lapSum / interiorCount;
    var lapVarianceSum = 0.0;
    for (final lap in laplacian) {
      final delta = lap - lapMean;
      lapVarianceSum += delta * delta;
    }

    final box3 = _boxMean(y, width, height, 1);
    final box9 = _boxMean(y, width, height, 4);
    var fineSum = 0.0;
    var coarseSum = 0.0;
    for (var row = 0; row < height - 8; row++) {
      for (var col = 0; col < width - 8; col++) {
        final center = y[(row + 4) * width + col + 4];
        final b3 = box3[(row + 3) * (width - 2) + col + 3];
        final b9 = box9[row * (width - 8) + col];
        fineSum += (center - b3).abs();
        coarseSum += (b3 - b9).abs();
      }
    }
    final detailCount = (width - 8) * (height - 8);
    final sigma =
        math.sqrt(math.pi / 2.0) *
        noiseSum /
        (6.0 * (width - 2) * (height - 2));
    // Keep the same sqrt-then-square operation order as the Python features.
    final rgStd = math.sqrt(rgVarianceSum / n);
    final ybStd = math.sqrt(ybVarianceSum / n);
    final colorfulness =
        (math.sqrt(rgStd * rgStd + ybStd * ybStd) +
            0.3 * math.sqrt(rgMean * rgMean + ybMean * ybMean)) /
        100.0;
    return List<double>.unmodifiable([
      math.log(1.0 + lapVarianceSum / interiorCount),
      math.log(1.0 + gradientSum / interiorCount),
      (fineSum / detailCount) / (coarseSum / detailCount + 0.5),
      edgeCount / interiorCount,
      yMean / 255.0,
      math.sqrt(yVarianceSum / n) / 255.0,
      _percentile(histogram, n, 0.05) / 255.0,
      _percentile(histogram, n, 0.5) / 255.0,
      _percentile(histogram, n, 0.95) / 255.0,
      darkCount / n,
      brightCount / n,
      math.log(1.0 + sigma),
      colorfulness,
      saturationSum / n,
      entropy / 8.0,
    ]);
  }

  static int _percentile(List<int> histogram, int n, double p) {
    final target = p * n;
    var cumulative = 0;
    for (var code = 0; code < histogram.length; code++) {
      cumulative += histogram[code];
      if (cumulative >= target) return code;
    }
    return 255;
  }

  /// Sum columns first, then rows, matching Python's floating-point order.
  static Float64List _boxMean(Float64List y, int w, int h, int radius) {
    final size = 2 * radius + 1;
    final outW = w - 2 * radius;
    final outH = h - 2 * radius;
    final horizontal = Float64List(h * outW);
    for (var row = 0; row < h; row++) {
      for (var col = 0; col < outW; col++) {
        var sum = y[row * w + col];
        for (var dx = 1; dx < size; dx++) {
          sum += y[row * w + col + dx];
        }
        horizontal[row * outW + col] = sum;
      }
    }
    final result = Float64List(outH * outW);
    for (var row = 0; row < outH; row++) {
      for (var col = 0; col < outW; col++) {
        var sum = horizontal[row * outW + col];
        for (var dy = 1; dy < size; dy++) {
          sum += horizontal[(row + dy) * outW + col];
        }
        result[row * outW + col] = sum / (size * size);
      }
    }
    return result;
  }
}
