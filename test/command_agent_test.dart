import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/plan/command_agent.dart';

Map<String, dynamic> _plan({bool music = false, bool logo = false}) => {
  'schemaVersion': 1,
  'title': 'T',
  'summary': 'S',
  'durationSec': 20,
  'aspectRatio': '16:9',
  'shots': [
    for (var i = 0; i < 5; i++)
      {
        'id': 's${i + 1}',
        'startSec': i * 4,
        'endSec': i * 4 + 4,
        'description': 'Kadr ${i + 1}',
        'sourceClipId': 'clip_01',
        'sourceIn': i * 4,
        'sourceOut': i * 4 + 4,
      },
  ],
  'mediaSlots': <Map<String, dynamic>>[],
  'captions': <Map<String, dynamic>>[],
  'audioTracks': <Map<String, dynamic>>[],
  'export': {'resolution': '1080p', 'fps': 30},
  if (music)
    'music': {
      'path': '/tmp/m.mp3',
      'name': 'm',
      'volume': 0.5,
      'beats': [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0],
    },
  if (logo) 'logo': {'clipId': 'clip_02', 'durationSec': 2},
};

const _agent = CommandAgent();
AgentResult _run(
  String s, {
  Map<String, dynamic>? plan,
  double t = 0,
  String? sel,
}) => _agent.run(s, plan ?? _plan(), playheadSec: t, selectedShotId: sel);
EditPlan _p(AgentResult r) => EditPlan.fromJson(r.plan);

