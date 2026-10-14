import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'scene_quality_model.dart';

class TechnicalQualityReport {
  const TechnicalQualityReport({
    required this.modelVersion,
    required this.samples,
    required this.meanQuality,
    required this.flags,
  });
  final String modelVersion;
  final int samples;
  final double meanQuality;
  final Map<String, int> flags;
}

abstract interface class TechnicalQualityAnalyzer {
  Future<TechnicalQualityReport> scan(String path);
}

/// Samples at most 12 frames from the first 24 seconds. Runs the same FFmpeg
/// pixel transform as training; feature extraction/MLP run off the UI isolate.
/// The output describes these samples only, not the entire clip.
class SceneQualityScanner implements TechnicalQualityAnalyzer {
  @override
  Future<TechnicalQualityReport> scan(String path) async {
    final artifact = await rootBundle.loadString(SceneQualityModel.assetPath);
    final model = SceneQualityModel.fromJsonString(artifact);
    final temp = await getTemporaryDirectory();
    await temp.create(recursive: true);
    final dir = await temp.createTemp('kart_quality_');
    try {
      final session = await FFmpegKit.executeWithArguments([
        '-hide_banner',
        '-loglevel',
        'error',
        '-i',
        path,
        '-vf',
        'fps=1/2:start_time=0:eof_action=pass,${model.analysisFilter}',
        '-frames:v',
        '12',
        '-an',
        '-c:v',
        'ppm',
        '-f',
        'image2',
        '${dir.path}/frame_%03d.ppm',
      ]);
      if (!ReturnCode.isSuccess(await session.getReturnCode())) {
        throw const FormatException('Kadrlarni tahlil uchun o‘qib bo‘lmadi.');
      }
      final paths = [
        for (final f in dir.listSync())
          if (f is File && f.path.endsWith('.ppm')) f.path,
      ]..sort();
      if (paths.isEmpty) throw const FormatException('Tahlil kadrlari yo‘q.');
      return await compute(_scoreFiles, (artifact: artifact, paths: paths));
    } finally {
      await dir.delete(recursive: true);
    }
  }
}

TechnicalQualityReport _scoreFiles(
  ({String artifact, List<String> paths}) input,
) {
  final model = SceneQualityModel.fromJsonString(input.artifact);
  var sum = 0.0;
  final flags = <String, int>{};
  for (final path in input.paths) {
    final frame = decodeAnalysisPpm(File(path).readAsBytesSync());
    final result = model.predictFrame(
      frame.rgb,
      width: frame.width,
      height: frame.height,
    );
    sum += result.technicalQuality;
    for (final flag in result.flags) {
      flags.update(flag, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return TechnicalQualityReport(
    modelVersion: model.version,
    samples: input.paths.length,
    meanQuality: sum / input.paths.length,
    flags: Map.unmodifiable(flags),
  );
}

/// Binary P6 output preserves exact RGB bytes, including whitespace-valued
/// first pixels. Restricts size to the analysis model's maximum dimension.
({int width, int height, Uint8List rgb}) decodeAnalysisPpm(Uint8List data) {
  var pos = 0;
  bool space(int c) => c == 32 || (c >= 9 && c <= 13);
  String token() {
    while (pos < data.length) {
      if (space(data[pos])) {
        pos++;
      } else if (data[pos] == 35) {
        while (pos < data.length && data[pos] != 10) {
          pos++;
        }
      } else {
        break;
      }
    }
    final start = pos;
    while (pos < data.length && !space(data[pos])) {
      pos++;
    }
    return String.fromCharCodes(data.sublist(start, pos));
  }

  if (token() != 'P6') throw const FormatException('Expected P6 frame.');
  final w = int.tryParse(token());
  final h = int.tryParse(token());
  final max = token();
  if (w == null ||
      h == null ||
      w < 12 ||
      h < 12 ||
      w > 384 ||
      h > 384 ||
      max != '255' ||
      pos >= data.length ||
      !space(data[pos])) {
    throw const FormatException('Invalid analysis frame header.');
  }
  pos++; // Exactly one delimiter; following whitespace may be pixel data.
  if (data.length - pos != w * h * 3) {
    throw const FormatException('Truncated or oversized analysis frame.');
  }
  return (width: w, height: h, rgb: Uint8List.sublistView(data, pos));
}
