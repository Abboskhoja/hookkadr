import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/projects/project.dart';
import 'package:hookkadr/features/plan/auto_editor.dart';
import 'package:hookkadr/features/plan/plan_ops.dart';
import 'package:hookkadr/features/render/beat_detector.dart';
import 'package:hookkadr/features/render/media_analyzer.dart';
import 'package:hookkadr/features/render/render_service.dart';
import 'package:hookkadr/features/render/thumbnailer.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders a real MP4 from a plan with clip, card and caption', (
    tester,
  ) async {
    final dir = await getTemporaryDirectory();
    final clipPath = '${dir.path}/src_clip.mp4';
    if (File(clipPath).existsSync()) File(clipPath).deleteSync();

    // Source clip: 5 s test pattern with a tone (so audio mapping is exercised).
    final enc = Platform.isIOS ? 'h264_videotoolbox' : 'h264_mediacodec';
    final gen = await FFmpegKit.executeWithArguments([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc=size=640x360:rate=30:duration=5',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=5',
      '-c:v',
      enc,
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-shortest',
      clipPath,
    ]);
    expect(
      ReturnCode.isSuccess(await gen.getReturnCode()),
      isTrue,
      reason: await gen.getAllLogsAsString(),
    );

    final plan = EditPlan.fromJson({
      'schemaVersion': 1,
      'title': 'Test',
      'summary': 's',
      'durationSec': 6,
      'aspectRatio': '9:16',
      'shots': [
        {
          'id': 's1',
          'startSec': 0,
          'endSec': 2,
          'description': 'Kirish',
          'sourceClipId': 'clip_01',
          'sourceIn': 1,
          'sourceOut': 3,
        },
        {
          'id': 's2',
          'startSec': 2,
          'endSec': 4,
          'description': "Karta: o'rta, 50%",
          'mediaSlotId': 'm1',
        },
        {
          'id': 's3',
          'startSec': 4,
          'endSec': 6,
          'description': 'Oxiri',
          'sourceClipId': 'clip_01',
          'sourceIn': 0,
          'sourceOut': 2,
        },
      ],
      'mediaSlots': [
        {'id': 'm1', 'kind': 'video', 'description': 'B-roll'},
      ],
      'captions': [
        {'startSec': 0.5, 'endSec': 1.8, 'text': "Salom, dunyo: 100%"},
      ],
      'audioTracks': <Map<String, dynamic>>[],
      'export': {'resolution': '720p', 'fps': 30},
    });

    var lastProgress = 0.0;
    final out = await RenderService().render(
      plan: plan,
      clips: [ProjectClip(id: 'clip_01', path: clipPath, name: 'src_clip.mp4')],
      resolution: '720p',
      name: 'itest',
      onProgress: (p) => lastProgress = p,
    );

    expect(File(out).existsSync(), isTrue);
    expect(File(out).lengthSync(), greaterThan(1000));

    final info = await FFprobeKit.getMediaInformation(out);
    final media = info.getMediaInformation()!;
    final duration = double.parse(media.getDuration()!);
    expect(duration, closeTo(6.0, 0.6));
    final streams = media.getStreams();
    final video = streams.firstWhere((s) => s.getType() == 'video');
    expect(video.getWidth(), 720);
    expect(video.getHeight(), 1280);
    expect(streams.any((s) => s.getType() == 'audio'), isTrue);
    expect(lastProgress, 1.0);
  });

  testWidgets('renders AI-image slideshow (stills + zoom + caption) to MP4', (
    tester,
  ) async {
    final dir = await getTemporaryDirectory();
    final img1 = '${dir.path}/scene1.png';
    final img2 = '${dir.path}/scene2.png';
    for (final (p, src) in [
      (img1, 'testsrc=size=800x800'),
      (img2, 'smptebars=size=800x800'),
    ]) {
      if (File(p).existsSync()) File(p).deleteSync();
      final g = await FFmpegKit.executeWithArguments([
        '-y',
        '-f',
        'lavfi',
        '-i',
        src,
        '-frames:v',
        '1',
        p,
      ]);
      expect(
        ReturnCode.isSuccess(await g.getReturnCode()),
        isTrue,
        reason: await g.getAllLogsAsString(),
      );
    }
    final plan = EditPlan.fromJson({
      'schemaVersion': 1,
      'title': 'Slayd',
      'summary': 's',
      'durationSec': 6,
      'aspectRatio': '9:16',
      'shots': [
        {
          'id': 's1',
          'startSec': 0,
          'endSec': 3,
          'description': 'a',
          'sourceClipId': 'clip_01',
          'sourceIn': 0,
          'sourceOut': 3,
        },
        {
          'id': 's2',
          'startSec': 3,
          'endSec': 6,
          'description': 'b',
          'sourceClipId': 'clip_02',
          'sourceIn': 0,
          'sourceOut': 3,
        },
      ],
      'mediaSlots': <Map<String, dynamic>>[],
      'captions': [
        {'startSec': 0.5, 'endSec': 2.5, 'text': 'Bugun keling!'},
      ],
      'audioTracks': <Map<String, dynamic>>[],
      'export': {'resolution': '720p', 'fps': 30},
    });
    final out = await RenderService().render(
      plan: plan,
      clips: [
        ProjectClip(id: 'clip_01', path: img1, name: 'AI rasm 1'),
        ProjectClip(id: 'clip_02', path: img2, name: 'AI rasm 2'),
      ],
      resolution: '720p',
      name: 'slideshow',
    );
    final media = (await FFprobeKit.getMediaInformation(out))
        .getMediaInformation()!;
    expect(double.parse(media.getDuration()!), closeTo(6.0, 0.6));
    final v = media.getStreams().firstWhere((s) => s.getType() == 'video');
    expect(v.getWidth(), 720);
    expect(v.getHeight(), 1280);
  });

  testWidgets('quick montage: analyse clip, auto-edit, render — no AI needed', (
    tester,
  ) async {
    final dir = await getTemporaryDirectory();
    final clip = '${dir.path}/scenes_clip.mp4';
    if (File(clip).existsSync()) File(clip).deleteSync();
    final enc = Platform.isIOS ? 'h264_videotoolbox' : 'h264_mediacodec';
    // 6 s: red / test pattern / blue (2 scene cuts), tone with a 1 s pause at 2.5–3.5 s.
    final gen = await FFmpegKit.executeWithArguments([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'color=c=red:s=640x360:r=30:d=2',
      '-f',
      'lavfi',
      '-i',
      'testsrc=size=640x360:rate=30:duration=2',
      '-f',
      'lavfi',
      '-i',
      'color=c=blue:s=640x360:r=30:d=2',
      '-f',
      'lavfi',
      '-i',
      "aevalsrc='if(between(t,2.5,3.5),0,0.5*sin(2*PI*440*t))':s=44100:d=6",
      '-filter_complex',
      '[0:v][1:v][2:v]concat=n=3:v=1:a=0[v]',
      '-map',
      '[v]',
      '-map',
      '3:a',
      '-c:v',
      enc,
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-shortest',
      clip,
    ]);
    expect(
      ReturnCode.isSuccess(await gen.getReturnCode()),
      isTrue,
      reason: await gen.getAllLogsAsString(),
    );

    final facts = await MediaAnalyzer().analyze('clip_01', clip);
    // ignore: avoid_print
    print('FACTS: ${facts.hint}');
    expect(facts.hasAudio, isTrue);
    expect(
      facts.sceneCuts.where((c) => (c - 2).abs() < 0.3 || (c - 4).abs() < 0.3),
      isNotEmpty,
    );
    expect(facts.silences.any((s) => s.start < 3 && s.end > 3), isTrue);

    final planJson = AutoEditor.build(
      clips: [facts],
      targetSec: 15,
      aspectRatio: '9:16',
      resolution: '720p',
      title: 'Avto',
    );
    final plan = EditPlan.fromJson(planJson);
    final out = await RenderService().render(
      plan: plan,
      clips: [ProjectClip(id: 'clip_01', path: clip, name: 'scenes_clip.mp4')],
      resolution: '720p',
      name: 'auto',
    );
    final media = (await FFprobeKit.getMediaInformation(out))
        .getMediaInformation()!;
    expect(double.parse(media.getDuration()!), closeTo(plan.durationSec, 0.6));
    final v = media.getStreams().firstWhere((s) => s.getType() == 'video');
    expect(v.getWidth(), 720);
    expect(v.getHeight(), 1280);
  });

  testWidgets(
    'music: beats detected on device, cuts snapped, ducked mix rendered',
    (tester) async {
      final dir = await getTemporaryDirectory();
      final song = '${dir.path}/click120.m4a';
      final clip = '${dir.path}/music_clip.mp4';
      for (final p in [song, clip]) {
        if (File(p).existsSync()) File(p).deleteSync();
      }
      final enc = Platform.isIOS ? 'h264_videotoolbox' : 'h264_mediacodec';
      // 20 s click track at 120 BPM (a 30 ms 1 kHz tick every 0.5 s).
      final g1 = await FFmpegKit.executeWithArguments([
        '-y',
        '-f',
        'lavfi',
        '-i',
        "aevalsrc='0.8*sin(2*PI*1000*t)*lt(mod(t,0.5),0.03)':s=44100:d=20",
        '-c:a',
        'aac',
        song,
      ]);
      expect(ReturnCode.isSuccess(await g1.getReturnCode()), isTrue);
      final g2 = await FFmpegKit.executeWithArguments([
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc=size=640x360:rate=30:duration=8',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=300:duration=8',
        '-c:v',
        enc,
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-shortest',
        clip,
      ]);
      expect(ReturnCode.isSuccess(await g2.getReturnCode()), isTrue);

      final beats = await BeatDetector.analyzeFile(song);
      // ignore: avoid_print
      print('BEATS: bpm=${beats.bpm} first=${beats.beats.take(4).toList()}');
      expect(beats.bpm, closeTo(120, 5));

      var planJson = <String, dynamic>{
        'schemaVersion': 1,
        'title': 'Ritm',
        'summary': 's',
        'durationSec': 6.0,
        'aspectRatio': '9:16',
        'shots': [
          {
            'id': 's1',
            'startSec': 0.0,
            'endSec': 2.3,
            'description': 'a',
            'sourceClipId': 'clip_01',
            'sourceIn': 0.0,
            'sourceOut': 2.3,
          },
          {
            'id': 's2',
            'startSec': 2.3,
            'endSec': 6.0,
            'description': 'b',
            'sourceClipId': 'clip_01',
            'sourceIn': 3.0,
            'sourceOut': 6.7,
          },
        ],
        'mediaSlots': <Map<String, dynamic>>[],
        'captions': <Map<String, dynamic>>[],
        'audioTracks': <Map<String, dynamic>>[],
        'export': {'resolution': '720p', 'fps': 30},
      };
      planJson = PlanOps.setMusic(planJson, {
        'path': song,
        'name': 'click',
        'volume': 0.5,
        'beats': beats.beats,
      });
      planJson = PlanOps.snapToBeats(planJson, beats.beats);
      final plan = EditPlan.fromJson(planJson);
      // the first cut moved from 2.3 s onto a beat (multiples of 0.5 s)
      final cut = plan.shots.first.endSec;
      expect(
        (cut * 2 - (cut * 2).round()).abs(),
        lessThan(0.1),
        reason: 'cut=$cut',
      );

      final out = await RenderService().render(
        plan: plan,
        clips: [ProjectClip(id: 'clip_01', path: clip, name: 'music_clip.mp4')],
        resolution: '720p',
        name: 'music',
      );
      final media = (await FFprobeKit.getMediaInformation(out))
          .getMediaInformation()!;
      expect(
        double.parse(media.getDuration()!),
        closeTo(plan.durationSec, 0.6),
      );
      expect(media.getStreams().any((s) => s.getType() == 'audio'), isTrue);
    },
  );

  testWidgets(
    'effects: zoom-punch, 2x speed, crossfade, slide, fade-in render',
    (tester) async {
      final dir = await getTemporaryDirectory();
      final clip = '${dir.path}/fx_clip.mp4';
      if (File(clip).existsSync()) File(clip).deleteSync();
      final enc = Platform.isIOS ? 'h264_videotoolbox' : 'h264_mediacodec';
      final g = await FFmpegKit.executeWithArguments([
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc=size=640x360:rate=30:duration=12',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=12',
        '-c:v',
        enc,
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-shortest',
        clip,
      ]);
      expect(ReturnCode.isSuccess(await g.getReturnCode()), isTrue);

      final plan = EditPlan.fromJson({
        'schemaVersion': 1,
        'title': 'FX',
        'summary': 's',
        'durationSec': 7.5,
        'aspectRatio': '9:16',
        'shots': [
          {
            'id': 's1',
            'startSec': 0,
            'endSec': 2.5,
            'description': 'a',
            'sourceClipId': 'clip_01',
            'sourceIn': 0,
            'sourceOut': 2.5,
            'transition': 'fadeBlack',
            'transitionSec': 0.4,
            'motion': 'punchIn',
          },
          {
            'id': 's2',
            'startSec': 2.5,
            'endSec': 5,
            'description': 'b',
            'sourceClipId': 'clip_01',
            'sourceIn': 3,
            'sourceOut': 8,
            'transition': 'crossfade',
            'transitionSec': 0.5,
            'speed': 2.0,
          },
          {
            'id': 's3',
            'startSec': 5,
            'endSec': 7.5,
            'description': 'c',
            'sourceClipId': 'clip_01',
            'sourceIn': 8,
            'sourceOut': 10.5,
            'transition': 'slide',
            'transitionSec': 0.4,
            'motion': 'slowZoom',
          },
        ],
        'mediaSlots': <Map<String, dynamic>>[],
        'captions': [
          {'startSec': 5.2, 'endSec': 7.0, 'text': 'Oxirgi kadr'},
        ],
        'audioTracks': <Map<String, dynamic>>[],
        'export': {'resolution': '720p', 'fps': 30},
      });
      final out = await RenderService().render(
        plan: plan,
        clips: [ProjectClip(id: 'clip_01', path: clip, name: 'fx_clip.mp4')],
        resolution: '720p',
        name: 'fx',
      );
      final media = (await FFprobeKit.getMediaInformation(out))
          .getMediaInformation()!;
      final dur = double.parse(media.getDuration()!);
      // ignore: avoid_print
      print('FX DURATION: $dur');
      expect(dur, closeTo(7.5, 0.4)); // transitions do not shorten the video
      final v = media.getStreams().firstWhere((s) => s.getType() == 'video');
      expect(v.getWidth(), 720);
      expect(v.getHeight(), 1280);
      expect(media.getStreams().any((s) => s.getType() == 'audio'), isTrue);
    },
  );

  testWidgets('thumbnails come from FFmpeg (no extra plugin)', (tester) async {
    final dir = await getTemporaryDirectory();
    final clip = '${dir.path}/thumb_src.mp4';
    if (File(clip).existsSync()) File(clip).deleteSync();
    final enc = Platform.isIOS ? 'h264_videotoolbox' : 'h264_mediacodec';
    final g = await FFmpegKit.executeWithArguments([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc=size=640x360:rate=30:duration=2',
      '-c:v',
      enc,
      '-pix_fmt',
      'yuv420p',
      clip,
    ]);
    expect(ReturnCode.isSuccess(await g.getReturnCode()), isTrue);
    final jpg = await Thumbnailer.jpeg(clip);
    expect(jpg, isNotNull);
    expect(jpg!.sublist(0, 2), [0xFF, 0xD8]); // JPEG magic
  });

  testWidgets('freeze frame renders and waveform comes from real audio', (
    tester,
  ) async {
    final dir = await getTemporaryDirectory();
    final clip = '${dir.path}/freeze_src.mp4';
    final song = '${dir.path}/wave.m4a';
    for (final p in [clip, song]) {
      if (File(p).existsSync()) File(p).deleteSync();
    }
    final enc = Platform.isIOS ? 'h264_videotoolbox' : 'h264_mediacodec';
    final g = await FFmpegKit.executeWithArguments([
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc=size=640x360:rate=30:duration=6',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=500:duration=6',
      '-c:v',
      enc,
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-shortest',
      clip,
    ]);
    expect(ReturnCode.isSuccess(await g.getReturnCode()), isTrue);
    // quiet first half, loud second half
    final g2 = await FFmpegKit.executeWithArguments([
      '-y',
      '-f',
      'lavfi',
      '-i',
      "aevalsrc='if(lt(t,2),0.01,0.8)*sin(2*PI*300*t)':s=44100:d=4",
      '-c:a',
      'aac',
      song,
    ]);
    expect(ReturnCode.isSuccess(await g2.getReturnCode()), isTrue);

    final env = (await BeatDetector.analyzeFile(song)).envelope;
    expect(env.length, closeTo(40, 3));
    expect(env.sublist(0, 15).every((v) => v < 0.1), isTrue);
    expect(env.sublist(25, 38).every((v) => v > 0.7), isTrue);

    final planJson = PlanOps.insertFreezeFrame({
      'schemaVersion': 1,
      'title': 'Freeze',
      'summary': 's',
      'durationSec': 4.0,
      'aspectRatio': '9:16',
      'shots': [
        {
          'id': 's1',
          'startSec': 0.0,
          'endSec': 4.0,
          'description': 'a',
          'sourceClipId': 'clip_01',
          'sourceIn': 0.0,
          'sourceOut': 4.0,
        },
      ],
      'mediaSlots': <Map<String, dynamic>>[],
      'captions': <Map<String, dynamic>>[],
      'audioTracks': <Map<String, dynamic>>[],
      'export': {'resolution': '720p', 'fps': 30},
    }, 2.0)!;
    final plan = EditPlan.fromJson(planJson);
    final out = await RenderService().render(
      plan: plan,
      clips: [ProjectClip(id: 'clip_01', path: clip, name: 'freeze_src.mp4')],
      resolution: '720p',
      name: 'freeze',
    );
    final media = (await FFprobeKit.getMediaInformation(out))
        .getMediaInformation()!;
    expect(
      double.parse(media.getDuration()!),
      closeTo(5.0, 0.4),
    ); // 4 s + 1 s freeze
  });
}