void main() {
  test('no-op commands never report changes', () {
    final r = _run('16:9 qil va 30 fps');
    expect(r.changed, isFalse);
    expect(r.done, isEmpty);
    expect(r.unhandled, hasLength(2));
  });

  test(
    'validation rollback removes success evidence for the failed operation',
    () {
      final plan = _plan(logo: true);
      plan['shots'] = [(plan['shots'] as List).first];
      (plan['shots'] as List).first['endSec'] = 5;
      (plan['shots'] as List).first['sourceOut'] = 5;
      plan['durationSec'] = 5;
      (plan['logo'] as Map)['durationSec'] = 5;
      EditPlan.fromJson(plan);
      final r = _run('hookni kuchaytir', plan: plan);
      expect(r.changed, isFalse);
      expect(r.done, isEmpty);
      expect(r.plan, plan);
      expect(r.unhandled.single, contains('bajarib bo‘lmadi'));
    },
  );

  group('duration', () {
    test('"Videoni 12 soniyaga qisqartir" really fits the timeline', () {
      final r = _run('Videoni 12 soniyaga qisqartir');
      expect(r.changed, isTrue);
      expect(_p(r).durationSec, closeTo(12, 0.2));
      expect(r.done.single, contains('12'));
    });

    test('"30 soniya qil" on a 20 s video does not pretend to lengthen', () {
      final r = _run('Videoni 30 soniyaga qil');
      expect(r.changed, isFalse);
      expect(r.unhandled.single, contains('uzaytirish'));
      expect(_p(r).durationSec, 20);
    });

    test('percent and half', () {
      expect(_p(_run('25% qisqartir')).durationSec, closeTo(15, 0.3));
      expect(_p(_run('yarmiga qisqartir')).durationSec, closeTo(10, 0.3));
    });

    test('very tight target drops trailing shots instead of breaking', () {
      final r = _run('Videoni 2 soniyaga qisqartir');
      final p = _p(r);
      expect(p.durationSec, closeTo(2, 0.2));
      expect(r.done.single, contains('olib tashlandi'));
    });
  });

  group('shots', () {
    test('delete last / third / selected shot', () {
      expect(_p(_run('oxirgi kadrni o‘chir')).shots.length, 4);
      final third = _p(_run('3-kadrni o‘chir'));
      expect(third.shots.map((s) => s.id), isNot(contains('s3')));
      final sel = _p(_run('tanlangan kadrni olib tashla', sel: 's2'));
      expect(sel.shots.map((s) => s.id), isNot(contains('s2')));
    });

    test('nonexistent shot is reported, not silently ignored', () {
      final r = _run('9-kadrni o‘chir');
      expect(r.changed, isFalse);
      expect(r.unhandled.join(), contains('yo‘q'));
    });

    test('split at playhead and refuse in the middle of nothing', () {
      final ok = _run('kadrni ikkiga bo‘l', t: 2);
      expect(_p(ok).shots.length, 6);
      final edge = _run('kadrni ikkiga bo‘l', t: 4.1);
      expect(edge.changed, isFalse);
      expect(edge.unhandled, isNotEmpty);
    });

    test('speed: whole video and one shot, slow-mo', () {
      final all = _p(_run('videoni 2x tezlashtir'));
      expect(all.shots.every((s) => s.speed == 2), isTrue);
      expect(all.durationSec, closeTo(10, 0.3));
      final one = _p(_run('2-kadrni sekinlashtir'));
      expect(one.shots[1].speed, 0.5);
      expect(one.shots[0].speed, 1);
    });

    test('hook strengthens the first shot', () {
      final p = _p(_run('Birinchi uch soniyani kuchliroq qil'));
      expect(p.shots.first.motion, ShotMotion.punchIn);
      expect(p.shots.first.duration, lessThanOrEqualTo(2.5));
    });
  });

  group('look', () {
    test('kino, qora-oq and removal', () {
      expect(_p(_run('kino uslubini ber')).grade, isNotNull);
      expect(_p(_run('qora-oq qil')).grade!.saturation, 0);
      final base = _run('iliq uslub').plan;
      final off = _p(_agent.run('rang uslubini olib tashla', base));
      expect(off.grade, isNull);
    });

    test('incremental colour tweaks accumulate and stay in range', () {
      var r = _run('yorqinroq qil');
      r = _agent.run('yorqinroq qil', r.plan);
      expect(_p(r).grade!.exposure, closeTo(0.16, 1e-6));
      for (var i = 0; i < 30; i++) {
        r = _agent.run('kontrastni oshir', r.plan);
      }
      expect(_p(r).grade!.contrast, 2);
    });

    test('transitions and motion', () {
      final t = _p(_run('hamma kadrga crossfade qo‘sh'));
      expect(
        t.shots.skip(1).every((s) => s.transition == ShotTransition.crossfade),
        isTrue,
      );
      final z = _p(_run('sekin zoom qo‘sh'));
      expect(z.shots.every((s) => s.motion == ShotMotion.slowZoom), isTrue);
    });
  });

  group('audio', () {
    test('lower and raise music, set percent, remove', () {
      final low = _p(_run('musiqani pasaytir', plan: _plan(music: true)));
      expect(low.music!.volume, lessThan(0.5));
      final pct = _p(_run('musiqa ovozini 20% qil', plan: _plan(music: true)));
      expect(pct.music!.volume, closeTo(0.2, 1e-6));
      final gone = _p(_run('musiqani o‘chir', plan: _plan(music: true)));
      expect(gone.music, isNull);
    });

    test('music commands without music explain what is missing', () {
      final r = _run('musiqani pasaytir');
      expect(r.changed, isFalse);
      expect(r.unhandled.single, contains('Musiqa yo‘q'));
    });

    test('beat sync needs beats and then really moves cuts', () {
      expect(_run('ritmga mosla').changed, isFalse);
      final r = _run('ritmga mosla', plan: _plan(music: true));
      expect(r.changed, isTrue);
    });

    test('original sound off', () {
      final p = _p(_run('asl ovozni o‘chir'));
      expect(p.shots.every((s) => s.volume == 0), isTrue);
    });
  });

  group('text, format, export', () {
    test('caption from quotes and from colon, at the end', () {
      final q = _p(
        _run('Oxirida "Hoziroq buyurtma bering, 20% chegirma" chiqar'),
      );
      expect(q.captions.single.text, 'Hoziroq buyurtma bering, 20% chegirma');
      expect(q.captions.single.endSec, closeTo(20, 0.05));
      final c = _p(_run('subtitr qo‘sh: Salom va xush kelibsiz', t: 3));
      expect(c.captions.single.text, 'Salom va xush kelibsiz');
      expect(c.captions.single.startSec, 3);
    });

    test('caption without text asks for it', () {
      final r = _run('subtitr qo‘sh');
      expect(r.changed, isFalse);
      expect(r.unhandled.single, contains('Matn'));
    });

    test('format, fps, resolution in one message', () {
      final r = _run('9:16 qil, 60 fps va 4K eksport qil');
      final p = _p(r);
      expect(p.aspectRatio, '9:16');
      expect(p.export.fps, 60);
      expect(p.export.resolution, '4K');
      expect(r.done.length, 3);
    });

    test('vertical word and logo guidance', () {
      expect(_p(_run('vertikal qil')).aspectRatio, '9:16');
      final r = _run('oxirida logotip chiqar');
      expect(r.changed, isFalse);
      expect(r.unhandled.single, contains('Logotip rasmi'));
      final had = _run('oxirida logotip chiqar', plan: _plan(logo: true));
      expect(had.changed, isFalse);
      expect(had.done, isEmpty);
      expect(had.understoodAnything, isTrue);
    });

    test('shortening keeps the logo valid', () {
      final p = _p(
        _run('Videoni 1 soniyaga qisqartir', plan: _plan(logo: true)),
      );
      expect(p.logo!.durationSec, lessThanOrEqualTo(p.durationSec));
    });
  });

  group('multi-command and safety', () {
    test('several commands run in order and report each', () {
      final r = _run(
        'Videoni 15 soniyaga qisqartir, kino uslubini ber va 9:16 qil',
        plan: _plan(music: true),
      );
      expect(r.done.length, 3);
      final p = _p(r);
      expect(p.durationSec, closeTo(15, 0.3));
      expect(p.grade, isNotNull);
      expect(p.aspectRatio, '9:16');
    });

    test(
      'partly understood message applies what it can and lists the rest',
      () {
        final r = _run('kino uslubini ber va xonanda qo‘shiq aytsin');
        expect(r.done.length, 1);
        expect(r.unhandled.single, contains('tushunmadim'));
      },
    );

    test('gibberish changes nothing and says so', () {
      final r = _run('asdf qwerty');
      expect(r.changed, isFalse);
      expect(r.understoodAnything, isFalse);
      expect(r.unhandled, isNotEmpty);
    });

    test('undo is requested, not faked', () {
      final r = _run('oxirgi o‘zgarishni bekor qil');
      expect(r.wantsUndo, isTrue);
      expect(r.changed, isFalse);
    });

    test('input plan is never mutated', () {
      final base = _plan();
      final before = base.toString();
      _agent.run('videoni 10 soniyaga qisqartir va kino uslubi', base);
      expect(base.toString(), before);
    });

    test('professional macro applies several real changes', () {
      final r = _run('Professional qil', plan: _plan(music: true));
      final p = _p(r);
      expect(r.changed, isTrue);
      expect(p.grade, isNotNull);
      expect(p.shots.first.transition, ShotTransition.fadeBlack);
      expect(p.shots[2].transition, ShotTransition.crossfade);
    });
  });
}
