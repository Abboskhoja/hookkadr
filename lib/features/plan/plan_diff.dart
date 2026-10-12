import '../../core/format.dart';

/// Human-readable list of what changed between two EditPlan JSON maps
/// (shown in the EditDiffCard so the user sees exactly what the AI did).
List<String> describePlanDiff(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) {
  final out = <String>[];
  double n(Object? v) => (v as num?)?.toDouble() ?? 0;

  final d0 = n(before['durationSec']);
  final d1 = n(after['durationSec']);
  if ((d0 - d1).abs() > 0.05) {
    out.add('Davomiylik: ${seconds(d0)} → ${seconds(d1)}');
  }
  if (before['aspectRatio'] != after['aspectRatio']) {
    out.add('Format: ${before['aspectRatio']} → ${after['aspectRatio']}');
  }
  final r0 = (before['export'] as Map?)?['resolution'];
  final r1 = (after['export'] as Map?)?['resolution'];
  if (r0 != r1) out.add('Sifat: $r0 → $r1');

  Map<String, Map<String, dynamic>> byId(Map<String, dynamic> plan) => {
    for (final s
        in (plan['shots'] as List? ?? const []).cast<Map<String, dynamic>>())
      s['id'] as String: s,
  };
  final a = byId(before);
  final b = byId(after);
  for (final id in a.keys.where((k) => !b.containsKey(k))) {
    out.add('Kadr olib tashlandi: $id');
  }
  for (final id in b.keys.where((k) => !a.containsKey(k))) {
    out.add(
      'Yangi kadr: $id (${seconds(n(b[id]!['endSec']) - n(b[id]!['startSec']))})',
    );
  }
  for (final id in b.keys.where(a.containsKey)) {
    final x = a[id]!;
    final y = b[id]!;
    final dx = n(x['endSec']) - n(x['startSec']);
    final dy = n(y['endSec']) - n(y['startSec']);
    if ((dx - dy).abs() > 0.05) {
      out.add('Kadr $id: ${seconds(dx)} → ${seconds(dy)}');
    }
    if (x['description'] != y['description']) {
      out.add('Kadr $id tavsifi yangilandi');
    }
    if (x['sourceClipId'] != y['sourceClipId'] ||
        x['sourceIn'] != y['sourceIn']) {
      out.add('Kadr $id: boshqa material/oraliq');
    }
  }
  final orderA = a.keys.where(b.containsKey).toList();
  final orderB = b.keys.where(a.containsKey).toList();
  if (orderA.join(',') != orderB.join(',')) out.add('Kadrlar tartibi o‘zgardi');

  final c0 = (before['captions'] as List? ?? const []).length;
  final c1 = (after['captions'] as List? ?? const []).length;
  final caps0 = [
    for (final c in (before['captions'] as List? ?? const []))
      (c as Map)['text'],
  ];
  final caps1 = [
    for (final c in (after['captions'] as List? ?? const []))
      (c as Map)['text'],
  ];
  if (c1 > c0) {
    out.add('Subtitr qo‘shildi (+${c1 - c0})');
  } else if (c1 < c0) {
    out.add('Subtitr olib tashlandi (−${c0 - c1})');
  } else if (caps0.join('|') != caps1.join('|')) {
    out.add('Subtitr matni yangilandi');
  }
  final a0 = (before['audioTracks'] as List? ?? const []).length;
  final a1 = (after['audioTracks'] as List? ?? const []).length;
  if (a0 != a1) out.add('Audio qatorlari: $a0 → $a1');
  return out;
}
