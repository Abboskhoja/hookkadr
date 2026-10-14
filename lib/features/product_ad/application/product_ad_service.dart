import 'dart:io';

import '../../ai/ai_clients.dart';
import '../../analysis/domain/edit_plan.dart';
import '../../montage/application/montage_service.dart';
import '../../projects/project.dart';
import '../domain/ad_copy.dart';
import '../domain/product_ad_composer.dart';
import 'ad_copy_writer.dart';

/// Produces a background music file of an exact length and tempo.
abstract interface class MusicMaker {
  Future<String> make({required double durationSec, required int bpm});
}

/// Extra checks on the finished file beyond the renderer's own (e.g. that
/// the requested music is really in it). Returns problems; empty = good.
typedef OutputVerifier = Future<List<String>> Function(
  String path,
  EditPlan plan,
);

class ProductAdResult {
  const ProductAdResult({
    required this.projectId,
    required this.outputPath,
    required this.copy,
    required this.copyByAi,
  });
  final String projectId;
  final String outputPath;
  final AdCopy copy;
  final bool copyByAi;
}

/// "Photos of my product → finished premium ad", fully on the phone:
/// copy (Kadr AI) → music (synth) → beat-locked plan → project → render →
/// verification. A file that fails verification is never reported as done.
class ProductAdService {
  ProductAdService({
    required this.repository,
    required this.renderer,
    required this.music,
    required this.copyWriter,
    required this.verify,
    int Function(String path)? fileSize,
    DateTime Function()? clock,
  }) : _fileSize = fileSize ?? ((p) => File(p).lengthSync()),
       _clock = clock ?? DateTime.now;

  final ProjectRepository repository;
  final VideoRenderer renderer;
  final MusicMaker music;
  final AdCopyWriter copyWriter;
  final OutputVerifier verify;
  final int Function(String path) _fileSize;
  final DateTime Function() _clock;

  Future<ProductAdResult> create({
    required List<ProjectClip> images,
    required String brief,
    int durationSec = 20,
    String aspectRatio = '9:16',
    String resolution = '1080p',
    void Function(String stage)? onStage,
    void Function(double progress)? onProgress,
  }) async {
    onStage?.call(
      copyWriter.model == null
          ? 'Reklama matni tayyorlanmoqda'
          : 'Kadr AI reklama matnini yozmoqda',
    );
    final copy = await copyWriter.write(brief: brief, photos: images.length);

    onStage?.call('Fon musiqasi yaratilmoqda');
    final musicPath = await music.make(
      durationSec: durationSec.toDouble(),
      bpm: ProductAdComposer.bpm,
    );

    onStage?.call('Kadrlar musiqa ritmiga joylanmoqda');
    final title = brief.trim().isEmpty
        ? 'Mahsulot reklamasi'
        : 'Reklama: ${brief.trim()}';
    final json = ProductAdComposer.compose(
      clipIds: [for (final i in images) i.id],
      copy: copy.copy,
      title: title,
      durationSec: durationSec,
      aspectRatio: aspectRatio,
      resolution: resolution,
      musicPath: musicPath,
    );
    final plan = EditPlan.fromJson(json); // never store an invalid plan
    final project = await repository.addProject(json, clips: images);

    onStage?.call('Video render qilinmoqda');
    final out = await renderer.render(
      plan: plan,
      clips: images,
      resolution: resolution,
      name: title,
      onProgress: onProgress,
    );

    onStage?.call('Tayyor video tekshirilmoqda');
    final problems = await verify(out, plan);
    if (problems.isNotEmpty) {
      throw AiException('Video tekshiruvdan o‘tmadi: ${problems.join('; ')}');
    }
    await repository.setLastRender(
      project.id,
      RenderInfo(
        path: out,
        sizeBytes: _fileSize(out),
        resolution: resolution,
        aspectRatio: aspectRatio,
        durationSec: plan.durationSec,
        fps: plan.export.fps,
        createdAt: _clock(),
        planSignature: planSignature(json),
      ),
    );
    return ProductAdResult(
      projectId: project.id,
      outputPath: out,
      copy: copy.copy,
      copyByAi: copy.byAi,
    );
  }
}
