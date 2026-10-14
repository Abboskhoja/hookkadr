import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/render_player.dart';
import '../../ai/ai_clients.dart';
import '../../editor/editor_screen.dart';
import '../../media/clip_importer.dart';
import '../../montage/output_format.dart';
import '../../projects/project.dart';
import '../../render/render_service.dart';
import '../application/ad_copy_writer.dart';
import '../application/product_ad_service.dart';
import '../data/ad_output_check.dart';
import '../data/music_synth.dart';
import '../domain/product_ad_composer.dart';

/// What the user chose in the setup sheet.
class AdSetup {
  const AdSetup({
    required this.brief,
    required this.aspect,
    required this.seconds,
  });
  final String brief;
  final String aspect;
  final int seconds;
}

/// Photos of a product → finished ad video, entirely on the phone.
Future<void> startProductAd(
  BuildContext context, {
  int seconds = 20,
  String aspect = '9:16',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final importer = ClipImporter();
  final picked = await importer.pickImages(limit: 10, maxSide: 2160);
  if (!context.mounted || picked.isEmpty) return;
  if (picked.length < 2) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Kamida 2 ta rasm tanlang.')),
    );
    return;
  }
  for (final c in picked) {
    await importer.measure(c);
  }
  if (!context.mounted) return;
  final setup = await showModalBottomSheet<AdSetup>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AdSetupSheet(
      images: [for (final c in picked) c.thumb],
      initialSeconds: seconds,
      initialAspect: aspect,
    ),
  );
  if (setup == null || !context.mounted) return;
  await _create(context, [
    for (final c in picked)
      ProjectClip(id: c.id, path: c.path, name: c.name, sizeBytes: c.sizeBytes),
  ], setup);
}

Future<void> _create(
  BuildContext context,
  List<ProjectClip> images,
  AdSetup setup,
) async {
  final app = AppScope.of(context);
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final stage = ValueNotifier<String>('Boshlanmoqda…');
  final progress = ValueNotifier<double?>(null);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: stage,
              builder: (_, s, _) => Text(s, style: AppText.body(context)),
            ),
            const SizedBox(height: 14),
            ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (_, p, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: p),
                  if (p != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${(p * 100).round()}%',
                      style: AppText.caption(context),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  try {
    final result =
        await ProductAdService(
          repository: app,
          renderer: RenderService(),
          music: MusicSynth(),
          copyWriter: AdCopyWriter(app.localModel),
          verify: checkAdOutput,
        ).create(
          images: images,
          brief: setup.brief,
          durationSec: setup.seconds,
          aspectRatio: setup.aspect,
          onStage: (s) {
            stage.value = s;
            progress.value = null;
          },
          onProgress: (p) => progress.value = p,
        );
    nav.pop();
    await nav.push(
      CupertinoPageRoute<void>(builder: (_) => AdResultScreen(result: result)),
    );
  } on AiException catch (e) {
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } on RenderException catch (e) {
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    nav.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Reklama yaratib bo‘lmadi. Boshqa rasmlar bilan urinib ko‘ring.',
        ),
      ),
    );
  } finally {
    stage.dispose();
    progress.dispose();
  }
}

/// Brief, format and length before creating the ad.
class AdSetupSheet extends StatefulWidget {
  const AdSetupSheet({
    super.key,
    required this.images,
    this.initialSeconds = 20,
    this.initialAspect = '9:16',
  });

  /// Thumbnails of the chosen photos (null when one could not be read).
  final List<Uint8List?> images;
  final int initialSeconds;
  final String initialAspect;

  @override
  State<AdSetupSheet> createState() => _AdSetupSheetState();
}

class _AdSetupSheetState extends State<AdSetupSheet> {
  final _brief = TextEditingController();
  late int _seconds = widget.initialSeconds;
  late String _aspect = widget.initialAspect;

  @override
  void dispose() {
    _brief.dispose();
    super.dispose();
  }

