import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/vision/frame_quality_features.dart';
import 'package:hookkadr/features/vision/scene_quality_model.dart';

/// Deliberately hand-written weights, used only to check arithmetic and input
/// validation independently of the trained model's Python-generated goldens.
Map<String, dynamic> _arithmeticArtifact() => {
  'schema': SceneQualityModel.artifactSchema,
  'name': 'scene_quality',
  'version': 'test-handweights',
  'task': 'frame_quality',
  'input': {
    'featureVersion': 1,
    'features': [...FrameQualityFeatures.names],
    'analysisFilter': SceneQualityModel.supportedAnalysisFilter,
    'analysisLongSide': 384,
  },
  'normalization': {
    'mean': [1.0, ...List<double>.filled(14, 0)],
    'std': [2.0, ...List<double>.filled(14, 1)],
  },
  'layers': [
    {
      'weights': [
        [2.0, -1.0, ...List<double>.filled(13, 0)],
        [-1.0, 2.0, ...List<double>.filled(13, 0)],
      ],
      'bias': [0.5, -10.0],
      'activation': 'relu',
    },
    {
      'weights': [
        [2.0, 3.0],
        [0.0, 1.0],
        [-2.0, 0.0],
        [1.0, 0.0],
        [0.0, 0.0],
        [0.0, 0.0],
      ],
      'bias': [0.0, 0.0, 1.0, 0.0, -1000.0, 1000.0],
      'activation': 'linear',
    },
  ],
  'outputs': {
    'quality': 0,
    'defects': [...SceneQualityModel.supportedDefects],
    'activation': 'sigmoid',
  },
  'thresholds': {
    for (final defect in SceneQualityModel.supportedDefects) defect: 0.5,
  },
};

