import 'dart:convert';
import 'dart:math' as math;

import '../analysis/domain/edit_plan.dart';
import '../plan/auto_editor.dart';
import '../plan/plan_ops.dart';
import '../projects/project.dart';
import '../render/media_analyzer.dart';
import 'quality_control.dart';

/// A verified stage has a validated artifact, not necessarily rendered media.
enum KartStageState { planned, verified, blocked }

class KartEvidence {
  const KartEvidence(this.skill, this.state, this.summary);
  final String skill;
  final KartStageState state;
  final String summary;

  Map<String, dynamic> toJson() => {
    'skill': skill,
    'state': state.name,
    'summary': summary,
  };
}

class KartProductionResult {
  const KartProductionResult({
    required this.plan,
    required this.document,
    required this.evidence,
    required this.findings,
    required this.metrics,
    required this.readyForRender,
  });
  final Map<String, dynamic> plan;
  final Map<String, dynamic> document;
  final List<KartEvidence> evidence;
  final List<QcFinding> findings;
  final Map<String, double> metrics;

  /// Plan preflight only. File existence and encoded output need RenderService.
  final bool readyForRender;
}

/// Local, deterministic first slice of KART production. Its executable skills
/// compile a brief into a storyboard, source ranges, motion, grade and captions.
/// Capture directions are explicitly proposals: this does not understand the
/// visual contents of footage, generate new media, or infer camera calibration.
abstract final class KartProduction {
  static bool accepts(String request) {
    final text = request.toLowerCase();
    return RegExp(r'reklama|storyboard|ssenariy').hasMatch(text) &&
        RegExp(r'yarat|tayyorla|tuz|rejalashtir').hasMatch(text);
  }

