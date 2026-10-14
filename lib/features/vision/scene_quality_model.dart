import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'frame_quality_features.dart';

/// A model estimate of technical frame quality and image defects.
///
/// This is a proxy learned from controlled image degradations. It does not
/// evaluate storytelling, originality, product accuracy, or commercial value.
class SceneQualityPrediction {
  const SceneQualityPrediction._({
    required this.technicalQuality,
    required this.defects,
    required this.flags,
  });

  static const scoreLabel = 'Technical frame quality';
  final double technicalQuality;
  final Map<String, double> defects;
  final List<String> flags;
}

/// Float64 evaluation of the versioned Python-exported MLP, entirely offline.
///
/// Invalid artifacts fail closed. There are no placeholder scores or heuristic
/// fallbacks when the model is missing, incompatible, or malformed.
class SceneQualityModel {
  SceneQualityModel._(
    this._mean,
    this._std,
    this._layers, {
    required this.name,
    required this.version,
    required this.defects,
    required this.thresholds,
  });

  static const artifactSchema = 'hookkadr.model/1';
  static const assetPath = 'assets/models/scene_quality.json';
  static const supportedAnalysisLongSide = 384;
  static const supportedAnalysisFilter =
      'format=yuv420p,scale=w=384:h=384'
      ':force_original_aspect_ratio=decrease:flags=area,format=rgb24';
  static const supportedDefects = <String>[
    'blurry',
    'dark',
    'overexposed',
    'noisy',
    'low_contrast',
  ];

  final String name;
  final String version;
  final List<String> defects;
  final Map<String, double> thresholds;
  final List<double> _mean;
  final List<double> _std;
  final List<_DenseLayer> _layers;

  String get analysisFilter => supportedAnalysisFilter;
  int get analysisLongSide => supportedAnalysisLongSide;

  static Future<SceneQualityModel> loadAsset({AssetBundle? bundle}) async =>
      SceneQualityModel.fromJsonString(
        await (bundle ?? rootBundle).loadString(assetPath),
      );

  factory SceneQualityModel.fromJsonString(String source) =>
      SceneQualityModel.fromJson(_object(jsonDecode(source), 'artifact'));

  factory SceneQualityModel.fromJson(Map<String, dynamic> artifact) {
    if (artifact['schema'] != artifactSchema ||
        artifact['task'] != 'frame_quality' ||
        artifact['name'] != 'scene_quality') {
      throw const FormatException('Unsupported scene quality artifact.');
    }
    final version = artifact['version'];
    if (version is! String || version.trim().isEmpty) {
      throw const FormatException('Model version must be a nonempty string.');
    }
    final input = _object(artifact['input'], 'input');
    if (input['featureVersion'] != FrameQualityFeatures.version ||
        !_sameList(input['features'], FrameQualityFeatures.names) ||
        input['analysisFilter'] != supportedAnalysisFilter ||
        input['analysisLongSide'] != supportedAnalysisLongSide) {
      throw const FormatException('Incompatible frame quality input contract.');
    }
    final normalization = _object(artifact['normalization'], 'normalization');
    final nFeatures = FrameQualityFeatures.names.length;
    final mean = _numbers(normalization['mean'], nFeatures, 'mean');
    final std = _numbers(normalization['std'], nFeatures, 'std');
    if (std.any((s) => s <= 0)) {
      throw const FormatException('Normalization std must be positive.');
    }
    final outputs = _object(artifact['outputs'], 'outputs');
    if (outputs['quality'] != 0 ||
        outputs['activation'] != 'sigmoid' ||
        !_sameList(outputs['defects'], supportedDefects)) {
      throw const FormatException('Unsupported frame quality output contract.');
    }
    final rawThresholds = _object(artifact['thresholds'], 'thresholds');
    final thresholds = <String, double>{};
    for (final defect in supportedDefects) {
      final threshold = _number(rawThresholds[defect], 'threshold $defect');
      if (threshold < 0 || threshold > 1) {
        throw FormatException('Threshold for $defect must be in [0, 1].');
      }
      thresholds[defect] = threshold;
    }
    final rawLayers = artifact['layers'];
    if (rawLayers is! List || rawLayers.isEmpty) {
      throw const FormatException('Model must contain dense layers.');
    }
    final layers = <_DenseLayer>[];
    var previousWidth = nFeatures;
    for (var i = 0; i < rawLayers.length; i++) {
      final raw = _object(rawLayers[i], 'layer $i');
      final last = i == rawLayers.length - 1;
      if (raw['activation'] != (last ? 'linear' : 'relu')) {
        throw FormatException('Unsupported activation in layer $i.');
      }
      final weights = raw['weights'];
      if (weights is! List || weights.isEmpty) {
        throw FormatException('Missing weights in layer $i.');
      }
      final rows = <List<double>>[
        for (var row = 0; row < weights.length; row++)
          _numbers(weights[row], previousWidth, 'layer $i weights $row'),
      ];
      final bias = _numbers(raw['bias'], rows.length, 'layer $i bias');
      if (last && rows.length != 1 + supportedDefects.length) {
        throw const FormatException('Incorrect model output dimensions.');
      }
      layers.add(_DenseLayer(rows, bias, !last));
      previousWidth = rows.length;
    }
    return SceneQualityModel._(
      mean,
      std,
      List.unmodifiable(layers),
      name: artifact['name'] as String,
      version: version,
      defects: supportedDefects,
      thresholds: Map.unmodifiable(thresholds),
    );
  }

