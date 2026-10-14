import '../ai/ai_clients.dart';
import '../analysis/domain/edit_plan.dart';
import '../montage/application/montage_service.dart';
import '../plan/auto_editor.dart';
import '../plan/command_agent.dart';
import '../plan/plan_ops.dart';
import '../projects/project.dart';
import '../render/media_analyzer.dart';
import '../vision/scene_quality_scanner.dart';
import 'capability_registry.dart';
import 'hook_engine.dart';
import 'kart_production.dart';
import 'quality_control.dart';

/// What the user is asking the Director for.
enum DirectorGoal {
  edit,
  review,
  hooks,
  remontage,
  generateImage,
  generateVideo,
  production,
}

enum StepStatus { done, blocked, failed }

/// One executed (or refused) step; shown to the user as it is.
class DirectorStep {
  const DirectorStep(this.status, this.label, {this.tool = ''});
  final StepStatus status;
  final String label;

  /// Which tool did it ("agent", "hook_engine", "qc", "auto_editor").
  final String tool;
}

class DirectorReport {
  const DirectorReport({
    required this.goal,
    required this.plan,
    required this.steps,
    this.findings = const [],
    this.wantsUndo = false,
    this.changedPlan = false,
    this.handledLocally = false,
  });

  final DirectorGoal goal;

  /// The plan after this request (same as the input when nothing changed).
  final Map<String, dynamic> plan;
  final List<DirectorStep> steps;

  /// Quality-control findings relevant to the result.
  final List<QcFinding> findings;
  final bool wantsUndo;
  final bool changedPlan;
  final bool handledLocally;

  List<String> get done => [
    for (final s in steps)
      if (s.status == StepStatus.done) s.label,
  ];
  List<String> get blocked => [
    for (final s in steps)
      if (s.status != StepStatus.done) s.label,
  ];
}

/// Kadr AI Director — the project's brain, in Dart, offline-first.
///
/// Understand → Plan → Choose tools → Execute → Validate → Report.
/// It decides what the user wants, picks the tool that really does it,
/// runs it on the real plan, re-validates the result and runs quality
/// control. It never reports a step as done unless the plan changed, and
/// when a capability needs an AI provider that is not connected it says so.
class KadrDirector {
  KadrDirector({
    this.connected = const {},
    this.analyzer,
    this.qualityAnalyzer,
    this.agent = const CommandAgent(),
  });

  final Set<ProviderKind> connected;
  final ClipAnalyzer? analyzer;
  final TechnicalQualityAnalyzer? qualityAnalyzer;
  final CommandAgent agent;

  // ------------------------------------------------------------ understand

  static DirectorGoal understand(String message) {
    final t = message.toLowerCase().replaceAll(RegExp('[’‘ʻʼ`´]'), "'");
    if (RegExp(
      r'(rasm|surat|tasvir)\w*.*(yarat|chiz|generats)|(yarat|chiz|generats)\w*.*(rasm|surat|tasvir)',
    ).hasMatch(t)) {
      return DirectorGoal.generateImage;
    }
    if (RegExp(r'(ai|ii)[ -]?video|generats\w*.*video|video.*generats|\bveo\b')
        .hasMatch(t)) {
      return DirectorGoal.generateVideo;
    }
    if (KartProduction.accepts(t)) return DirectorGoal.production;
    if (RegExp(
      r'hook(lar)?\s*(yoz|taklif|variant|top|qo.y|ber)|\d\s*-?\s*(?:chi|nchi)?\s*hook|boshlanish\w*\s*(yoz|variant|taklif)|hooklar',
    ).hasMatch(t)) {
      return DirectorGoal.hooks;
    }
    if (RegExp(
      r'tekshir|sifat\w*\s*(baho|tekshir)|xato\w*\s*top|nuqson|baholab ber|\bqc\b|tahlil qil',
    ).hasMatch(t)) {
      return DirectorGoal.review;
    }
    if (RegExp(
      r'(qayta|qaytadan|boshidan|yangidan)\s*montaj|avto.?montaj\s*qil',
    ).hasMatch(t)) {
      return DirectorGoal.remontage;
    }
    return DirectorGoal.edit;
  }

  // --------------------------------------------------------------- execute

