import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';
import 'package:hookkadr/features/plan/auto_editor.dart';
import 'package:hookkadr/features/render/media_analyzer.dart';

void main() {
  group('ffmpeg log parsers', () {
    test('scene cuts from showinfo', () {
      const log =
          '[Parsed_showinfo_2 @ 0x1] n:   0 pts:  60 pts_time:2.002 duration:1\n'
          '[Parsed_showinfo_2 @ 0x1] n:   1 pts: 121 pts_time:4.04 duration:1\n'
          '[Parsed_showinfo_2 @ 0x1] n:   2 pts: 122 pts_time:4.1 duration:1\n';
      expect(parseSceneCuts(log), [2.002, 4.04]); // 4.1 merged (too close)
    });

    test('silences, including one that runs to the end', () {
      const log =
          '[silencedetect @ 0x1] silence_start: 2.01\n'
          '[silencedetect @ 0x1] silence_end: 3.02 | silence_duration: 1.01\n'
          '[silencedetect @ 0x1] silence_start: 5.5\n';
      final s = parseSilences(log, 6);
      expect(s, hasLength(2));
      expect(s[0].start, 2.01);
      expect(s[0].end, 3.02);
      expect(s[1].end, 6);
    });
  });

  group('AutoEditor', () {
    const a = ClipFacts(
      id: 'clip_01',
      durationSec: 6,
      sceneCuts: [2, 4],
      silences: [(start: 2.2, end: 3.2)],
      hasAudio: true,
    );
    const b = ClipFacts(id: 'clip_02', durationSec: 10, sceneCuts: [5]);

    test('pauses are cut out of usable pieces', () {
      final pieces = AutoEditor.usablePieces(a);
      for (final p in pieces) {
        expect(
          p.end <= 2.2 || p.start >= 3.2,
          isTrue,
          reason: '$p overlaps silence',
        );
      }
      expect(pieces.first, (start: 0.0, end: 2.0));
    });

    test('builds a valid plan near the target with in-range sources', () {
      final plan = AutoEditor.build(
        clips: const [a, b],
        targetSec: 12,
        aspectRatio: '9:16',
        resolution: '1080p',
        title: 'Test',
      );
      final p = EditPlan.fromJson(plan);
      expect(p.durationSec, closeTo(12, 1.0));
      expect(p.shots.first.description, startsWith('Hook'));
      for (final s in p.shots) {
        final len = s.sourceClipId == 'clip_01' ? 6 : 10;
        expect(s.sourceIn!, greaterThanOrEqualTo(0));
        expect(s.sourceOut!, lessThanOrEqualTo(len + 0.01));
        expect(s.duration, greaterThanOrEqualTo(AutoEditor.minPiece - 0.01));
      }
      expect(plan['summary'], contains('pauza kesildi'));
    });

    test('never repeats footage to fill time: shorter result is honest', () {
      final plan = AutoEditor.build(
        clips: const [ClipFacts(id: 'clip_01', durationSec: 4)],
        targetSec: 30,
        aspectRatio: '9:16',
        resolution: '720p',
        title: 'Qisqa',
      );
      final p = EditPlan.fromJson(plan);
      expect(p.durationSec, lessThanOrEqualTo(4.01));
    });
  });
}
