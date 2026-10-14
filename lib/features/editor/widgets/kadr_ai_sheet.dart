import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../ai/ai_clients.dart';
import '../../director/kadr_director.dart';
import '../../director/quality_control.dart';
import '../../plan/command_agent.dart';
import '../../plan/plan_diff.dart';
import '../../projects/project.dart';
import '../../render/media_analyzer.dart';
import '../../vision/scene_quality_scanner.dart';

/// Kadr AI bottom sheet: natural-language edit commands. The offline command
/// agent executes deterministic edits instantly; only when it understands
/// nothing does a connected LLM propose a full plan for review.
class KadrAiSheet extends StatefulWidget {
  const KadrAiSheet({
    super.key,
    required this.projectId,
    required this.onApplied,
    required this.onUndo,
    this.playheadSec = 0,
    this.selectedShotId,
  });
  final String projectId;
  final void Function(Map<String, dynamic> before) onApplied;
  final Future<void> Function() onUndo;
  final double playheadSec;
  final String? selectedShotId;

  @override
  State<KadrAiSheet> createState() => _KadrAiSheetState();
}

class _KadrAiSheetState extends State<KadrAiSheet> {
  final _c = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Offline agent commands run immediately; this is what they did.
  List<String> _done = const [];
  List<String> _unhandled = const [];
  List<QcFinding> _findings = const [];

  static const _chips = [
    'Reklama storyboardini tuz',
    'Professional qil',
    'Sifatni tekshir',
    'Hook variantlarini ber',
    'Kino uslubini ber',
    'Videoni 20 soniyaga qisqartir',
    '9:16 qil',
  ];

  /// LLM proposal waiting for Apply/Cancel, with what it would change.
  Map<String, dynamic>? _proposal;
  String? _baseSignature;
  List<String> _changes = const [];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Kadr AI: first the offline command agent (instant, executes for real);
  /// only when it understood nothing, the connected LLM proposes a plan.
  Future<void> _run(String text) async {
    final app = AppScope.of(context);
    final project = app.byId(widget.projectId);
    if (project == null || text.trim().isEmpty) return;
    final director = KadrDirector(
      connected: {
        for (final k in ProviderKind.values)
          if (app.isConnected(k)) k,
      },
      analyzer: MediaAnalyzer(),
      qualityAnalyzer: SceneQualityScanner(),
    );
    setState(() => _busy = true);
    final rep = await director.handle(
      text,
      plan: project.planJson,
      clips: project.clips,
      playheadSec: widget.playheadSec,
      selectedShotId: widget.selectedShotId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (rep.wantsUndo) {
      await widget.onUndo();
      if (!mounted) return;
      setState(() {
        _done = const ['Oxirgi o‘zgarish bekor qilindi'];
        _unhandled = const [];
        _findings = const [];
        _error = null;
      });
      _c.clear();
      return;
    }
    if (rep.changedPlan) {
      widget.onApplied(project.planJson);
      await app.updatePlan(project.id, rep.plan);
      if (!mounted) return;
      setState(() {
        _done = rep.done;
        _unhandled = rep.blocked;
        _findings = rep.findings;
        _error = null;
      });
      _c.clear();
      return;
    }
    // Non-edit goals (review, hook list, generation…) are answered here.
    if (rep.goal != DirectorGoal.edit || rep.handledLocally) {
      setState(() {
        _done = rep.done;
        _unhandled = rep.blocked;
        _findings = rep.findings;
        _error = null;
      });
      _c.clear();
      return;
    }
    final res = (unhandled: rep.blocked);
    final gen = app.generator();
    if (gen == null) {
      setState(() {
        _done = const [];
        _unhandled = res.unhandled;
        _error = res.unhandled.isEmpty
            ? 'Buyruq tushunarsiz. Masalan: “${CommandAgent.examples.first}”.'
            : 'Bajarilmadi. Murakkab so‘rovlar uchun AI ulang (Sozlamalar).';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _done = const [];
      _unhandled = const [];
      _findings = const [];
    });
    try {
      final updated = await gen.edit(
        current: project.planJson,
        instruction: text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _proposal = updated;
        _baseSignature = planSignature(project.planJson);
        _changes = describePlanDiff(project.planJson, updated);
      });
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final app = AppScope.of(context);
    final project = app.byId(widget.projectId);
    final plan = _proposal;
    if (project == null || plan == null) return;
    if (planSignature(project.planJson) != _baseSignature) {
      setState(() {
        _error = 'Loyiha bu taklifdan keyin o‘zgargan. Qayta so‘rang.';
        _proposal = null;
      });
      return;
    }
    widget.onApplied(project.planJson);
    await app.updatePlan(project.id, plan);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.of(context).viewInsets.bottom,
    ),
    child: SingleChildScrollView(
      child: _proposal != null ? _review(context) : _ask(context),
    ),
  );

  Widget _review(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('AI montajchi taklifi', style: AppText.title(context)),
      const SizedBox(height: 10),
      if (_changes.isEmpty)
        Text('O‘zgarish topilmadi.', style: AppText.body(context))
      else
        for (final c in _changes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.dot, size: 18),
                Expanded(
                  child: Text(
                    c,
                    style: AppText.body(context).copyWith(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _changes.isEmpty ? null : _apply,
              icon: const Icon(LucideIcons.check, size: 18),
              label: const Text('Qo‘llash'),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => setState(() => _proposal = null),
            child: const Text('Bekor qilish'),
          ),
        ],
      ),
    ],
  );

