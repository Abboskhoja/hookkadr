import 'dart:convert';

import '../analysis/domain/edit_plan.dart';
import 'plan_ops.dart';

/// What [CommandAgent] did with a user message.
class AgentResult {
  const AgentResult({
    required this.plan,
    required this.done,
    required this.unhandled,
    this.wantsUndo = false,
    this.recognized = false,
  });

  /// The edited plan (equals the input when nothing was applied).
  final Map<String, dynamic> plan;

  /// One honest sentence per change that was really applied.
  final List<String> done;

  /// Parts of the message that could not be executed, with the reason.
  final List<String> unhandled;

  /// The user asked to undo the last change; the editor owns the history.
  final bool wantsUndo;
  final bool recognized;

  bool get changed => done.isNotEmpty;
  bool get understoodAnything => recognized || changed || wantsUndo;
}

/// Kadr AI's offline "hands": turns Uzbek editing commands into real
/// [PlanOps] operations on the timeline. Deterministic, instant, no network.
/// It never reports something as done unless the plan actually changed.
class CommandAgent {
  const CommandAgent();

  static const examples = [
    'Videoni 20 soniyaga qisqartir',
    'Kino uslubini ber va musiqani pasaytir',
    '9:16 qil, 1080p eksport',
    'Hamma kadrga crossfade qo‘sh',
    'Oxirgi kadrni o‘chir',
    'Professional qil',
  ];

  AgentResult run(
    String message,
    Map<String, dynamic> plan, {
    double playheadSec = 0,
    String? selectedShotId,
  }) {
    final r = _Run(plan, playheadSec, selectedShotId);
    var recognized = false;
    final protected = <String>[];
    var text = message.trim();

    // Quoted text and everything after a colon is user content (caption
    // text), never commands: hide it from the clause splitter.
    String hide(String s) {
      protected.add(s);
      return '§${protected.length - 1}§';
    }

    text = text.replaceAllMapped(
      RegExp('["«“]([^"»”]+)["»”]'),
      (m) => hide(m[1]!),
    );
    final colon = text.indexOf(':');
    if (colon >= 0 && colon < text.length - 1) {
      final tail = text.substring(colon + 1).trim();
      if (tail.isNotEmpty && !RegExp(r'^\d').hasMatch(tail)) {
        text = '${text.substring(0, colon)} ${hide(tail)}';
      }
    }

    final clauses = text
        .split(
          RegExp(
            r"\s*(?:[.;\n!]|,|\bva\b|\bhamda\b|\bkeyin\b|\bso[’'‘`]?ng\b|\bkeyin esa\b)\s*",
            caseSensitive: false,
          ),
        )
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty);

