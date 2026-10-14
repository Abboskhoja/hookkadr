import '../analysis/domain/edit_plan.dart';
import '../projects/project.dart';
import 'export_presets.dart';

/// Resolved output size for a plan.
({int width, int height}) outputSize(String aspectRatio, String resolution) {
  final short = ExportPreset.of(resolution).shortSide;
  switch (aspectRatio) {
    case '16:9':
      return (width: (short * 16 / 9).round() ~/ 2 * 2, height: short);
    case '1:1':
      return (width: short, height: short);
    case '4:5':
      return (width: short, height: (short * 5 / 4).round() ~/ 2 * 2);
    case '3:4':
      return (width: short, height: (short * 4 / 3).round() ~/ 2 * 2);
    default: // 9:16
      return (width: short, height: (short * 16 / 9).round() ~/ 2 * 2);
  }
}

class RenderArgs {
  RenderArgs({
    required this.args,
    required this.totalSec,
    required this.textFiles,
  });
  final List<String> args;
  final double totalSec;

  /// Text files the filter graph reads (path -> content). Writing text to
  /// files avoids every filtergraph escaping problem.
  final Map<String, String> textFiles;
}

/// Builds the ffmpeg arguments that turn an [EditPlan] and the project's
/// clips into one MP4. Pure function so it can be unit-tested without
/// FFmpeg. [hasAudio] tells which clip ids contain an audio stream.
RenderArgs buildRenderArgs({
  required EditPlan plan,
  required List<ProjectClip> clips,
  required Set<String> hasAudio,
  required String fontPath,
  required String textDir,
  required String outputPath,
  required String videoEncoder,
  required String resolution,
  double? musicDurationSec,
}) {
  final size = outputSize(plan.aspectRatio, resolution);
  final w = size.width;
  final h = size.height;
  final fps = plan.export.fps;

  final usedClipIds = <String>[];
  for (final s in plan.shots) {
    final id = s.sourceClipId;
    if (id != null &&
        clips.any((c) => c.id == id) &&
        !usedClipIds.contains(id)) {
      usedClipIds.add(id);
    }
  }

  final args = <String>['-y'];
  final isImage = <String>{};
  for (final id in usedClipIds) {
    final c = clips.firstWhere((c) => c.id == id);
    if (c.isImage) {
      isImage.add(id);
      args.addAll(['-loop', '1', '-framerate', '$fps']);
    }
    args
      ..add('-i')
      ..add(c.path);
  }

  // Logo end card: an extra still-image input placed after the clips.
  final logo = plan.logo;
  final logoClip = logo == null
      ? null
      : clips.where((c) => c.id == logo.clipId && c.isImage).firstOrNull;
  int? logoIdx;
  if (logoClip != null) {
    logoIdx = usedClipIds.length;
    args.addAll(['-loop', '1', '-framerate', '$fps', '-i', logoClip.path]);
  }

  final textFiles = <String, String>{};
  String textFile(String key, String text) {
    final path = '$textDir/$key.txt';
    textFiles[path] = text.replaceAll('\n', ' ');
    return path;
  }

  String n3(double v) => v.toStringAsFixed(3);
  final shots = plan.shots;

  // Effective transition length into shot i (0 = hard cut). Never longer
  // than half of either neighbour so no shot disappears.
  double transIn(int i) {
    if (i == 0 || shots[i].transition == ShotTransition.cut) return 0;
    final t = shots[i].transitionSec;
    final limit = [
      shots[i - 1].duration * 0.5,
      shots[i].duration * 0.5,
    ].reduce((a, b) => a < b ? a : b);
    return (t < limit ? t : limit).clamp(0.0, 2.0).toDouble();
  }

  final f = StringBuffer();
  final audioInputs = StringBuffer();
  for (final (i, s) in shots.indexed) {
    final d = s.duration;
    // The outgoing shot runs on under the next transition so the timeline
    // length (and every caption / beat) stays exactly as planned.
    final tail = i + 1 < shots.length ? transIn(i + 1) : 0.0;
    final len = d + tail;
    final speed = s.speed;
    final idx = s.sourceClipId == null
        ? -1
        : usedClipIds.indexOf(s.sourceClipId!);
    final motion = motionFilter(s.motion, w, h, fps);
    if (idx >= 0 && isImage.contains(s.sourceClipId)) {
      // Still image: oversample, then a push-in (slow Ken Burns by default).
      final z = s.motion == ShotMotion.punchIn
          ? "if(lt(on,9),1.22-0.024*on,1.0+(on-9)*0.0004)"
          : 'min(1.0+on*0.0007,1.25)';
      f.write(
        '[$idx:v]scale=${w * 2}:${h * 2}:force_original_aspect_ratio=increase,'
        'crop=${w * 2}:${h * 2},'
        "zoompan=z='$z':x='iw/2-(iw/zoom/2)':"
        "y='ih/2-(ih/zoom/2)':d=1:s=${w}x$h:fps=$fps,"
        'trim=duration=${n3(len)},setpts=PTS-STARTPTS,setsar=1,settb=AVTB,format=yuv420p[v$i];',
      );
      f.write(
        'anullsrc=r=44100:cl=stereo,atrim=duration=${n3(d)},asetpts=PTS-STARTPTS[a$i];',
      );
    } else if (idx >= 0 && s.freeze) {
      // Freeze frame: take one frame and hold it.
      f.write(
        '[$idx:v]trim=start=${n3(s.sourceIn ?? 0)}:duration=0.050,setpts=PTS-STARTPTS,'
        'scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h,'
        'setsar=1,fps=$fps$motion,tpad=stop_mode=clone:stop_duration=${n3(len)},'
        'trim=duration=${n3(len)},settb=AVTB,format=yuv420p[v$i];',
      );
      f.write(
        'anullsrc=r=44100:cl=stereo,atrim=duration=${n3(d)},asetpts=PTS-STARTPTS[a$i];',
      );
    } else if (idx >= 0) {
      final sIn = n3(s.sourceIn ?? 0);
      final pts = speed == 1.0
          ? 'PTS-STARTPTS'
          : '(PTS-STARTPTS)/${speed.toStringAsFixed(4)}';
      f.write(
        '[$idx:v]trim=start=$sIn:duration=${n3(len * speed)},setpts=$pts,'
        'scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h,'
        'setsar=1,fps=$fps$motion,tpad=stop_mode=clone:stop_duration=${n3(len)},'
        'trim=duration=${n3(len)},settb=AVTB,format=yuv420p[v$i];',
      );
      if (hasAudio.contains(s.sourceClipId)) {
        final tempo = atempoChain(speed);
        f.write(
          '[$idx:a]atrim=start=$sIn:duration=${n3(d * speed)},asetpts=PTS-STARTPTS'
          '${tempo.isEmpty ? '' : ',$tempo'}'
          '${s.volume == 1.0 ? '' : ',volume=${s.volume.toStringAsFixed(2)}'},'
          'aresample=44100,aformat=channel_layouts=stereo,'
          'apad=whole_dur=${n3(d)},atrim=duration=${n3(d)}[a$i];',
        );
      } else {
        f.write(
          'anullsrc=r=44100:cl=stereo,atrim=duration=${n3(d)},asetpts=PTS-STARTPTS[a$i];',
        );
      }
    } else {
      // No footage for this shot (e.g. a still to be generated): dark card
      // with the shot description so the cut is visible, never a fake image.
      f.write(
        'color=c=0x181715:s=${w}x$h:r=$fps:d=${n3(len)},format=yuv420p,settb=AVTB,'
        'drawtext=fontfile=$fontPath:textfile=${textFile('shot$i', s.description)}:'
        'expansion=none:fontsize=${(h * 0.028).round()}:'
        'fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2[v$i];',
      );
      f.write(
        'anullsrc=r=44100:cl=stereo,atrim=duration=${n3(d)},asetpts=PTS-STARTPTS[a$i];',
      );
    }
    audioInputs.write('[a$i]');
  }

  // Video: chain shots with concat (cuts) or xfade (transitions).
  var acc = 'v0';
  if (shots.first.transition == ShotTransition.fadeBlack) {
    final t = shots.first.transitionSec
        .clamp(0.1, shots.first.duration * 0.5)
        .toDouble();
    f.write('[v0]fade=t=in:st=0:d=${n3(t)}[vin];');
    acc = 'vin';
  }
  for (var i = 1; i < shots.length; i++) {
    final out = 'x$i';
    final t = transIn(i);
    if (t == 0) {
      f.write('[$acc][v$i]concat=n=2:v=1:a=0[$out];');
    } else {
      f.write(
        '[$acc][v$i]xfade=transition=${xfadeName(shots[i].transition)}:'
        'duration=${n3(t)}:offset=${n3(shots[i].startSec)}[$out];',
      );
    }
    acc = out;
  }
  final grade = plan.grade;
  f.write(
    grade == null || grade.isNeutral
        ? '[$acc]null[vc];'
        : '[$acc]${gradeFilter(grade)}[vc];',
  );
  f.write('${audioInputs}concat=n=${shots.length}:v=0:a=1[ac]');

  // Music layer: looped, trimmed to the video, faded out, and ducked under
  // speech (sidechain compression driven by the clips' own audio).
  var audioOut = 'ac';
  final music = plan.music;
  if (music != null) {
    final mi = usedClipIds.length + (logoIdx == null ? 0 : 1);
    final total = plan.durationSec;
    // No -stream_loop: in FFmpeg 7/8 a loop that restarts after the output
    // has finished deadlocks in cleanup (seen on iOS: the MP4 is written but
    // the render never returns). A short song is repeated as extra inputs
    // and joined instead; each copy simply ends.
    final needed = music.offsetSec + total;
    final songSec = musicDurationSec;
    final copies = songSec == null || songSec <= 0 || songSec >= needed - 0.01
        ? 1
        : (needed / songSec).ceil();
    for (var k = 0; k < copies; k++) {
      args.addAll(['-i', music.path]);
    }
    final song = copies == 1
        ? '[$mi:a]'
        : '${[for (var k = 0; k < copies; k++) '[${mi + k}:a]'].join()}'
              'concat=n=$copies:v=0:a=1,';
    final fade = music.fadeOutSec.clamp(0.0, total).toDouble();
    f.write(
      ';${song}atrim=start=${music.offsetSec.toStringAsFixed(3)}:duration=${total.toStringAsFixed(3)},'
      'asetpts=PTS-STARTPTS,aresample=44100,aformat=channel_layouts=stereo,'
      'volume=${music.volume.toStringAsFixed(2)}'
      '${music.fadeInSec > 0 ? ',afade=t=in:st=0:d=${music.fadeInSec.clamp(0.0, total).toStringAsFixed(3)}' : ''}'
      '${fade > 0 ? ',afade=t=out:st=${(total - fade).toStringAsFixed(3)}:d=${fade.toStringAsFixed(3)}' : ''}'
      '[mus]',
    );
    f.write(
      ';[ac]asplit=2[dlg][key]'
      ';[mus][key]sidechaincompress=threshold=0.04:ratio=6:attack=20:release=350[duck]'
      ';[dlg][duck]amix=inputs=2:duration=first:normalize=0[amix]',
    );
    audioOut = 'amix';
  }

  var last = 'vc';
  if (logo != null && logoIdx != null) {
    final start = (plan.durationSec - logo.durationSec).clamp(0.0, 1e6);
    final fade = logo.fadeSec > 0
        ? ',fade=t=in:st=0:d=${n3(logo.fadeSec)}:alpha=1'
        : '';
    f.write(
      ';[$logoIdx:v]format=rgba,scale=${(w * logo.scale).round() ~/ 2 * 2}:-2'
      '$fade,trim=duration=${n3(logo.durationSec)},'
      'setpts=PTS-STARTPTS+${n3(start)}/TB[logo]'
      ";[$last][logo]overlay=x=(W-w)/2:y=(H-h)/2:format=auto:"
      "enable='between(t,${n3(start)},${n3(plan.durationSec)})'[vlogo]",
    );
    last = 'vlogo';
  }
  for (final (i, c) in plan.captions.indexed) {
    final out = 'vcap$i';
    f.write(
      ';[$last]drawtext=fontfile=$fontPath:textfile=${textFile('cap$i', c.text)}:'
      'expansion=none:fontsize=${(h * 0.034).round()}:'
      'fontcolor=white:box=1:boxcolor=black@0.6:boxborderw=${(h * 0.012).round()}:'
      "x=(w-text_w)/2:y=h*0.78:enable='between(t,${c.startSec.toStringAsFixed(2)},${c.endSec.toStringAsFixed(2)})'"
      '[$out]',
    );
    last = out;
  }

  args
    ..addAll(['-filter_complex', f.toString()])
    ..addAll(['-map', '[$last]', '-map', '[$audioOut]'])
    ..addAll([
      '-c:v',
      videoEncoder,
      '-b:v',
      '${ExportPreset.of(resolution).videoBitrate}',
    ])
    ..addAll(['-pix_fmt', 'yuv420p', '-r', '$fps'])
    ..addAll([
      '-c:a',
      'aac',
      '-b:a',
      '${ExportPreset.of(resolution).audioBitrate}',
    ])
    ..addAll(['-t', plan.durationSec.toStringAsFixed(3)])
    ..addAll(['-movflags', '+faststart', outputPath]);

  return RenderArgs(
    args: args,
    totalSec: plan.durationSec,
    textFiles: textFiles,
  );
}

