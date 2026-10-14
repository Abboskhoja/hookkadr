import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../application/product_ad_service.dart';

/// Kadr AI background music, synthesised by FFmpeg: a soft I–V–vi–IV pad
/// in C, a plucked bass and a gentle kick on every beat. Our own sound, so
/// there is no licence question, and its beat grid is exact, so cuts can land
/// on the beat. It is simple production music, not a composed song.
class MusicSynth implements MusicMaker {
  MusicSynth({Future<Directory> Function()? dir})
    : _dir = dir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _dir;

  static List<double> beatTimes({
    required double durationSec,
    required int bpm,
  }) {
    final beat = 60 / bpm;
    return [for (var t = 0.0; t < durationSec - 1e-9; t += beat) t];
  }

  // Bar chords (three voices) and bass roots, Hz.
  static const _chords = [
    [261.63, 329.63, 392.00], // C
    [246.94, 293.66, 392.00], // G
    [261.63, 329.63, 440.00], // Am
    [261.63, 349.23, 440.00], // F
  ];
  static const _bass = [65.41, 98.00, 110.00, 87.31];

  static String _pick(String k, List<double> v) =>
      'if(eq($k,0),${v[0]},if(eq($k,1),${v[1]},if(eq($k,2),${v[2]},${v[3]})))';

  static List<String> buildArgs({
    required double durationSec,
    required int bpm,
    required String outPath,
  }) {
    final b = (60 / bpm).toStringAsFixed(6);
    final bar = (240 / bpm).toStringAsFixed(6);
    final d = durationSec.toStringAsFixed(3);
    final k = 'mod(floor(t/$bar),4)';
    String voice(int i) =>
        'sin(2*PI*${_pick(k, [for (final c in _chords) c[i]])}*t)';
    final pad =
        '0.09*(${voice(0)}+${voice(1)}+${voice(2)})*pow(sin(PI*mod(t,$bar)/$bar),0.6)';
    // Every beat envelope returns to exactly zero before the next beat, so
    // the grid has no clicks.
    final tail = '(1-pow(mod(t,$b)/$b,4))';
    final bass =
        '0.18*sin(2*PI*${_pick(k, _bass)}*t)*exp(-3*mod(t,$b))*(1-exp(-60*mod(t,$b)))*$tail';
    final kick =
        '0.35*sin(2*PI*(45+90*exp(-25*mod(t,$b)))*mod(t,$b))*exp(-9*mod(t,$b))*$tail';
    final e = '$pad+$bass+$kick';
    final fadeAt = (durationSec - 1.5).clamp(0, durationSec).toStringAsFixed(3);
    return [
      '-y',
      '-hide_banner',
      '-filter_complex',
      "aevalsrc=exprs='$e|$e':s=44100:d=$d,lowpass=f=4500,"
          'afade=t=in:d=0.5,afade=t=out:st=$fadeAt:d=1.5,volume=0.9[a]',
      '-map',
      '[a]',
      '-t',
      d,
      '-c:a',
      'aac',
      '-b:a',
      '160k',
      outPath,
    ];
  }

  @override
  Future<String> make({required double durationSec, required int bpm}) async {
    final dir = Directory('${(await _dir()).path}/music')
      ..createSync(recursive: true);
    final out = '${dir.path}/kadr_music_${bpm}bpm_${durationSec.round()}s.m4a';
    if (File(out).existsSync() && File(out).lengthSync() > 0) return out;
    final session = await FFmpegKit.executeWithArguments(
      buildArgs(durationSec: durationSec, bpm: bpm, outPath: out),
    );
    if (!ReturnCode.isSuccess(await session.getReturnCode())) {
      throw StateError(
        'Musiqa yaratilmadi: ${(await session.getAllLogsAsString())?.split('\n').lastWhere((l) => l.trim().isNotEmpty, orElse: () => '')}',
      );
    }
    return out;
  }
}