  Future<DirectorReport> handle(
    String message, {
    required Map<String, dynamic> plan,
    List<ProjectClip> clips = const [],
    double playheadSec = 0,
    String? selectedShotId,
    bool autoReview = true,
  }) async {
    final goal = understand(message);
    switch (goal) {
      case DirectorGoal.production:
        return _production(message, plan, clips);
      case DirectorGoal.generateImage:
        return _generation(goal, plan, AiTask.imageGeneration);
      case DirectorGoal.generateVideo:
        return _generation(goal, plan, AiTask.videoGeneration);
      case DirectorGoal.review:
        return _review(plan, clips);
      case DirectorGoal.hooks:
        return _hooks(message, plan);
      case DirectorGoal.remontage:
        return _remontage(message, plan, clips);
      case DirectorGoal.edit:
        return _edit(
          message,
          plan,
          clips,
          playheadSec,
          selectedShotId,
          autoReview,
        );
    }
  }

  Future<DirectorReport> _production(
    String message,
    Map<String, dynamic> plan,
    List<ProjectClip> clips,
  ) async {
    final steps = <DirectorStep>[];
    try {
      final current = EditPlan.fromJson(plan);
      final facts = <ClipFacts>[];
      for (final clip in clips) {
        if (clip.isImage) {
          steps.add(
            DirectorStep(
              StepStatus.blocked,
              '${clip.name}: bu oqim hozir video kliplarni montaj qiladi.',
              tool: 'media_analyzer',
            ),
          );
          continue;
        }
        try {
          final a = analyzer;
          if (a == null) throw StateError('analyzer unavailable');
          final measured = await a.analyze(clip.id, clip.path);
          if (measured.id != clip.id ||
              !measured.durationSec.isFinite ||
              measured.durationSec <= 0) {
            throw StateError('invalid media measurement');
          }
          facts.add(measured);
        } catch (_) {
          steps.add(
            DirectorStep(
              StepStatus.blocked,
              '${clip.name}: klipni o‘lchab bo‘lmadi; qayta import qiling.',
              tool: 'media_analyzer',
            ),
          );
        }
      }
      final subject = RegExp(
        r'^(?:menga\s+)?(?:\d+\s*(?:soniyalik|sekundlik)\s+)?(.+?)\s+reklama',
        caseSensitive: false,
      ).firstMatch(message.trim())?.group(1);
      final result = KartProduction.build(
        request: message,
        title: subject != null && subject.length <= 80
            ? subject
            : current.title,
        facts: facts,
        defaultDurationSec: current.durationSec.round().clamp(5, 120),
        aspectRatio: current.aspectRatio,
        resolution: current.export.resolution,
        fps: current.export.fps,
        music: plan['music'] as Map<String, dynamic>?,
      );
      steps.addAll([
        for (final e in result.evidence)
          DirectorStep(
            e.state == KartStageState.verified
                ? StepStatus.done
                : StepStatus.blocked,
            e.summary,
            tool: e.skill,
          ),
      ]);
      return DirectorReport(
        goal: DirectorGoal.production,
        plan: result.plan,
        steps: steps,
        findings: result.findings,
        changedPlan: true,
      );
    } on Exception catch (e) {
      return DirectorReport(
        goal: DirectorGoal.production,
        plan: plan,
        steps: [
          DirectorStep(
            StepStatus.failed,
            'Reja yaratilmagan: $e',
            tool: 'kart_production',
          ),
        ],
      );
    } on ArgumentError catch (e) {
      return DirectorReport(
        goal: DirectorGoal.production,
        plan: plan,
        steps: [
          DirectorStep(
            StepStatus.failed,
            'Reja yaratilmagan: ${e.message}',
            tool: 'kart_production',
          ),
        ],
      );
    }
  }

  Future<DirectorReport> _edit(
    String message,
    Map<String, dynamic> plan,
    List<ProjectClip> clips,
    double playhead,
    String? selected,
    bool autoReview,
  ) async {
    final r = agent.run(
      message,
      plan,
      playheadSec: playhead,
      selectedShotId: selected,
    );
    final steps = <DirectorStep>[
      for (final d in r.done) DirectorStep(StepStatus.done, d, tool: 'agent'),
      for (final u in r.unhandled)
        DirectorStep(StepStatus.blocked, u, tool: 'agent'),
    ];
    var findings = const <QcFinding>[];
    if (r.changed && autoReview) {
      // Validate stage: only surface what needs attention after the edit.
      findings = _qc(
        r.plan,
        clips,
      ).where((f) => f.severity != Severity.info).toList();
    }
    return DirectorReport(
      goal: DirectorGoal.edit,
      plan: r.plan,
      steps: steps,
      findings: findings,
      wantsUndo: r.wantsUndo,
      changedPlan: r.changed,
      handledLocally: r.understoodAnything,
    );
  }

