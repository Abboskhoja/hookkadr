import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/option_pill.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/render_player.dart';
import '../../ai/ai_clients.dart';
import '../../analysis/domain/edit_plan.dart';
import '../../editor/editor_screen.dart';
import '../../media/clip_importer.dart';
import '../../projects/project.dart';
import '../../render/export_presets.dart';
import '../../render/media_analyzer.dart';
import '../../render/render_service.dart';
import '../application/montage_service.dart';

/// Dedicated montage page: add clips, set shape/length/quality, one tap →
/// a finished MP4. Same engine as chat ([MontageService]).
class MontageScreen extends StatefulWidget {
  const MontageScreen({super.key});

  @override
  State<MontageScreen> createState() => _MontageScreenState();
}

enum _Phase { setup, working, done }

class _MontageScreenState extends State<MontageScreen> {
  static const _maxClips = 6;
  final _importer = ClipImporter();
  final _prompt = TextEditingController();
  final _clips = <ImportedClip>[];
  String _aspect = '9:16';
  int _duration = 30;
  String _resolution = '1080p';
  _Phase _phase = _Phase.setup;
  String _stage = '';
  double? _progress;
  String? _error;
  String? _projectId;
  RenderInfo? _render;
  bool _saved = false;

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _add({bool camera = false}) async {
    final added = camera
        ? await _importer.record()
        : await _importer.pick(limit: _maxClips - _clips.length);
    if (!mounted || added.isEmpty) return;
    setState(() => _clips.addAll(added));
    for (final c in added) {
      await _importer.measure(c);
      if (mounted) setState(() {});
    }
  }

