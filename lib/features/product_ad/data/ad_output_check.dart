import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';

import '../../analysis/domain/edit_plan.dart';

/// Checks what the renderer's own verification does not: when the plan has
/// music, the file must really contain an audio stream of the right length.
Future<List<String>> checkAdOutput(String path, EditPlan plan) async {
  final probe = (await FFprobeKit.getMediaInformation(path))
      .getMediaInformation()
      ?.getAllProperties();
  if (probe == null) return const ['faylni o‘qib bo‘lmadi'];
  return adOutputProblems(probe, plan);
}

/// Pure part of [checkAdOutput], unit-tested with probe JSON.
List<String> adOutputProblems(Map<dynamic, dynamic> probe, EditPlan plan) {
  if (plan.music == null) return const [];
  final streams = probe['streams'];
  Map? audio;
  if (streams is List) {
    for (final s in streams) {
      if (s is Map && s['codec_type'] == 'audio') {
        audio = s;
        break;
      }
    }
  }
  if (audio == null) return const ['videoda musiqa (audio) yo‘q'];
  final d = double.tryParse('${audio['duration']}');
  if (d == null || (d - plan.durationSec).abs() > 0.25) {
    return [
      'audio davomiyligi ${d?.toStringAsFixed(2) ?? '?'} s, kutilgan ${plan.durationSec} s',
    ];
  }
  return const [];
}