  static KartProductionResult build({
    required String request,
    required String title,
    List<ClipFacts> facts = const [],
    int defaultDurationSec = 30,
    String aspectRatio = '9:16',
    String resolution = '1080p',
    int fps = 30,
    Map<String, dynamic>? music,
  }) {
    if (request.trim().isEmpty || title.trim().isEmpty) {
      throw ArgumentError('Vazifa va mavzu bo‘sh bo‘lmasin.');
    }
    final seconds = RegExp(r'(-?\d+(?:[.,]\d+)?)\s*(?:soniya|sekund|sek\b|s\b)')
        .firstMatch(request.toLowerCase());
    final requestedSeconds = seconds == null
        ? defaultDurationSec.toDouble()
        : double.parse(seconds.group(1)!.replaceAll(',', '.'));
    if (!requestedSeconds.isFinite ||
        requestedSeconds < 5 ||
        requestedSeconds > 120 ||
        requestedSeconds != requestedSeconds.roundToDouble()) {
      throw ArgumentError('Hozircha 5–120 soniyalik reklama rejalashtiriladi.');
    }
    final target = requestedSeconds.toInt();
    final ids = <String>{};
    for (final f in facts) {
      if (f.id.isEmpty ||
          !ids.add(f.id) ||
          !f.durationSec.isFinite ||
          f.durationSec <= 0 ||
          f.sceneCuts.any((v) => !v.isFinite) ||
          f.silences.any(
            (s) =>
                !s.start.isFinite ||
                !s.end.isFinite ||
                s.start < 0 ||
                s.end <= s.start ||
                s.end > f.durationSec,
          )) {
        throw ArgumentError('Klip o‘lchovlari yaroqsiz: ${f.id}');
      }
    }
    final requestedRatio = RegExp(r'\b(9:16|16:9|1:1)\b').firstMatch(request);
    final ratio = requestedRatio?.group(1) ?? aspectRatio;
    final cinematic = RegExp(r'premium|cinematic|kino')
        .hasMatch(request.toLowerCase());
    final style = cinematic ? AutoStyle.kino : AutoStyle.dinamik;
    final topic = title.trim();
    var plan = facts.isEmpty
        ? _unfilledPlan(topic, target, ratio, resolution, fps)
        : AutoEditor.build(
            clips: [
              for (final f in facts)
                ClipFacts(
                  id: f.id,
                  durationSec: f.durationSec,
                  sceneCuts: [...f.sceneCuts]..sort(),
                  silences: f.silences,
                  hasAudio: f.hasAudio,
                ),
            ],
            targetSec: target,
            aspectRatio: ratio,
            resolution: resolution,
            title: topic,
            style: style,
          );
    // All-silent / too-short sources remain unfilled; never claim an edit.
    if ((plan['shots'] as List).isEmpty) {
      plan = _unfilledPlan(topic, target, ratio, resolution, fps);
    }
    _completeSmallRemainder(plan, facts, target);
    (plan['export'] as Map)['fps'] = fps;
    plan = PlanOps.setGrade(
      plan,
      ColorGrade.presets[cinematic ? 'kino' : 'jonli'],
    );
    final length = (plan['durationSec'] as num).toDouble();
    // Short, claim-free copy; its reading speed is measured below.
    if (length >= 3.5) {
      plan = PlanOps.addCaption(
        plan,
        startSec: 0,
        endSec: math.min(2, length / 2),
        text: 'Yaqindan ko‘ring',
      );
      plan = PlanOps.addCaption(
        plan,
        startSec: math.max(2, length - 2),
        endSec: length,
        text: 'Batafsil bog‘laning',
      );
    }
    if (music != null) {
      final safeMusic = jsonDecode(jsonEncode(music)) as Map<String, dynamic>;
      final track = MusicTrack.fromJson(safeMusic);
      safeMusic['volume'] = math.min(track.volume, 0.35);
      safeMusic['fadeInSec'] = math.min(0.5, length / 4);
      safeMusic['fadeOutSec'] = math.min(1.5, length / 4);
      plan = PlanOps.setMusic(plan, safeMusic);
    }
    final parsed = EditPlan.fromJson(plan);
    final storyboard = _storyboard(parsed, topic);
    final findings = QualityControl.check(
      parsed,
      clipDurations: {for (final f in facts) f.id: f.durationSec},
      knownClipIds: ids,
    );
    final coverage =
        parsed.shots
            .where((s) => ids.contains(s.sourceClipId))
            .fold<double>(0, (sum, s) => sum + s.duration) /
        length;
    final shortfall = math.max(0.0, target - length);
    final ready =
        coverage >= 0.999 &&
        shortfall <= 1 / fps &&
        !findings.any((f) => f.severity == Severity.problem);
    final metrics = <String, double>{
      'requestedDurationSec': target.toDouble(),
      'plannedDurationSec': length,
      'durationShortfallSec': shortfall,
      'mediaCoverage': coverage,
      'shotCount': parsed.shots.length.toDouble(),
      'maxCaptionCharsPerSecond': parsed.captions.fold<double>(
        0,
        (v, c) => math.max(v, c.text.length / (c.endSec - c.startSec)),
      ),
      'problemCount': findings
          .where((f) => f.severity == Severity.problem)
          .length
          .toDouble(),
    };
    final evidence = <KartEvidence>[
      KartEvidence(
        'creative_planner',
        KartStageState.verified,
        '$target s uchun hook → detal → namoyish → yakun tuzilmasi tayyor.',
      ),
      KartEvidence(
        'storyboard',
        KartStageState.verified,
        '${storyboard.length} kadrli storyboard, kamera va yorug‘lik ko‘rsatmalari yozildi. '
            'Bular suratga olish takliflari.',
      ),
      KartEvidence(
        'editor',
        coverage < 0.999 || shortfall > 1 / fps
            ? KartStageState.blocked
            : KartStageState.verified,
        coverage < 0.999
            ? 'Media yetishmaydi: storyboard tayyor, lavhalarni qo‘shing.'
            : shortfall > 1 / fps
            ? 'Manbadan ${length.toStringAsFixed(1)} s montaj tuzildi; '
                  '${shortfall.toStringAsFixed(1)} s material yetishmaydi.'
            : '${parsed.shots.length} kadr, ${length.toStringAsFixed(1)} s: '
                  'manba oraliqlari timeline’ga joylandi.',
      ),
      const KartEvidence(
        'colorist',
        KartStageState.verified,
        'Rang parametrlari rejaga yozildi; pikselga eksportda qo‘llanadi.',
      ),
      KartEvidence(
        'copywriter',
        parsed.captions.isEmpty
            ? KartStageState.blocked
            : KartStageState.verified,
        parsed.captions.isEmpty
            ? 'Matn uchun video juda qisqa.'
            : 'Hook va yakuniy chaqiriq timeline’ga qo‘shildi.',
      ),
      KartEvidence(
        'sound_designer',
        music == null ? KartStageState.blocked : KartStageState.verified,
        music == null
            ? 'Musiqa yaratilmagan. Kerakli audio faylni tanlang.'
            : 'Musiqa balansi va kirish/chiqish so‘nishi rejaga yozildi.',
      ),
      KartEvidence(
        'quality_control',
        KartStageState.verified,
        'Reja tekshirildi: ${metrics['problemCount']!.toInt()} muammo; '
            'media qamrovi ${(coverage * 100).round()}%. '
            'Kadr mazmuni va mahsulot o‘xshashligi baholanmagan.',
      ),
      KartEvidence(
        'render',
        ready ? KartStageState.planned : KartStageState.blocked,
        ready ? 'MP4 hali yaratilmagan. Eksport orqali render qiling.' : 'Yakuniy MP4 uchun yetishmayotgan media yoki reja muammolarini tuzating.',
      ),
    ];
    final document = <String, dynamic>{
      'schema': 'kart.production/1',
      'implementation': 'deterministic',
      'request': request,
      'brief': {
        'subject': topic,
        'durationSec': target,
        'aspectRatio': ratio,
        'style': style.name,
      },
      'storyboard': storyboard,
      'evidence': [for (final e in evidence) e.toJson()],
      'metrics': metrics,
      'planSignature': planSignature(plan),
      'mediaGenerated': false,
      'renderVerified': false,
    };
    plan['production'] = document;
    return KartProductionResult(
      plan: plan,
      document: document,
      evidence: evidence,
      findings: findings,
      metrics: metrics,
      readyForRender: ready,
    );
  }