Uint8List _flat(int r, int g, int b) => Uint8List.fromList([
  for (var i = 0; i < 144; i++) ...[r, g, b],
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('versioned technical frame features', () {
    test('flat grey has zero detail, noise, color and entropy', () {
      final features = FrameQualityFeatures.extract(
        _flat(128, 128, 128),
        width: 12,
        height: 12,
      );
      expect(features.length, 15);
      for (final i in [0, 1, 2, 3, 5, 9, 10, 11, 12, 13, 14]) {
        expect(features[i], 0, reason: FrameQualityFeatures.names[i]);
      }
      for (final i in [4, 6, 7, 8]) {
        expect(features[i], 128 / 255);
      }
    });

    test('histogram rounds exact half luma upward; mean remains unrounded', () {
      final features = FrameQualityFeatures.extract(
        _flat(0, 0, 250),
        width: 12,
        height: 12,
      );
      expect(features[4], 28.5 / 255);
      for (final i in [6, 7, 8]) {
        expect(features[i], 29 / 255);
      }
      expect(features[12], 0.75);
      expect(features[13], 1);
    });

    test('shadow and highlight cutoffs match Python strictly', () {
      for (final code in [0, 19, 20, 235, 236, 255]) {
        final features = FrameQualityFeatures.extract(
          _flat(code, code, code),
          width: 12,
          height: 12,
        );
        expect(features[9], code < 20 ? 1.0 : 0.0);
        expect(features[10], code > 235 ? 1.0 : 0.0);
        expect(features.every((f) => f.isFinite), isTrue);
      }
    });

    test('rejects small frames, truncation and extra channels', () {
      for (final size in [(11, 12), (12, 11), (0, 12), (-1, 12)]) {
        expect(
          () => FrameQualityFeatures.extract(
            Uint8List(0),
            width: size.$1,
            height: size.$2,
          ),
          throwsArgumentError,
        );
      }
      for (final length in [0, 431, 433, 576]) {
        expect(
          () => FrameQualityFeatures.extract(
            Uint8List(length),
            width: 12,
            height: 12,
          ),
          throwsArgumentError,
        );
      }
    });
  });

  group('MLP inference contract', () {
    test('normalizes, applies hidden ReLU, stable sigmoid and thresholds', () {
      final model = SceneQualityModel.fromJson(_arithmeticArtifact());
      final result = model.predict([5, 3, ...List<double>.filled(13, 0)]);
      expect(result.technicalQuality, closeTo(1 / (1 + math.exp(-3)), 1e-15));
      expect(result.defects['blurry'], 0.5);
      expect(result.defects['dark'], closeTo(1 / (1 + math.exp(2)), 1e-15));
      expect(
        result.defects['overexposed'],
        closeTo(1 / (1 + math.exp(-1.5)), 1e-15),
      );
      expect(result.defects['noisy'], 0);
      expect(result.defects['low_contrast'], 1);
      expect(result.flags, ['blurry', 'overexposed', 'low_contrast']);
      expect(SceneQualityPrediction.scoreLabel, 'Technical frame quality');
      expect(() => result.defects['dark'] = 0, throwsUnsupportedError);
      expect(() => result.flags.clear(), throwsUnsupportedError);
    });

    test('asset loader reads and validates the supplied bundle', () async {
      final model = await SceneQualityModel.loadAsset(
        bundle: _ModelBundle(jsonEncode(_arithmeticArtifact())),
      );
      expect(model.version, 'test-handweights');
      expect(model.analysisFilter, SceneQualityModel.supportedAnalysisFilter);
    });

    final invalidArtifacts = <String, void Function(Map<String, dynamic>)>{
      'schema': (a) => a['schema'] = 'hookkadr.model/2',
      'task': (a) => a['task'] = 'creative_quality',
      'name': (a) => a['name'] = 'other_model',
      'version': (a) => a['version'] = '',
      'feature version': (a) => a['input']['featureVersion'] = 2,
      'feature order': (a) =>
          a['input']['features'] = FrameQualityFeatures.names.reversed.toList(),
      'analysis filter': (a) => a['input']['analysisFilter'] = 'scale=160:-2',
      'analysis size': (a) => a['input']['analysisLongSide'] = 512,
      'missing mean': (a) => a['normalization'].remove('mean'),
      'short std': (a) => a['normalization']['std'] = [1.0],
      'zero std': (a) => a['normalization']['std'][0] = 0.0,
      'negative std': (a) => a['normalization']['std'][0] = -1.0,
      'nonfinite mean': (a) => a['normalization']['mean'][0] = double.nan,
      'nonfinite std': (a) => a['normalization']['std'][0] = double.infinity,
      'missing layers': (a) => a['layers'] = [],
      'short weights': (a) => a['layers'][0]['weights'][0] = [1.0],
      'nonfinite weights': (a) =>
          a['layers'][0]['weights'][0][0] = double.infinity,
      'nonfinite bias': (a) => a['layers'][0]['bias'][0] = double.nan,
      'wrong bias length': (a) => a['layers'][0]['bias'] = [0.0],
      'unknown activation': (a) => a['layers'][0]['activation'] = 'gelu',
      'nonlinear output': (a) => a['layers'][1]['activation'] = 'relu',
      'wrong output width': (a) {
        (a['layers'][1]['weights'] as List).removeLast();
        (a['layers'][1]['bias'] as List).removeLast();
      },
      'wrong quality index': (a) => a['outputs']['quality'] = 1,
      'output activation': (a) => a['outputs']['activation'] = 'softmax',
      'unknown defect': (a) => a['outputs']['defects'][0] = 'creative',
      'missing threshold': (a) => a['thresholds'].remove('blurry'),
      'nonfinite threshold': (a) => a['thresholds']['dark'] = double.nan,
      'negative threshold': (a) => a['thresholds']['dark'] = -0.1,
      'excessive threshold': (a) => a['thresholds']['dark'] = 1.1,
    };
    for (final entry in invalidArtifacts.entries) {
      test('rejects artifact with ${entry.key}', () {
        final artifact = _arithmeticArtifact();
        entry.value(artifact);
        expect(
          () => SceneQualityModel.fromJson(artifact),
          throwsFormatException,
        );
      });
    }

    test('rejects malformed JSON or a non-object root', () {
      for (final text in ['broken', '[]', 'null', '1']) {
        expect(
          () => SceneQualityModel.fromJsonString(text),
          throwsFormatException,
        );
      }
    });

    test('rejects wrong feature count and nonfinite features', () {
      final model = SceneQualityModel.fromJson(_arithmeticArtifact());
      for (final features in <List<double>>[
        [],
        List.filled(14, 0),
        List.filled(16, 0),
        [double.nan, ...List.filled(14, 0)],
        [double.infinity, ...List.filled(14, 0)],
      ]) {
        expect(() => model.predict(features), throwsArgumentError);
      }
    });

    test(
      'rejects arithmetic overflow instead of returning an invented score',
      () {
        final normalizationOverflow = _arithmeticArtifact();
        normalizationOverflow['normalization']['std'][0] = 1e-320;
        final normalizer = SceneQualityModel.fromJson(normalizationOverflow);
        expect(
          () => normalizer.predict([2, ...List.filled(14, 0)]),
          throwsArgumentError,
        );

        final layerOverflow = _arithmeticArtifact();
        layerOverflow['layers'][0]['weights'][0][0] = 1e308;
        final model = SceneQualityModel.fromJson(layerOverflow);
        expect(
          () => model.predict([1e308, ...List.filled(14, 0)]),
          throwsStateError,
        );
      },
    );
  });

  group('Python to Dart production parity', () {
    final artifactFile = File(SceneQualityModel.assetPath);
    final goldenFile = File('test/fixtures/scene_quality_golden.json');
    final artifactBytes = artifactFile.readAsBytesSync();
    final model = SceneQualityModel.fromJsonString(utf8.decode(artifactBytes));
    final golden =
        jsonDecode(goldenFile.readAsStringSync()) as Map<String, dynamic>;

    test('goldens identify the exact deployed artifact', () {
      expect(golden['model'], model.name);
      expect(golden['version'], model.version);
      expect(
        golden['artifactSha256'],
        sha256.convert(artifactBytes).toString(),
      );
      expect(golden['frames'], hasLength(7));
    });

    for (final raw in golden['frames'] as List) {
      final frame = raw as Map<String, dynamic>;
      test('features, quality and all defects: ${frame['name']}', () {
        final rgb = base64Decode(frame['rgbBase64'] as String);
        final features = FrameQualityFeatures.extract(
          rgb,
          width: frame['width'] as int,
          height: frame['height'] as int,
        );
        final expectedFeatures = frame['features'] as List;
        expect(features.length, expectedFeatures.length);
        for (var i = 0; i < features.length; i++) {
          expect(
            features[i],
            closeTo(expectedFeatures[i] as num, 1e-9),
            reason: FrameQualityFeatures.names[i],
          );
        }
        final prediction = model.predictFrame(
          rgb,
          width: frame['width'] as int,
          height: frame['height'] as int,
        );
        expect(
          prediction.technicalQuality,
          closeTo(frame['quality'] as num, 1e-9),
        );
        final defects = frame['defects'] as Map<String, dynamic>;
        expect(prediction.defects.keys, defects.keys);
        for (final defect in defects.keys) {
          expect(
            prediction.defects[defect],
            closeTo(defects[defect] as num, 1e-9),
            reason: defect,
          );
        }
        expect(prediction.flags, [
          for (final defect in model.defects)
            if ((defects[defect] as num) >= model.thresholds[defect]!) defect,
        ]);
      });
    }
  });
}

class _ModelBundle extends CachingAssetBundle {
  _ModelBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async {
    expect(key, SceneQualityModel.assetPath);
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  }
}
