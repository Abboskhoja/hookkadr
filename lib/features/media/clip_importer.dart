import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../render/thumbnailer.dart';

/// A clip copied into the app's storage, with what we could measure.
class ImportedClip {
  ImportedClip({required this.id, required this.path, required this.name});

  bool get isImage {
    final p = path.toLowerCase();
    return p.endsWith('.png') ||
        p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.webp') ||
        p.endsWith('.heic');
  }

  final String id;
  final String path;
  final String name;
  String note = '';
  double? durationSec;
  int? sizeBytes;
  Uint8List? thumb;
}

/// Copies picked videos into app storage (originals stay untouched and the
/// project keeps working after the picker's temp files are purged), then
/// measures duration, size and a thumbnail.
class ClipImporter {
  /// [startIndex]: highest clip number already used in the project, so new
  /// ids never collide (clip_04 follows clip_03).
  ClipImporter({int startIndex = 0}) : _counter = startIndex;

  int _counter;

  String _nextId() => 'clip_${(++_counter).toString().padLeft(2, '0')}';

  Future<List<ImportedClip>> pick({int limit = 6}) async {
    final files = await ImagePicker().pickMultiVideo(limit: limit);
    return _import(files.take(limit).toList());
  }

  /// [maxSide] makes the picker re-encode to JPEG (HEIC photos and EXIF
  /// rotation become plain, upright JPEGs the renderer reads everywhere).
  Future<List<ImportedClip>> pickImages({
    int limit = 10,
    double? maxSide,
  }) async {
    final files = await ImagePicker().pickMultiImage(
      limit: limit,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: maxSide == null ? null : 92,
    );
    return _import(files.take(limit).toList());
  }

  Future<List<ImportedClip>> record() async {
    final f = await ImagePicker().pickVideo(source: ImageSource.camera);
    return f == null ? const [] : _import([f]);
  }

  Future<List<ImportedClip>> _import(List<XFile> files) async {
    if (files.isEmpty) return const [];
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/clips')..createSync(recursive: true);
    final out = <ImportedClip>[];
    for (final f in files) {
      final stored =
          '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${f.name}';
      await File(f.path).copy(stored);
      out.add(ImportedClip(id: _nextId(), path: stored, name: f.name));
    }
    return out;
  }

  /// Fills duration, size and thumbnail; failures leave fields null.
  Future<void> measure(ImportedClip c) async {
    if (c.isImage) {
      c.sizeBytes = await File(c.path).length();
      c.thumb = await File(c.path).readAsBytes();
      return;
    }
    try {
      c.sizeBytes = await File(c.path).length();
      final ctl = VideoPlayerController.file(File(c.path));
      await ctl.initialize();
      c.durationSec = ctl.value.duration.inMilliseconds / 1000;
      await ctl.dispose();
    } catch (_) {}
    try {
      c.thumb = await Thumbnailer.jpeg(c.path);
    } catch (_) {}
  }
}