  Future<DirectorReport> _review(
    Map<String, dynamic> plan,
    List<ProjectClip> clips,
  ) async {
    final findings = _qc(plan, clips);
    final steps = findings.isEmpty
        ? [
            DirectorStep(
              StepStatus.done,
              'Tekshiruv: jiddiy muammo topilmadi',
              tool: 'qc',
            ),
          ]
        : [
            DirectorStep(
              StepStatus.done,
              'Tekshiruv: ${findings.length} ta eslatma '
              '(${findings.where((f) => f.severity == Severity.problem).length} ta muammo)',
              tool: 'qc',
            ),
          ];
    final vision = qualityAnalyzer;
    if (vision != null) {
      for (final clip in clips.take(4)) {
        try {
          final report = await vision.scan(clip.path);
          const labels = {
            'blurry': 'xira',
            'dark': 'qorong‘i',
            'overexposed': 'ortiqcha yorug‘',
            'noisy': 'shovqinli',
            'low_contrast': 'past kontrast',
          };
          final flags = report.flags.entries
              .map(
                (e) =>
                    '${labels[e.key] ?? e.key}: ${e.value}/${report.samples}',
              )
              .join(', ');
          steps.add(
            DirectorStep(
              StepStatus.done,
              '${clip.name}: ${report.samples} namuna; texnik sifat '
              '${(report.meanQuality * 100).round()}/100 (model ${report.modelVersion}). '
              '${flags.isEmpty ? 'Namunalarda nuqson belgilanmadi.' : flags}. '
              'Bu dastlabki 24 soniyadan namuna, estetik baho emas.',
              tool: 'scene_quality',
            ),
          );
        } catch (_) {
          steps.add(
            DirectorStep(
              StepStatus.blocked,
              '${clip.name}: texnik sifat o‘lchanmadi.',
              tool: 'scene_quality',
            ),
          );
        }
      }
      if (clips.length > 4) {
        steps.add(
          const DirectorStep(
            StepStatus.blocked,
            'Hozir dastlabki 4 ta media tekshirildi; qolganlari baholanmagan.',
            tool: 'scene_quality',
          ),
        );
      }
    }
    return DirectorReport(
      goal: DirectorGoal.review,
      plan: plan,
      steps: steps,
      findings: findings,
    );
  }

  DirectorReport _hooks(String message, Map<String, dynamic> plan) {
    final p = EditPlan.fromJson(plan);
    final topic = '${p.title} ${p.summary}';
    final variants = HookEngine.generate(
      topic: p.title,
      kind: HookEngine.kindOf(topic),
    );
    final pick = RegExp(r'(\d)\s*-?\s*(?:chi|nchi)?\s*hook')
        .firstMatch(message.toLowerCase());
    final wantsList =
        RegExp(r'variant|taklif|ro.yxat|hooklar|ber\b')
            .hasMatch(message.toLowerCase()) &&
        pick == null;
    final steps = <DirectorStep>[];
    if (wantsList) {
      for (final (i, v) in variants.indexed) {
        steps.add(
          DirectorStep(
            StepStatus.done,
            '${i + 1}. “${v.text}” — ${v.visual}',
            tool: 'hook_engine',
          ),
        );
      }
      steps.add(
        const DirectorStep(
          StepStatus.done,
          'Qo‘llash uchun: “2-hookni qo‘y”',
          tool: 'hook_engine',
        ),
      );
      return DirectorReport(goal: DirectorGoal.hooks, plan: plan, steps: steps);
    }
    final idx = pick == null
        ? 0
        : (int.parse(pick.group(1)!) - 1).clamp(0, variants.length - 1);
    final v = variants[idx];
    var next = PlanOps.setFormat(plan);
    // Replace an existing opening caption, never stack two on top.
    final caps = (next['captions'] as List).cast<Map<String, dynamic>>();
    next['captions'] = [
      for (final c in caps)
        if ((c['startSec'] as num) >= 1.0) c,
    ];
    final end = (p.durationSec < 2.5 ? p.durationSec : 2.5).toDouble();
    next = PlanOps.addCaption(next, startSec: 0, endSec: end, text: v.text);
    next = PlanOps.setMotion(next, p.shots.first.id, 'punchIn');
    EditPlan.fromJson(next);
    steps.add(
      DirectorStep(
        StepStatus.done,
        'Hook qo‘yildi (${idx + 1}-variant): “${v.text}”. '
        'Birinchi kadr: ${v.visual}',
        tool: 'hook_engine',
      ),
    );
    return DirectorReport(
      goal: DirectorGoal.hooks,
      plan: next,
      steps: steps,
      changedPlan: true,
    );
  }