    for (final raw in clauses) {
      final t = _norm(raw);
      final quoted = RegExp('§(\\d+)§').firstMatch(raw);
      r.text = quoted == null ? null : protected[int.parse(quoted[1]!)];
      var matched = false;
      for (final rule in _rules) {
        final m = rule.$1.firstMatch(t);
        if (m == null) continue;
        final before = r.plan;
        final completedBefore = r.done.length;
        try {
          matched = rule.$2(r, t, m);
          if (matched) EditPlan.fromJson(r.plan); // never keep an invalid plan
          if (matched &&
              r.done.length > completedBefore &&
              jsonEncode(before) == jsonEncode(r.plan)) {
            r.done.removeRange(completedBefore, r.done.length);
            r.plan = before;
            r.unhandled.add('“$raw” — reja allaqachon shu holatda');
          }
        } catch (_) {
          r.plan = before;
          r.done.removeRange(completedBefore, r.done.length);
          r.unhandled.add('“$raw” — bajarib bo‘lmadi');
          matched = true;
        }
        if (matched) break;
      }
      recognized = recognized || matched;
      if (!matched) r.unhandled.add('“$raw” — tushunmadim');
    }
    if (r.done.isNotEmpty && jsonEncode(plan) == jsonEncode(r.plan)) {
      r.done.clear();
      r.unhandled.add('Buyruqlardan keyin reja o‘zgarmadi.');
    }
    return AgentResult(
      plan: r.plan,
      done: r.done,
      unhandled: r.unhandled,
      wantsUndo: r.undo,
      recognized: recognized,
    );
  }

  // ---------------------------------------------------------------- rules

  static final List<(RegExp, bool Function(_Run, String, RegExpMatch))>
  _rules = [
    // Undo
    (
      RegExp(r'\b(bekor qil|orqaga qayt|undo|oxirgi o.zgarishni)'),
      (r, t, m) {
        r.undo = true;
        return true;
      },
    ),
    // Professional macro
    (
      RegExp(
        r'(professional|pro qil|zo.r qil|chiroyli qil|sifatli qil|avto.?montaj|o.zing qil|hammasini qil)',
      ),
      (r, t, m) => r.polish(),
    ),
    // Hook
    (
      RegExp(r'\bhook|boshlanish.*kuchli|birinchi (?:\w+ )?soniya'),
      (r, t, m) {
        final shots = r.typed.shots;
        final first = shots.first;
        r.plan = PlanOps.setMotion(r.plan, first.id, 'punchIn');
        if (first.duration > 2.5) {
          r.plan = PlanOps.resizeShot(r.plan, first.id, 2.5);
        }
        r.done.add(
          'Hook kuchaytirildi: birinchi kadr zoom-punch bilan, ≤2.5 s',
        );
        return true;
      },
    ),
    // Fit duration: "20 soniyaga qisqartir"
    (
      RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(?:soniya|sekund|s\b|sec)\w*\s*(?:ga|gacha|qil|ga qisqartir|bo.lsin)?',
      ),
      (r, t, m) {
        if (!RegExp(r'qisqar|kalta|sig.dir|kes|qil|bo.lsin|gacha')
                .hasMatch(t) ||
            RegExp(r'kadr').hasMatch(t)) {
          return false;
        }
        final target = double.parse(m[1]!.replaceAll(',', '.'));
        return r.fitTo(target);
      },
    ),
    (
      RegExp(r'(\d+)\s*%\s*(?:ga\s*)?qisqar'),
      (r, t, m) {
        final pct = int.parse(m[1]!).clamp(5, 80);
        return r.fitTo(r.total * (1 - pct / 100));
      },
    ),
    (
      RegExp(r'\b(yarmiga|ikki baravar) qisqar'),
      (r, t, m) => r.fitTo(r.total / 2),
    ),
    // Shot delete
    (
      RegExp(r"(o.chir|olib tashla|kes tashla|yo.q qil)"),
      (r, t, m) {
        if (RegExp(r'subtitr|matn|caption').hasMatch(t)) {
          return r.clearCaptions();
        }
        if (RegExp(r'logo').hasMatch(t)) {
          r.plan = PlanOps.setLogo(r.plan, null);
          r.done.add('Logotip olib tashlandi');
          return true;
        }
        if (RegExp(r'musiqa').hasMatch(t)) {
          r.plan = PlanOps.setMusic(r.plan, null);
          r.done.add('Musiqa olib tashlandi');
          return true;
        }
        if (RegExp(r'asl ovoz|ovoz').hasMatch(t)) {
          r.setAllVolume(0);
          r.done.add('Videodagi asl ovoz o‘chirildi');
          return true;
        }
        if (RegExp(r'o.tish').hasMatch(t)) {
          r.plan = PlanOps.setTransition(r.plan, null, 'cut');
          r.done.add('Hamma o‘tishlar oddiy kesishga o‘zgartirildi');
          return true;
        }
        if (RegExp(r'harakat|zoom').hasMatch(t)) {
          r.setAllMotion('none');
          r.done.add('Kamera harakati olib tashlandi');
          return true;
        }
        if (RegExp(r'rang|filtr|uslub').hasMatch(t)) {
          r.plan = PlanOps.setGrade(r.plan, null);
          r.done.add('Rang uslubi olib tashlandi (asl ranglar)');
          return true;
        }
        final ids = r.targets(t, defaultAll: false);
        if (ids.isEmpty) return false;
        var n = 0;
        for (final id in ids) {
          final next = PlanOps.removeShot(r.plan, id);
          if (next == null) {
            r.unhandled.add('Kamida bitta kadr qolishi kerak');
            break;
          }
          r.plan = next;
          n++;
        }
        if (n > 0) r.done.add('$n ta kadr o‘chirildi');
        return n > 0;
      },
    ),
    // Split / duplicate / freeze at the playhead
    (
      RegExp(r"(ikkiga bo.l|bo.l\b|split|qirq|ajrat)"),
      (r, t, m) {
        final next = PlanOps.splitAt(r.plan, r.playhead);
        if (next == null) {
          r.unhandled.add(
            'Kadr bo‘linmadi: pleyhedni kadr o‘rtasiga qo‘ying (har bir bo‘lak ≥0.5 s)',
          );
          return true;
        }
        r.plan = next;
        r.done.add(
          'Kadr ${r.playhead.toStringAsFixed(1)} s da ikkiga bo‘lindi',
        );
        return true;
      },
    ),
    (
      RegExp(r"(nusxa|ikkilantir|takrorla|duplicate)"),
      (r, t, m) {
        final ids = r.targets(t, defaultAll: false);
        if (ids.isEmpty) return false;
        for (final id in ids) {
          r.plan = PlanOps.duplicate(r.plan, id);
        }
        r.done.add('${ids.length} ta kadr nusxalandi');
        return true;
      },
    ),
    (
      RegExp(r"(ushlab tur|to.xtat|freeze|qotir)"),
      (r, t, m) {
        final next = PlanOps.insertFreezeFrame(r.plan, r.playhead);
        if (next == null) {
          r.unhandled.add('Kadr qotmadi: pleyhedni video kadr ustiga qo‘ying');
          return true;
        }
        r.plan = next;
        r.done.add('Kadr 1 soniyaga qotirildi');
        return true;
      },
    ),
    // Speed
    (
      RegExp(
        r'(tezlashtir|tezroq|tez qil|sekinlashtir|sekinroq|sekin qil|slow|tezlik|\d+(?:[.,]\d+)?\s*x\b)',
      ),
      (r, t, m) {
        final slow = RegExp(r'sekin|slow').hasMatch(t);
        final num = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:x|marta|baravar)')
            .firstMatch(t);
        final value = num == null
            ? (slow ? 0.5 : 1.5)
            : double.parse(num[1]!.replaceAll(',', '.'));
        final speed = (slow && num != null && value > 1 ? 1 / value : value)
            .clamp(kMinSpeed, kMaxSpeed)
            .toDouble();
        final ids = r.targets(t, defaultAll: true);
        for (final id in ids) {
          r.plan = PlanOps.setSpeed(r.plan, id, speed);
        }
        r.done.add(
          '${ids.length} ta kadr tezligi ${speed.toStringAsFixed(speed % 1 == 0 ? 0 : 2)}× qilindi',
        );
        return true;
      },
    ),
    // Transitions
    (
      RegExp(
        r'(crossfade|yumshoq o.tish|silliq o.tish|qora orqali|fade|surish|slide|o.tish)',
      ),
      (r, t, m) {
        final name = RegExp(r'qora orqali|fadeblack').hasMatch(t)
            ? 'fadeBlack'
            : RegExp(r'surish|slide').hasMatch(t)
            ? 'slide'
            : RegExp(r'zoom').hasMatch(t)
            ? 'zoom'
            : 'crossfade';
        final ids = r.targets(t, defaultAll: true);
        if (ids.length == r.typed.shots.length) {
          r.plan = PlanOps.setTransition(r.plan, null, name, seconds: 0.5);
          r.done.add('Hamma o‘tishlar “$name” qilindi');
        } else {
          for (final id in ids) {
            r.plan = PlanOps.setTransition(r.plan, id, name, seconds: 0.5);
          }
          r.done.add('${ids.length} ta kadrga “$name” o‘tishi qo‘yildi');
        }
        return true;
      },
    ),
    // Camera motion
    (
      RegExp(r'(zoom|harakat|punch|kamera)'),
      (r, t, m) {
        final mode = RegExp(r'punch|zarba').hasMatch(t)
            ? 'punchIn'
            : 'slowZoom';
        final ids = r.targets(t, defaultAll: true);
        for (final id in ids) {
          r.plan = PlanOps.setMotion(r.plan, id, mode);
        }
        r.done.add(
          '${ids.length} ta kadrga ${mode == 'punchIn' ? 'zoom-punch' : 'sekin zoom'} qo‘shildi',
        );
        return true;
      },
    ),
    // Look
    (
      RegExp(
        r'(kino|iliq uslub|iliq rang|sovuq|jonli|qora.?oq|black|cinematic|uslub)',
      ),
      (r, t, m) {
        ColorGrade? g;
        String label;
        if (RegExp(r'qora.?oq|black').hasMatch(t)) {
          g = const ColorGrade(saturation: 0, contrast: 1.1);
          label = 'qora-oq';
        } else if (RegExp(r'sovuq').hasMatch(t)) {
          g = ColorGrade.presets['sovuq'];
          label = 'sovuq';
        } else if (RegExp(r'jonli').hasMatch(t)) {
          g = ColorGrade.presets['jonli'];
          label = 'jonli';
        } else if (RegExp(r'iliq').hasMatch(t)) {
          g = ColorGrade.presets['iliq'];
          label = 'iliq';
        } else {
          g = ColorGrade.presets['kino'];
          label = 'kino';
        }
        r.plan = PlanOps.setGrade(r.plan, g);
        r.done.add('Rang uslubi “$label” qo‘llandi');
        return true;
      },
    ),
    (
      RegExp(
        r'(yorqin|yorug.roq|ochroq|qoraroq|to.qroq|xira|kontrast|to.yingan|rang(?:lar)?ni|iliqroq|sovuqroq)',
      ),
      (r, t, m) {
        final g = r.typed.grade ?? const ColorGrade();
        double c(double v, double lo, double hi) => v.clamp(lo, hi).toDouble();
        var e = g.exposure, k = g.contrast, s = g.saturation, w = g.temperature;
        final up = !RegExp(r'kamay|pasay|kam|kuchsiz|xira').hasMatch(t);
        final step = up ? 1 : -1;
        final what = <String>[];
        if (RegExp(r'yorqin|yorug.roq|ochroq').hasMatch(t)) {
          e = c(e + 0.08, -0.5, 0.5);
          what.add('yorug‘lik');
        }
        if (RegExp(r'qoraroq|to.qroq').hasMatch(t)) {
          e = c(e - 0.08, -0.5, 0.5);
          what.add('qoraroq');
        }
        if (RegExp(r'kontrast').hasMatch(t)) {
          k = c(k + 0.15 * step, 0.5, 2);
          what.add('kontrast');
        }
        if (RegExp(r'to.yingan|rang(?:lar)?ni|jonliroq').hasMatch(t)) {
          s = c(s + 0.2 * step, 0, 2.5);
          what.add('to‘yinganlik');
        }
        if (RegExp(r'iliqroq').hasMatch(t)) {
          w = c(w + 0.2, -1, 1);
          what.add('iliqroq');
        }
        if (RegExp(r'sovuqroq').hasMatch(t)) {
          w = c(w - 0.2, -1, 1);
          what.add('sovuqroq');
        }
        if (what.isEmpty) return false;
        r.plan = PlanOps.setGrade(
          r.plan,
          ColorGrade(exposure: e, contrast: k, saturation: s, temperature: w),
        );
        r.done.add('Rang sozlandi: ${what.join(', ')}');
        return true;
      },
    ),
    // Music
    (
      RegExp(r'(musiqa|fon|ovoz|volume)'),
      (r, t, m) {
        final music = r.typed.music;
        final asl = RegExp(r'asl ovoz|video ovoz|nutq').hasMatch(t);
        if (asl) {
          final loud = RegExp(r'ko.tar|balandlat|baland|kuchay').hasMatch(t);
          final mute = RegExp(r'o.chir|ovozsiz').hasMatch(t);
          r.setAllVolume(mute ? 0 : (loud ? 1.5 : 0.5));
          r.done.add(
            mute
                ? 'Asl ovoz o‘chirildi'
                : loud
                ? 'Asl ovoz balandlashtirildi'
                : 'Asl ovoz pasaytirildi',
          );
          return true;
        }
        if (music == null) {
          r.unhandled.add(
            'Musiqa yo‘q: avval 🎵 tugmasi bilan musiqa qo‘shing',
          );
          return true;
        }
        final pct = RegExp(r'(\d+)\s*%').firstMatch(t);
        double v;
        String msg;
        if (pct != null) {
          v = int.parse(pct[1]!) / 100;
          msg = 'Musiqa ovozi ${pct[1]}% qilindi';
        } else if (RegExp(r'past|kamay|pasay|sokin|yengil').hasMatch(t)) {
          v = music.volume * 0.6;
          msg = 'Musiqa ovozi pasaytirildi';
        } else if (RegExp(r'baland|ko.tar|kuchay|oshir').hasMatch(t)) {
          v = music.volume * 1.5;
          msg = 'Musiqa ovozi balandlashtirildi';
        } else {
          return false;
        }
        r.plan = PlanOps.setMusicVolume(r.plan, v.clamp(0.0, 1.0).toDouble());
        r.done.add(msg);
        return true;
      },
    ),
    (
      RegExp(r'(ritm|beat|zarb)'),
      (r, t, m) {
        final beats = r.typed.music?.beats ?? const <double>[];
        if (beats.isEmpty) {
          r.unhandled.add(
            'Ritmga moslash uchun musiqa kerak: avval 🎵 bilan musiqa qo‘shing',
          );
          return true;
        }
        r.plan = PlanOps.snapToBeats(r.plan, beats);
        r.done.add('Kesimlar musiqa ritmiga moslashtirildi');
        return true;
      },
    ),
    // Logo
    (
      RegExp(r'logo'),
      (r, t, m) {
        if (r.typed.logo != null) {
          r.done.add(
            'Logotip allaqachon oxirida chiqadi (oxirgi ${r.typed.logo!.durationSec} s)',
          );
          return true;
        }
        r.unhandled.add(
          'Logotip rasmi kerak: 🎨 Ko‘rinish panelidan rasm tanlang — keyin u oxirida chiqadi',
        );
        return true;
      },
    ),
    // Captions
    (
      RegExp(r'(subtitr|matn|yozuv|caption|title|chaqiriq|chiqar)'),
      (r, t, m) {
        final text = r.text;
        if (text == null || text.isEmpty) {
          r.unhandled.add(
            'Matn yozilmagan: masalan — subtitr qo‘sh: "Hoziroq buyurtma bering"',
          );
          return true;
        }
        final total = r.total;
        final atEnd = RegExp(r'oxir').hasMatch(t);
        final atStart = RegExp(r'boshi|boshida|boshlan').hasMatch(t);
        final start = atEnd
            ? (total - 2.5).clamp(0.0, total).toDouble()
            : atStart
            ? 0.0
            : r.playhead.clamp(0.0, (total - 0.5).clamp(0.0, total)).toDouble();
        final end = (start + 2.5).clamp(0.0, total).toDouble();
        if (end - start < 0.3) return false;
        r.plan = PlanOps.addCaption(
          r.plan,
          startSec: start,
          endSec: end,
          text: text,
        );
        r.done.add(
          'Matn qo‘shildi: “$text” (${start.toStringAsFixed(1)}–${end.toStringAsFixed(1)} s)',
        );
        return true;
      },
    ),
    // Format
    (
      RegExp(
        r'\b(9\s*:\s*16|16\s*:\s*9|1\s*:\s*1|4\s*:\s*5|3\s*:\s*4)\b|vertikal|gorizontal|kvadrat|reels|shorts|tiktok|youtube',
      ),
      (r, t, m) {
        final raw = RegExp(r'\b(9|16|1|4|3)\s*:\s*(16|9|1|5|4)\b')
            .firstMatch(t);
        var ratio = raw == null ? null : '${raw[1]}:${raw[2]}';
        ratio ??= RegExp(r'vertikal|reels|shorts|tiktok').hasMatch(t)
            ? '9:16'
            : RegExp(r'gorizontal|youtube').hasMatch(t)
            ? '16:9'
            : '1:1';
        if (!kAspectRatios.contains(ratio)) return false;
        r.plan = PlanOps.setFormat(r.plan, aspectRatio: ratio);
        r.done.add('Format $ratio qilindi');
        return true;
      },
    ),
    (
      RegExp(r'\b(24|25|30|60)\s*fps'),
      (r, t, m) {
        r.plan = PlanOps.setFormat(r.plan, fps: int.parse(m[1]!));
        r.done.add('Kadr tezligi ${m[1]} FPS qilindi');
        return true;
      },
    ),
    (
      RegExp(r'\b(360p|720p|1080p|4k|full ?hd|\bhd\b)'),
      (r, t, m) {
        final raw = m[1]!;
        final res = raw == '4k'
            ? '4K'
            : raw.contains('full') || raw == '1080p'
            ? '1080p'
            : raw == 'hd'
            ? '720p'
            : raw;
        final p = r.copy();
        (p['export'] as Map<String, dynamic>)['resolution'] = res;
        r.plan = p;
        r.done.add(
          'Eksport sifati $res qilindi'
          '${res == '4K' ? ' (manba 4K bo‘lmasa upscale bo‘ladi)' : ''}',
        );
        return true;
      },
    ),
  ];

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp('[’‘ʻʼ`´]'), "'").replaceAll('х', 'x');
}

