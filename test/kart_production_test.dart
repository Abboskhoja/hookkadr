import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/director/kart_production.dart';
import 'package:hookkadr/features/render/media_analyzer.dart';
import 'package:hookkadr/features/render/render_plan.dart';
import 'package:hookkadr/features/projects/project.dart';

void main() {
  KartProductionResult build({List<ClipFacts> facts = const []}) =>
      KartProduction.build(
        request: 'Menga 30 soniyalik premium avtomobil reklamasi yarat.',
        title: 'Avtomobil',
        facts: facts,
      );

  test('brief becomes serializable storyboard, never fabricated media', () {
    final result = build();
    final plan = EditPlan.fromJson(result.plan);
    expect(plan.durationSec, 30);
    expect(plan.shots, hasLength(5));
    expect(plan.mediaSlots, hasLength(5));
    expect(plan.shots.every((s) => s.sourceClipId == null), isTrue);
    expect(result.readyForRender, isFalse);
    final document = jsonDecode(jsonEncode(result.document)) as Map;
    expect(document['schema'], 'kart.production/1');
    expect(
      (document['storyboard'] as List).first['generationInstruction'],
      contains('Avtomobil'),
    );
    expect(
      result.evidence.where((e) => e.skill == 'render').single.state,
      KartStageState.blocked,
    );
    expect(result.metrics['mediaCoverage'], 0);
  });

  test(
    'measured source ranges, grade and captions reach real render graph',
    () {
      final result = build(
        facts: [
          const ClipFacts(id: 'car', durationSec: 40, sceneCuts: [10, 20, 30]),
        ],
      );
      final plan = EditPlan.fromJson(result.plan);
      expect(
        result.readyForRender,
        isTrue,
        reason: '${result.metrics} ${result.findings.map((f) => f.code)}',
      );
      expect(plan.durationSec, closeTo(30, 0.5));
      expect(plan.grade, isNotNull);
      expect(plan.captions, hasLength(2));
      for (final shot in plan.shots) {
        expect(shot.sourceClipId, 'car');
        expect(shot.sourceOut, lessThanOrEqualTo(40));
      }
      final built = buildRenderArgs(
        plan: plan,
        clips: const [ProjectClip(id: 'car', path: '/car.mp4', name: 'car')],
        hasAudio: const {},
        fontPath: '/font.ttf',
        textDir: '/text',
        outputPath: '/ad.mp4',
        videoEncoder: 'h264_videotoolbox',
        resolution: '720p',
      );
      final graph = built.args.join(' ');
      expect(graph, contains('lutyuv'));
      expect(graph, contains('drawtext'));
      expect(graph, contains('trim=start='));
      expect(graph, contains('zoompan'));
      expect(
        result.evidence.where((e) => e.skill == 'render').single.state,
        KartStageState.planned,
      );
      expect(result.metrics['mediaCoverage'], 1);
    },
  );

  test('insufficient footage is disclosed without invented filler', () {
    final result = build(facts: [const ClipFacts(id: 'car', durationSec: 4)]);
    final plan = EditPlan.fromJson(result.plan);
    expect(plan.durationSec, lessThanOrEqualTo(4));
    expect(result.readyForRender, isFalse);
    expect(result.metrics['durationShortfallSec'], greaterThan(25));
    expect(
      result.evidence.any(
        (e) => e.skill == 'editor' && e.state == KartStageState.blocked,
      ),
      isTrue,
    );
  });

  test('bad facts and unsupported requested duration are rejected', () {
    expect(
      () => build(
        facts: [const ClipFacts(id: 'x', durationSec: double.nan)],
      ),
      throwsArgumentError,
    );
    expect(
      () => build(
        facts: [
          const ClipFacts(id: 'x', durationSec: 5),
          const ClipFacts(id: 'x', durationSec: 5),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => KartProduction.build(
        request: '500 soniyalik reklama yarat',
        title: 'Test',
      ),
      throwsArgumentError,
    );
    for (final duration in ['-5', '2.5', '10,5']) {
      expect(
        () => KartProduction.build(
          request: '$duration soniyalik reklama yarat',
          title: 'Test',
        ),
        throwsArgumentError,
      );
    }
  });

  test('caller data remains unchanged and evidence is reproducible', () {
    final music = <String, dynamic>{
      'path': '/music.m4a',
      'name': 'music',
      'volume': 0.9,
    };
    final before = jsonEncode(music);
    final result = KartProduction.build(
      request: '10 soniyalik reklama yarat',
      title: 'Test',
      music: music,
      facts: [const ClipFacts(id: 'car', durationSec: 20)],
    );
    expect(jsonEncode(music), before);
    final plan = EditPlan.fromJson(result.plan);
    expect(plan.music!.volume, lessThanOrEqualTo(0.35));
    final bare = Map<String, dynamic>.from(result.plan)..remove('production');
    expect(result.document['planSignature'], planSignature(bare));
  });
}