  Future<DirectorReport> _remontage(
    String message,
    Map<String, dynamic> plan,
    List<ProjectClip> clips,
  ) async {
    DirectorReport fail(String why) => DirectorReport(
      goal: DirectorGoal.remontage,
      plan: plan,
      steps: [DirectorStep(StepStatus.failed, why, tool: 'auto_editor')],
    );
    final a = analyzer;
    final usable = [
      for (final c in clips)
        if (c.durationSec != null || c.isImage) c,
    ];
    if (a == null || usable.isEmpty) {
      return fail('Qayta montaj uchun loyihada klip kerak.');
    }
    final old = EditPlan.fromJson(plan);
    final t = message.toLowerCase();
    final style = RegExp(r'kino|cinematic').hasMatch(t)
        ? AutoStyle.kino
        : RegExp(r'iliq').hasMatch(t)
        ? AutoStyle.iliq
        : AutoStyle.dinamik;
    final secMatch = RegExp(r'(\d+)\s*(?:soniya|sekund|s\b)').firstMatch(t);
    final target = secMatch == null
        ? old.durationSec.round().clamp(5, 120)
        : int.parse(secMatch.group(1)!).clamp(5, 120);

    final facts = <ClipFacts>[];
    for (final c in usable) {
      if (c.isImage) {
        facts.add(ClipFacts(id: c.id, durationSec: 3));
        continue;
      }
      try {
        facts.add(await a.analyze(c.id, c.path));
      } catch (_) {
        facts.add(ClipFacts(id: c.id, durationSec: c.durationSec ?? 0));
      }
    }
    final built = AutoEditor.build(
      clips: [
        for (final f in facts)
          if (f.durationSec > 0) f,
      ],
      targetSec: target,
      aspectRatio: old.aspectRatio,
      resolution: old.export.resolution,
      title: old.title,
      style: style,
    );
    if ((built['shots'] as List).isEmpty) {
      return fail('Kliplardan ishlatsa bo‘ladigan qism topilmadi.');
    }
    (built['export'] as Map<String, dynamic>)['fps'] = old.export.fps;
    if (plan['music'] != null) built['music'] = plan['music'];
    if (plan['logo'] != null) built['logo'] = plan['logo'];
    final p = EditPlan.fromJson(built);
    final dropped = old.captions.length;
    return DirectorReport(
      goal: DirectorGoal.remontage,
      plan: built,
      steps: [
        DirectorStep(
          StepStatus.done,
          'Qayta montaj (${style.name}): ${p.shots.length} kadr, '
          '${p.durationSec.toStringAsFixed(1)} s; musiqa va logotip saqlandi',
          tool: 'auto_editor',
        ),
        if (dropped > 0)
          DirectorStep(
            StepStatus.blocked,
            'Eski $dropped ta matn vaqti mos kelmagani uchun olib tashlandi — '
            '“hook yoz” yoki matn qayta qo‘shing',
            tool: 'auto_editor',
          ),
      ],
      changedPlan: true,
    );
  }

  DirectorReport _generation(
    DirectorGoal goal,
    Map<String, dynamic> plan,
    AiTask task,
  ) {
    final cap = CapabilityRegistry.best(task, connected);
    final label = task == AiTask.imageGeneration ? 'Rasm' : 'AI video';
    final step = cap == null
        ? DirectorStep(
            StepStatus.blocked,
            '$label yaratib bo‘lmaydi: ${CapabilityRegistry.missing(task)}',
            tool: 'registry',
          )
        : DirectorStep(
            StepStatus.blocked,
            '$label ${cap.provider.label} orqali yaratiladi (${cap.note}). '
            'Narx provayder tarifiga bog‘liq — Kadr AI chatida so‘rovni '
            'yozing: u tasdiq so‘rab, natijani loyihaga qo‘shadi.',
            tool: 'registry',
          );
    return DirectorReport(goal: goal, plan: plan, steps: [step]);
  }

  List<QcFinding> _qc(Map<String, dynamic> plan, List<ProjectClip> clips) {
    final p = EditPlan.fromJson(plan);
    return QualityControl.check(
      p,
      clipDurations: {
        for (final c in clips)
          if (c.durationSec != null && !c.isImage) c.id: c.durationSec!,
      },
      knownClipIds: {for (final c in clips) c.id},
    );
  }
}