  int get _maxPhotos =>
      (_seconds *
          ProductAdComposer.fps ~/
          (ProductAdComposer.fps * 60 ~/ ProductAdComposer.bpm)) ~/
      ProductAdComposer.minBeatsPerShot;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final app = AppScope.of(context);
    final n = widget.images.length;
    final tooMany = n > _maxPhotos;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rasmlardan reklama', style: AppText.title(context)),
              const SizedBox(height: 4),
              Text(
                '$n ta rasm · kesimlar musiqa ritmida · matn va musiqa bilan',
                style: AppText.caption(context),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: n,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final t = widget.images[i];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 58,
                        color: p.surfaceRaised,
                        child: t == null
                            ? Icon(LucideIcons.image, color: p.textSecondary)
                            : Image.memory(t, fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _brief,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Mahsulot haqida bir gap',
                  hintText: 'Masalan: Charm sumka, qo‘lda tikilgan',
                ),
              ),
              Text('Qayerga', style: AppText.caption(context)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in OutputFormat.all)
                    ChoiceChip(
                      label: Text(f.label),
                      selected: f.aspect == _aspect,
                      onSelected: (_) => setState(() => _aspect = f.aspect),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Uzunligi', style: AppText.caption(context)),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 15, label: Text('15 s')),
                  ButtonSegment(value: 20, label: Text('20 s')),
                  ButtonSegment(value: 30, label: Text('30 s')),
                ],
                selected: {_seconds},
                onSelectionChanged: (v) => setState(() => _seconds = v.first),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    LucideIcons.sparkles,
                    size: 16,
                    color: app.localModel != null ? p.accent : p.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      app.localModel != null
                          ? 'Matnni Kadr AI telefonda yozadi.'
                          : 'Kadr AI o‘rnatilmagan — oddiy neytral matn qo‘yiladi. '
                                'Uni Profil → Kadr AI telefonda bo‘limidan o‘rnating.',
                      style: AppText.caption(context),
                    ),
                  ),
                ],
              ),
              if (tooMany) ...[
                const SizedBox(height: 8),
                Text(
                  '$_seconds soniyaga ko‘pi bilan $_maxPhotos ta rasm sig‘adi — '
                  'uzunlikni oshiring yoki kamroq rasm tanlang.',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: tooMany
                      ? null
                      : () => Navigator.pop(
                          context,
                          AdSetup(
                            brief: _brief.text.trim(),
                            aspect: _aspect,
                            seconds: _seconds,
                          ),
                        ),
                  icon: const Icon(LucideIcons.clapperboard, size: 18),
                  label: const Text('Reklama yaratish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The finished ad: watch it, save it, share it or keep editing.
class AdResultScreen extends StatelessWidget {
  const AdResultScreen({super.key, required this.result});
  final ProductAdResult result;

  Future<void> _save(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Gal.putVideo(result.outputPath, album: 'HOOKKADR');
      messenger.showSnackBar(
        const SnackBar(content: Text('Galereyaga saqlandi.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Saqlab bo‘lmadi: galereyaga ruxsat bering.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = result.copy;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader('Reklama tayyor'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  AspectRatio(
                    aspectRatio: 9 / 13,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ColoredBox(
                        color: Colors.black,
                        child: File(result.outputPath).existsSync()
                            ? RenderPlayer(
                                path: result.outputPath,
                                posterAt: const Duration(milliseconds: 1200),
                              )
                            : const Center(child: Text('Video topilmadi')),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    result.copyByAi
                        ? 'Matnni Kadr AI telefonda yozdi'
                        : 'Neytral shablon matn (Kadr AI o‘rnatilmagan)',
                    style: AppText.caption(context),
                  ),
                  const SizedBox(height: 6),
                  for (final line in [c.hook, ...c.lines, c.cta])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('•  $line', style: AppText.body(context)),
                    ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => _save(context),
                    icon: const Icon(LucideIcons.download, size: 18),
                    label: const Text('Galereyaga saqlash'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) =>
                            EditorScreen(projectId: result.projectId),
                      ),
                    ),
                    icon: const Icon(LucideIcons.scissors, size: 18),
                    label: const Text('Tahrirlash'),
                  ),
                  TextButton.icon(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(files: [XFile(result.outputPath)]),
                    ),
                    icon: Icon(LucideIcons.share2, size: 18, color: p.accent),
                    label: const Text('Ulashish'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