/// Mutable state while one message is executed.
class _Run {
  _Run(Map<String, dynamic> plan, this.playhead, this.selected)
    : plan = PlanOps.setFormat(plan);

  Map<String, dynamic> plan;
  final double playhead;
  final String? selected;
  String? text;
  bool undo = false;
  final done = <String>[];
  final unhandled = <String>[];

  EditPlan get typed => EditPlan.fromJson(plan);
  double get total => typed.durationSec;

  Map<String, dynamic> copy() =>
      PlanOps.setFormat(plan); // deep copy via PlanOps

  static const _ordinals = {
    'birinchi': 0,
    'ikkinchi': 1,
    'uchinchi': 2,
    'to‘rtinchi': 3,
    "to'rtinchi": 3,
    'beshinchi': 4,
  };

  /// Which shots a command refers to: "3-kadr", "oxirgi kadr", "birinchi",
  /// the selected shot, or (with [defaultAll]) the whole video.
  List<String> targets(String t, {required bool defaultAll}) {
    final shots = typed.shots;
    if (RegExp(r'hamma|barcha|butun|hammasi|video').hasMatch(t) &&
        !RegExp(r'\d+\s*-?\s*(?:chi|nchi|inchi)?\s*kadr').hasMatch(t)) {
      return [for (final s in shots) s.id];
    }
    if (RegExp(r'oxirgi').hasMatch(t)) return [shots.last.id];
    for (final e in _ordinals.entries) {
      if (t.contains(e.key) && e.value < shots.length) {
        return [shots[e.value].id];
      }
    }
    final n = RegExp(r'(\d+)\s*-?\s*(?:chi|nchi|inchi)?\s*kadr').firstMatch(t);
    if (n != null) {
      final i = int.parse(n[1]!) - 1;
      if (i >= 0 && i < shots.length) return [shots[i].id];
      unhandled.add('${n[1]}-kadr yo‘q (jami ${shots.length} ta)');
      return const [];
    }
    if (selected != null && shots.any((s) => s.id == selected)) {
      return [selected!];
    }
    if (defaultAll) return [for (final s in shots) s.id];
    return const [];
  }