  SceneQualityPrediction predictFrame(
    Uint8List rgb, {
    required int width,
    required int height,
  }) =>
      predict(FrameQualityFeatures.extract(rgb, width: width, height: height));

  SceneQualityPrediction predict(List<double> features) {
    if (features.length != _mean.length || features.any((f) => !f.isFinite)) {
      throw ArgumentError('Expected ${_mean.length} finite frame features.');
    }
    var z = <double>[
      for (var i = 0; i < features.length; i++)
        (features[i] - _mean[i]) / _std[i],
    ];
    if (z.any((value) => !value.isFinite)) {
      throw ArgumentError('Frame feature normalization overflowed.');
    }
    for (final layer in _layers) {
      final next = <double>[];
      for (var row = 0; row < layer.weights.length; row++) {
        var sum = 0.0;
        for (var col = 0; col < z.length; col++) {
          sum += z[col] * layer.weights[row][col];
        }
        sum += layer.bias[row];
        if (!sum.isFinite) {
          throw StateError('Scene quality model arithmetic overflowed.');
        }
        next.add(layer.relu && sum < 0 ? 0.0 : sum);
      }
      z = next;
    }
    final probabilities = <String, double>{
      for (var i = 0; i < defects.length; i++) defects[i]: _sigmoid(z[i + 1]),
    };
    return SceneQualityPrediction._(
      technicalQuality: _sigmoid(z[0]),
      defects: Map.unmodifiable(probabilities),
      flags: List.unmodifiable([
        for (final defect in defects)
          if (probabilities[defect]! >= thresholds[defect]!) defect,
      ]),
    );
  }

  static double _sigmoid(double z) {
    if (z >= 0) return 1.0 / (1.0 + math.exp(-z));
    final e = math.exp(z);
    return e / (1.0 + e);
  }

  static Map<String, dynamic> _object(Object? value, String name) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('$name must be an object.');
    }
    return value;
  }

  static bool _sameList(Object? value, List<String> expected) {
    if (value is! List || value.length != expected.length) return false;
    for (var i = 0; i < value.length; i++) {
      if (value[i] != expected[i]) return false;
    }
    return true;
  }

  static double _number(Object? value, String name) {
    if (value is! num || !value.isFinite) {
      throw FormatException('$name must be finite and numeric.');
    }
    return value.toDouble();
  }

  static List<double> _numbers(Object? value, int length, String name) {
    if (value is! List || value.length != length) {
      throw FormatException('$name must contain $length values.');
    }
    return List<double>.unmodifiable([
      for (final element in value) _number(element, name),
    ]);
  }
}

class _DenseLayer {
  const _DenseLayer(this.weights, this.bias, this.relu);

  final List<List<double>> weights;
  final List<double> bias;
  final bool relu;
}
