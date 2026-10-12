import 'dart:convert';

/// A user clip stored inside the app so previews survive restarts.
class ProjectClip {
  const ProjectClip({
    required this.id,
    required this.path,
    required this.name,
    this.durationSec,
    this.sizeBytes,
  });

  factory ProjectClip.fromJson(Map<String, dynamic> j) => ProjectClip(
    id: j['id'] as String,
    path: j['path'] as String,
    name: j['name'] as String,
    durationSec: (j['durationSec'] as num?)?.toDouble(),
    sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
  );

  final String id;
  final String path;
  final String name;
  final double? durationSec;
  final int? sizeBytes;

  /// Still images (AI generated or user supplied) are rendered with a slow
  /// zoom; everything else is treated as video.
  bool get isImage {
    final p = path.toLowerCase();
    return p.endsWith('.png') ||
        p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.webp') ||
        p.endsWith('.heic');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'durationSec': durationSec,
    'sizeBytes': sizeBytes,
  };
}

/// Stable FNV-1a signature of a plan, used to tell if a render is current.
String planSignature(Map<String, dynamic> plan) {
  var h = 0x811c9dc5;
  for (final c in jsonEncode(plan).codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16);
}

/// Facts about the last real MP4 render (never estimated).
class RenderInfo {
  const RenderInfo({
    required this.path,
    required this.sizeBytes,
    required this.resolution,
    required this.aspectRatio,
    required this.durationSec,
    required this.fps,
    required this.createdAt,
    required this.planSignature,
  });

  factory RenderInfo.fromJson(Map<String, dynamic> j) => RenderInfo(
    path: j['path'] as String,
    sizeBytes: (j['sizeBytes'] as num).toInt(),
    resolution: j['resolution'] as String,
    aspectRatio: j['aspectRatio'] as String,
    durationSec: (j['durationSec'] as num).toDouble(),
    fps: (j['fps'] as num).toInt(),
    createdAt: DateTime.parse(j['createdAt'] as String),
    planSignature: j['planSignature'] as String? ?? '',
  );

  final String path;
  final int sizeBytes;
  final String resolution;
  final String aspectRatio;
  final double durationSec;
  final int fps;
  final DateTime createdAt;

  /// [planSignature] of the plan that produced this file.
  final String planSignature;

  Map<String, dynamic> toJson() => {
    'planSignature': planSignature,
    'path': path,
    'sizeBytes': sizeBytes,
    'resolution': resolution,
    'aspectRatio': aspectRatio,
    'durationSec': durationSec,
    'fps': fps,
    'createdAt': createdAt.toIso8601String(),
  };
}

class Project {
  Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.planJson,
    this.clips = const [],
    this.history = const [],
    this.lastRender,
  });

  /// Previous plan versions, oldest first (bounded).
  final List<Map<String, dynamic>> history;
  final RenderInfo? lastRender;

  static const maxHistory = 20;

  factory Project.fromJson(Map<String, dynamic> j) => Project(
    id: j['id'] as String,
    name: j['name'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    planJson: j['plan'] as Map<String, dynamic>,
    clips: [
      for (final c in (j['clips'] as List? ?? const []))
        ProjectClip.fromJson(c as Map<String, dynamic>),
    ],
    history: [
      for (final h in (j['history'] as List? ?? const []))
        h as Map<String, dynamic>,
    ],
    lastRender: j['lastRender'] == null
        ? null
        : RenderInfo.fromJson(j['lastRender'] as Map<String, dynamic>),
  );

  final String id;
  final String name;
  final DateTime createdAt;

  /// Validated EditPlan JSON (see EditPlan.fromJson).
  final Map<String, dynamic> planJson;
  final List<ProjectClip> clips;

  ProjectClip? clip(String? id) {
    for (final c in clips) {
      if (c.id == id) return c;
    }
    return null;
  }

  Project copyWith({
    String? name,
    Map<String, dynamic>? planJson,
    List<Map<String, dynamic>>? history,
    RenderInfo? lastRender,
    List<ProjectClip>? clips,
  }) => Project(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    planJson: planJson ?? this.planJson,
    clips: clips ?? this.clips,
    history: history ?? this.history,
    lastRender: lastRender ?? this.lastRender,
  );

  /// The rendered MP4 matches the current plan (plan unchanged since render).
  bool get renderIsCurrent =>
      lastRender != null &&
      lastRender!.planSignature == planSignature(planJson);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'plan': planJson,
    'clips': clips.map((c) => c.toJson()).toList(),
    'history': history,
    'lastRender': lastRender?.toJson(),
  };
}