  Widget _ask(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(LucideIcons.sparkles, size: 18, color: context.palette.accent),
          const SizedBox(width: 8),
          Text('Kadr AI', style: AppText.title(context)),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Buyruq bering — men timeline’da bajaraman.',
        style: AppText.caption(context),
      ),
      const SizedBox(height: 12),
      _storyboard(context),
      TextField(
        controller: _c,
        enabled: !_busy,
        minLines: 1,
        maxLines: 3,
        textInputAction: TextInputAction.send,
        onSubmitted: _run,
        decoration: const InputDecoration(
          hintText: 'Masalan: videoni 15 soniyaga qisqartir',
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: AppColors.danger)),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : () => _run(_c.text),
        child: _busy
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.palette.onAccent,
                ),
              )
            : const Text('Bajarish'),
      ),
      const SizedBox(height: 12),
      if (_done.isNotEmpty ||
          _unhandled.isNotEmpty ||
          _findings.isNotEmpty) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.palette.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final d in _done)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        LucideIcons.check,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d)),
                    ],
                  ),
                ),
              for (final u in _unhandled)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        LucideIcons.triangleAlert,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(u)),
                    ],
                  ),
                ),
              for (final f in _findings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        f.severity == Severity.problem
                            ? LucideIcons.circleAlert
                            : f.severity == Severity.warning
                            ? LucideIcons.triangleAlert
                            : LucideIcons.info,
                        size: 16,
                        color: f.severity == Severity.problem
                            ? AppColors.danger
                            : f.severity == Severity.warning
                            ? AppColors.warning
                            : context.palette.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f.message)),
                      if (f.fix != null)
                        TextButton(
                          onPressed: _busy ? null : () => _run(f.fix!),
                          child: const Text('Tuzat'),
                        ),
                    ],
                  ),
                ),
              if (_done.isNotEmpty &&
                  _done.first != 'Oxirgi o‘zgarish bekor qilindi')
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await widget.onUndo();
                      if (mounted) {
                        setState(() {
                          _done = const ['Oxirgi o‘zgarish bekor qilindi'];
                          _unhandled = const [];
                        });
                      }
                    },
                    icon: const Icon(LucideIcons.undo2, size: 16),
                    label: const Text('Qaytarish'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final i in _chips)
            ActionChip(label: Text(i), onPressed: _busy ? null : () => _run(i)),
        ],
      ),
      const SizedBox(height: 16),
    ],
  );

  Widget _storyboard(BuildContext context) {
    final project = AppScope.of(context).byId(widget.projectId);
    final document = project?.planJson['production'];
    if (project == null ||
        document is! Map<String, dynamic> ||
        document['schema'] != 'kart.production/1') {
      return const SizedBox.shrink();
    }
    final shots = document['storyboard'];
    if (shots is! List) return const SizedBox.shrink();
    final bare = Map<String, dynamic>.from(project.planJson)
      ..remove('production');
    final stale = document['planSignature'] != planSignature(bare);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Storyboard · ${shots.length} kadr'),
      subtitle: Text(
        stale
            ? 'Timeline o‘zgargan; bu avvalgi storyboard.'
            : project.renderIsCurrent
            ? 'Storyboard · joriy MP4 eksporti mavjud'
            : 'Suratga olish rejasi · joriy MP4 eksporti yo‘q',
      ),
      children: [
        for (final shot in shots.whereType<Map>())
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${shot['startSec']}–${shot['endSec']} s · ${shot['purpose']}',
            ),
            subtitle: Text(
              '${(shot['captureDirection'] as Map?)?['composition'] ?? ''}\n'
              '${shot['generationInstruction'] ?? ''}',
            ),
          ),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(
                text: const JsonEncoder.withIndent('  ').convert(document),
              ),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Storyboard nusxalandi')),
              );
            }
          },
          icon: const Icon(LucideIcons.copy, size: 16),
          label: const Text('Storyboard JSON nusxalash'),
        ),
      ],
    );
  }
}