  static Map<String, dynamic> _unfilledPlan(
    String topic,
    int target,
    String ratio,
    String resolution,
    int fps,
  ) {
    final opening = target >= 10 ? 2.0 : 1.0;
    final bounds = [
      0.0,
      opening,
      for (var i = 1; i <= 4; i++)
        ((opening + (target - opening) * i / 4) * 100).round() / 100,
    ];
    return {
      'schemaVersion': 1,
      'title': topic,
      'summary': 'Storyboard — media hali biriktirilmagan.',
      'durationSec': target,
      'aspectRatio': ratio,
      'shots': [
        for (var i = 0; i < 5; i++)
          {
            'id': 's${i + 1}',
            'startSec': bounds[i],
            'endSec': bounds[i + 1],
            'description': '$topic · ${_purpose(i, 5)} (reja)',
            'mediaSlotId': 'm${i + 1}',
          },
      ],
      'mediaSlots': [
        for (var i = 0; i < 5; i++)
          {
            'id': 'm${i + 1}',
            'kind': 'video',
            'description': '$topic · ${_purpose(i, 5)}',
            'requiredDurationSec': bounds[i + 1] - bounds[i],
          },
      ],
      'captions': <Map<String, dynamic>>[],
      'audioTracks': <Map<String, dynamic>>[],
      'export': {'resolution': resolution, 'fps': fps},
    };
  }

  // AutoEditor avoids tiny final shots. Consume remaining source frames on
  // the last shot when safe, rather than silently shortening the brief.
  static void _completeSmallRemainder(
    Map<String, dynamic> plan,
    List<ClipFacts> facts,
    int target,
  ) {
    final gap = target - (plan['durationSec'] as num).toDouble();
    if (gap <= 0 || gap >= AutoEditor.minPiece) return;
    final shots = plan['shots'] as List;
    final last = shots.last as Map<String, dynamic>;
    final id = last['sourceClipId'];
    final source = facts.where((f) => f.id == id).firstOrNull;
    if (source == null) return;
    final out = (last['sourceOut'] as num).toDouble();
    final end = ((out + gap) * 100).round() / 100;
    if (end > source.durationSec ||
        source.silences.any((s) => s.start < end && s.end > out) ||
        shots
            .take(shots.length - 1)
            .any(
              (s) =>
                  s['sourceClipId'] == id &&
                  (s['sourceIn'] as num) < end &&
                  (s['sourceOut'] as num) > out,
            )) {
      return;
    }
    last['sourceOut'] = end;
    last['endSec'] = target.toDouble();
    plan['durationSec'] = target.toDouble();
  }

  static String _purpose(int i, int count) => i == 0
      ? 'hook'
      : i == count - 1
      ? 'yakun'
      : i.isOdd
      ? 'detal'
      : 'namoyish';

  static List<Map<String, dynamic>> _storyboard(
    EditPlan plan,
    String topic,
  ) => [
    for (final (i, s) in plan.shots.indexed)
      {
        'shotId': s.id,
        'startSec': s.startSec,
        'endSec': s.endSec,
        'purpose': _purpose(i, plan.shots.length),
        'sourceClipId': s.sourceClipId,
        'captureDirection': {
          'composition': i.isOdd
              ? 'Yaqin detal, fon sodda'
              : 'Mahsulot to‘liq, kadr chetlarida bo‘sh joy',
          'lensSuggestionMm': i.isOdd ? 85 : 35,
          'lighting': 'Yumshoq yon yorug‘lik; rang va shaklni saqlash',
          'movement': i == 0 ? 'Sekin yaqinlashish' : 'Barqaror kadr',
          'status': 'proposed',
        },
        'generationInstruction':
            '$topic: ${_purpose(i, plan.shots.length)}. '
            '${s.duration.toStringAsFixed(2)} s, ${plan.aspectRatio}. '
            'Mahsulot reference kerak; shakl, rang va naqshni tekshiring. '
            'Matn va logotip alohida qatlamda. Bu topshiriq hali bajarilmagan.',
      },
  ];
}