  Future<void> _note(ImportedClip c) async {
    final ctl = TextEditingController(text: c.note);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c.id),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Izoh: boshiga qo‘y, 0:04–0:08 ni ol…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (v != null) setState(() => c.note = v.trim());
  }

  Future<void> _run() async {
    final app = AppScope.of(context);
    final service = MontageService(
      analyzer: MediaAnalyzer(),
      renderer: RenderService(),
      repository: app,
    );
    setState(() {
      _phase = _Phase.working;
      _error = null;
      _progress = null;
    });
    try {
      final result = await service.buildProject(
        clips: [
          for (final c in _clips)
            MontageClip(
              id: c.id,
              path: c.path,
              name: c.name,
              note: c.note,
              durationSec: c.durationSec,
              sizeBytes: c.sizeBytes,
            ),
        ],
        prompt: _prompt.text.trim(),
        settings: MontageSettings(
          targetSec: _duration,
          aspectRatio: _aspect,
          resolution: _resolution,
          platform: 'Reels',
        ),
        planner: app.generator(onStage: (s) => setState(() => _stage = s)),
        canWatchVideo: app.canWatchVideo,
        analystSizeLimited: app.analystHasSizeLimit,
        onStage: (s) => setState(() => _stage = s),
      );
      final render = await service.render(
        result.projectId,
        resolution: _resolution,
        onStage: (s) => setState(() => _stage = s),
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _projectId = result.projectId;
        _render = render;
        _phase = _Phase.done;
      });
    } on AiException catch (e) {
      if (mounted) setState(() => _fail(e.message));
    } on RenderException catch (e) {
      if (mounted) setState(() => _fail(e.message));
    } on EditPlanFormatException catch (e) {
      if (mounted) {
        setState(() => _fail('AI noto‘g‘ri reja berdi: ${e.message}'));
      }
    } catch (e) {
      if (mounted) setState(() => _fail('Kutilmagan xato: $e'));
    }
  }

  void _fail(String message) {
    _error = message;
    _phase = _Phase.setup;
  }

  Future<void> _save() async {
    final r = _render;
    if (r == null) return;
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putVideo(r.path, album: 'HOOKKADR');
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Galereyaga saqlab bo‘lmadi: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          PageHeader(
            'Montaj',
            actions: [
              if (_phase == _Phase.done)
                GlassIconButton(
                  icon: LucideIcons.rotateCcw,
                  tooltip: 'Yangi montaj',
                  onTap: () => setState(() {
                    _clips.clear();
                    _phase = _Phase.setup;
                    _render = null;
                    _projectId = null;
                    _saved = false;
                  }),
                ),
            ],
          ),
          Expanded(
            child: switch (_phase) {
              _Phase.setup => _setup(context),
              _Phase.working => _working(context),
              _Phase.done => _done(context),
            },
          ),
        ],
      ),
    ),
  );

  Widget _setup(BuildContext context) {
    final p = context.palette;
    final total = _clips.fold<double>(0, (a, c) => a + (c.durationSec ?? 0));
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.62,
                children: [
                  for (final c in _clips)
                    _ClipTile(
                      clip: c,
                      onNote: _note,
                      onRemove: (c) => setState(() => _clips.remove(c)),
                    ),
                  if (_clips.length < _maxClips)
                    _AddTile(
                      onGallery: () => _add(),
                      onCamera: () => _add(camera: true),
                    ),
                ],
              ),
              if (_clips.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_clips.length} klip · jami ${seconds(total)}',
                  style: AppText.caption(context),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _prompt,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Qanday montaj? (ixtiyoriy)',
                  prefixIcon: Icon(LucideIcons.wandSparkles, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                runSpacing: 8,
                children: [
                  OptionPill(
                    icon: LucideIcons.ratio,
                    label: _aspect,
                    busy: false,
                    options: const ['9:16', '16:9', '1:1', '4:5'],
                    onPick: (v) => setState(() => _aspect = v),
                  ),
                  OptionPill(
                    icon: LucideIcons.timer,
                    label: '$_duration s',
                    busy: false,
                    options: const ['15 s', '30 s', '45 s', '60 s'],
                    onPick: (v) => setState(
                      () => _duration = int.parse(v.split(' ').first),
                    ),
                  ),
                  OptionPill(
                    icon: LucideIcons.film,
                    label: _resolution,
                    busy: false,
                    options: const ['360p', '720p', '1080p', '4K'],
                    onPick: (v) => setState(() => _resolution = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 7, left: 4),
                    child: Text(
                      FileSizeEstimator.estimateLabel(
                        _resolution,
                        _duration.toDouble(),
                      ),
                      style: AppText.caption(context).copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _clips.isEmpty ? null : _run,
            icon: const Icon(LucideIcons.scissors, size: 20),
            label: const Text('Montaj qilish'),
            style: FilledButton.styleFrom(
              disabledBackgroundColor: p.surfaceRaised,
            ),
          ),
        ),
      ],
    );
  }

  Widget _working(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_progress == null)
            const CupertinoActivityIndicator(radius: 14)
          else
            SizedBox(
              width: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: _progress, minHeight: 6),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            _progress == null
                ? _stage
                : '$_stage · ${(_progress! * 100).round()}%',
            textAlign: TextAlign.center,
            style: AppText.body(context),
          ),
        ],
      ),
    ),
  );

  Widget _done(BuildContext context) {
    final r = _render;
    final id = _projectId;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (r != null && File(r.path).existsSync())
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: ColoredBox(
                color: Colors.black,
                child: RenderPlayer(path: r.path),
              ),
            ),
          )
        else
          Text(
            'Reja tayyor, lekin video render qilinmadi.',
            style: AppText.body(context),
          ),
        if (r != null) ...[
          const SizedBox(height: 8),
          Text(
            '${r.aspectRatio} · ${r.resolution} · ${seconds(r.durationSec)} · ${r.fps} FPS · MP4 · '
            '${FileSizeEstimator.formatBytes(r.sizeBytes)}',
            style: AppText.caption(context),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            if (id != null)
              IconButton.outlined(
                tooltip: 'Muharrirda ochish',
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => EditorScreen(projectId: id),
                  ),
                ),
                icon: const Icon(LucideIcons.panelsTopLeft),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: r == null || _saved ? null : _save,
                icon: Icon(
                  _saved ? LucideIcons.check : LucideIcons.download,
                  size: 20,
                ),
                label: Text(_saved ? 'Saqlandi' : 'Galereyaga saqlash'),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
      ],
    );
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    required this.clip,
    required this.onNote,
    required this.onRemove,
  });
  final ImportedClip clip;
  final ValueChanged<ImportedClip> onNote;
  final ValueChanged<ImportedClip> onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      onTap: () => onNote(clip),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            clip.thumb != null
                ? Image.memory(clip.thumb!, fit: BoxFit.cover)
                : ColoredBox(
                    color: p.surfaceRaised,
                    child: const Center(child: CupertinoActivityIndicator()),
                  ),
            Positioned(
              top: 2,
              right: 2,
              child: IconButton(
                tooltip: 'Olib tashlash',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () => onRemove(clip),
                icon: const Icon(LucideIcons.x, size: 16, color: Colors.white),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      [
                        if (clip.durationSec != null)
                          seconds(clip.durationSec!),
                        if (clip.sizeBytes != null)
                          FileSizeEstimator.formatBytes(clip.sizeBytes!),
                      ].join(' · '),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          clip.note.isEmpty
                              ? LucideIcons.messageSquarePlus
                              : LucideIcons.messageSquare,
                          size: 12,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            clip.note.isEmpty ? clip.id : clip.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onGallery, required this.onCamera});
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.separator),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filledTonal(
            tooltip: 'Galereyadan video',
            onPressed: onGallery,
            icon: const Icon(LucideIcons.plus),
          ),
          const SizedBox(height: 8),
          IconButton(
            tooltip: 'Kamera',
            onPressed: onCamera,
            icon: Icon(LucideIcons.camera, color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}