/// Colour look as one LGPL-only filter chain: exposure + contrast on luma
/// (`lutyuv`), saturation (`hue`), warm/cool balance (`colorbalance`).
String gradeFilter(ColorGrade g) {
  String n(double v) => v.toStringAsFixed(3);
  final parts = <String>[];
  if (g.exposure != 0 || g.contrast != 1) {
    parts.add(
      "lutyuv=y='clip((val-128)*${n(g.contrast)}+128+${n(g.exposure * 100)},16,235)'",
    );
  }
  if (g.saturation != 1) parts.add('hue=s=${n(g.saturation)}');
  if (g.temperature != 0) {
    final t = g.temperature;
    parts.add(
      'colorbalance=rs=${n(0.12 * t)}:bs=${n(-0.12 * t)}:'
      'rm=${n(0.2 * t)}:bm=${n(-0.2 * t)}:'
      'rh=${n(0.1 * t)}:bh=${n(-0.1 * t)}',
    );
  }
  return parts.join(',');
}

/// FFmpeg `xfade` transition names.
String xfadeName(ShotTransition t) => switch (t) {
  ShotTransition.crossfade => 'fade',
  ShotTransition.fadeBlack => 'fadeblack',
  ShotTransition.slide => 'slideleft',
  ShotTransition.zoom => 'zoomin',
  ShotTransition.cut => 'fade',
};

/// `atempo` accepts 0.5–2.0 per stage, so larger changes are chained.
String atempoChain(double speed) {
  if (speed == 1.0) return '';
  final parts = <String>[];
  var s = speed;
  while (s > 2.0) {
    parts.add('atempo=2.0');
    s /= 2.0;
  }
  while (s < 0.5) {
    parts.add('atempo=0.5');
    s /= 0.5;
  }
  parts.add('atempo=${s.toStringAsFixed(4)}');
  return parts.join(',');
}

/// Camera-style motion on video (oversample 20% so zooming stays sharp).
String motionFilter(ShotMotion m, int w, int h, int fps) {
  if (m == ShotMotion.none) return '';
  final ow = (w * 1.2).round() ~/ 2 * 2;
  final oh = (h * 1.2).round() ~/ 2 * 2;
  final z = m == ShotMotion.punchIn
      ? "if(lt(on,9),1.2-0.022*on,1.0)" // quick punch that settles in 0.3 s
      : 'min(1.0+on*0.0015,1.18)'; // slow push-in
  return ',scale=$ow:$oh,'
      "zoompan=z='$z':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=${w}x$h:fps=$fps";
}
