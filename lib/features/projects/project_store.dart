import 'dart:convert';

import 'project.dart';

/// Preserves unreadable source data before replacing a project collection.
/// Storage callbacks keep this policy independent of Flutter and preferences.
class ProjectStore {
  ProjectStore({required this.read, required this.write});

  static const projectsKey = 'projects_v1';
  static const recoveryKey = 'projects_recovery_v1';
  final String? Function(String key) read;
  final Future<bool> Function(String key, String value) write;

  List<Project> load() => _decode(read(projectsKey)).projects;

  Future<void> save(List<Project> projects) async {
    // Encode before any write: an invalid new value must not touch storage.
    final encoded = jsonEncode(projects.map((p) => p.toJson()).toList());
    final raw = read(projectsKey);
    if (raw != null && _decode(raw).damaged) {
      final backup = read(recoveryKey);
      final List<dynamic> snapshots;
      if (backup == null) {
        snapshots = [];
      } else {
        // Fail closed if the recovery archive itself is malformed.
        final decoded = jsonDecode(backup);
        if (decoded is! List || decoded.any((item) => item is! String)) {
          throw StateError('Loyiha zaxirasi o‘qilmadi. Asl ma’lumot saqlandi.');
        }
        snapshots = decoded;
      }
      if (!snapshots.contains(raw)) {
        snapshots.add(raw);
        if (!await write(recoveryKey, jsonEncode(snapshots))) {
          throw StateError(
            'Loyiha zaxirasi saqlanmadi. Asl ma’lumot saqlandi.',
          );
        }
      }
    }
    if (!await write(projectsKey, encoded)) {
      throw StateError('Loyihalar saqlanmadi. Qayta urinib ko‘ring.');
    }
  }

  ({List<Project> projects, bool damaged}) _decode(String? raw) {
    if (raw == null) return (projects: [], damaged: false);
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return (projects: [], damaged: true);
    }
    if (decoded is! List) return (projects: [], damaged: true);
    final projects = <Project>[];
    var damaged = false;
    for (final entry in decoded) {
      try {
        if (entry is! Map<String, dynamic>) {
          damaged = true;
          continue;
        }
        projects.add(Project.fromJson(entry));
      } on Object {
        // The full original document is retained before the next save.
        damaged = true;
      }
    }
    return (projects: projects, damaged: damaged);
  }
}