  bool fitTo(double target) {
    if (target < 1) {
      unhandled.add('Juda qisqa: kamida 1 soniya bo‘lishi kerak');
      return true;
    }
    final before = total;
    if (target >= before - 0.05) {
      unhandled.add(
        'Video allaqachon ${before.toStringAsFixed(1)} s — uzaytirish uchun '
        'kadr yoki klip qo‘shing',
      );
      return true;
    }
    var p = plan;
    // 1) shrink every shot proportionally (never below the minimum).
    final ratio = target / before;
    for (final s in EditPlan.fromJson(p).shots) {
      final d = (s.duration * ratio).clamp(PlanOps.minShot, PlanOps.maxShot);
      p = PlanOps.resizeShot(p, s.id, d.toDouble());
    }
    // 2) still too long (many tiny shots): drop shots from the end.
    var typedNow = EditPlan.fromJson(p);
    final shotsBefore = typedNow.shots.length;
    while (typedNow.durationSec > target + 0.1 && typedNow.shots.length > 1) {
      final next = PlanOps.removeShot(p, typedNow.shots.last.id);
      if (next == null) break;
      p = next;
      typedNow = EditPlan.fromJson(p);
    }
    // 3) trim the last shot to hit the target exactly.
    final over = typedNow.durationSec - target;
    if (over > 0.05) {
      final last = typedNow.shots.last;
      p = PlanOps.resizeShot(p, last.id, last.duration - over);
    }
    plan = _fixLogo(p);
    final dropped = shotsBefore - typed.shots.length;
    done.add(
      'Video ${before.toStringAsFixed(1)} s dan '
      '${typed.durationSec.toStringAsFixed(1)} s ga qisqartirildi'
      '${dropped > 0 ? ' (oxiridagi $dropped ta kadr olib tashlandi)' : ''}',
    );
    return true;
  }

  Map<String, dynamic> _fixLogo(Map<String, dynamic> p) {
    final logo = p['logo'] as Map<String, dynamic>?;
    final total = (p['durationSec'] as num).toDouble();
    if (logo != null && (logo['durationSec'] as num) > total) {
      final q = PlanOps.setFormat(p);
      (q['logo'] as Map<String, dynamic>)['durationSec'] = total;
      return q;
    }
    return p;
  }

  void setAllVolume(double v) {
    for (final s in typed.shots) {
      plan = PlanOps.setShotVolume(plan, s.id, v);
    }
  }

  void setAllMotion(String m) {
    for (final s in typed.shots) {
      plan = PlanOps.setMotion(plan, s.id, m);
    }
  }

  bool clearCaptions() {
    final p = PlanOps.setFormat(plan);
    final n = (p['captions'] as List).length;
    p['captions'] = <Map<String, dynamic>>[];
    plan = p;
    done.add(n == 0 ? 'Subtitr yo‘q edi' : '$n ta matn o‘chirildi');
    return true;
  }

  /// "Professional qil": the steps a human editor does by default.
  bool polish() {
    final shots = typed.shots;
    final applied = <String>[];
    if (typed.grade == null) {
      plan = PlanOps.setGrade(plan, ColorGrade.presets['kino']);
      applied.add('kino rangi');
    }
    plan = PlanOps.setTransition(plan, null, 'crossfade', seconds: 0.4);
    applied.add('yumshoq o‘tishlar');
    for (final (i, s) in shots.indexed) {
      if (s.freeze) continue;
      plan = PlanOps.setMotion(
        plan,
        s.id,
        i == 0 ? 'punchIn' : (i.isOdd ? 'slowZoom' : 'none'),
      );
    }
    applied.add('hook zoom-punch va sekin zoom');
    final first = shots.first;
    plan = PlanOps.setTransition(plan, first.id, 'fadeBlack', seconds: 0.6);
    applied.add('qoradan chiqish');
    final music = typed.music;
    if (music != null) {
      if (music.beats.isNotEmpty) {
        plan = PlanOps.snapToBeats(plan, music.beats);
        applied.add('ritmga moslash');
      }
      plan = PlanOps.setMusicFadeIn(plan, 1.0);
      applied.add('musiqa asta boshlanishi');
    }
    done.add('Professional ishlov: ${applied.join(', ')}');
    return true;
  }
}
