import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/app/app_controller.dart';
import 'package:hookkadr/core/theme/app_theme.dart';
import 'package:hookkadr/core/theme/semantic_colors.dart';
import 'package:hookkadr/features/plan/plan_diff.dart';
import 'package:hookkadr/features/projects/project.dart';
import 'package:hookkadr/features/render/export_presets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _plan({double d2 = 6, bool extraCaption = false}) => {
  'schemaVersion': 1,
  'title': 'T',
  'summary': 'S',
  'durationSec': 4 + d2,
  'aspectRatio': '9:16',
  'shots': [
    {'id': 's1', 'startSec': 0, 'endSec': 4, 'description': 'a'},
    {'id': 's2', 'startSec': 4, 'endSec': 4 + d2, 'description': 'b'},
  ],
  'mediaSlots': <Map<String, dynamic>>[],
  'captions': [
    {'startSec': 0, 'endSec': 1, 'text': 'x'},
    if (extraCaption) {'startSec': 1, 'endSec': 2, 'text': 'y'},
  ],
  'audioTracks': <Map<String, dynamic>>[],
  'export': {'resolution': '1080p', 'fps': 30},
};

void main() {
  group('FileSizeEstimator', () {
    test('matches the spec presets (decimal MB)', () {
      expect(FileSizeEstimator.estimateBytes('1080p', 15), 19110000);
      expect(FileSizeEstimator.estimateLabel('1080p', 15), '≈19 MB');
      expect(FileSizeEstimator.estimateLabel('360p', 15), '≈2.5 MB');
      expect(FileSizeEstimator.estimateLabel('720p', 30), '≈19 MB');
      expect(FileSizeEstimator.estimateLabel('4K', 60), '≈264 MB');
    });
    test('presets carry the HOOKKADR export sizes', () {
      expect(ExportPreset.of('360p').shortSide, 360);
      expect(ExportPreset.of('4K').shortSide, 2160);
      expect(ExportPreset.of('nonsense').label, '1080p');
    });
  });

  group('plan diff', () {
    test('describes duration, shot and caption changes', () {
      final lines = describePlanDiff(_plan(), _plan(d2: 3, extraCaption: true));
      expect(lines, contains('Davomiylik: 10 s → 7 s'));
      expect(lines, contains('Kadr s2: 6 s → 3 s'));
      expect(lines, contains('Subtitr qo‘shildi (+1)'));
    });
    test('identical plans produce no changes', () {
      expect(describePlanDiff(_plan(), _plan()), isEmpty);
    });
  });

  group('versions and current output', () {
    test('updatePlan keeps history and undo restores it', () async {
      SharedPreferences.setMockInitialValues({});
      final app = AppController(
        keys: MemoryKeyStore(),
        prefs: await SharedPreferences.getInstance(),
      );
      final p = await app.addProject(_plan());
      await app.updatePlan(p.id, _plan(d2: 3));
      expect(app.byId(p.id)!.history, hasLength(1));
      expect(await app.undoPlan(p.id), isTrue);
      expect(app.byId(p.id)!.planJson['durationSec'], 10);
      expect(await app.undoPlan(p.id), isFalse);
    });

    test('a render is current only for the plan it was made from', () async {
      SharedPreferences.setMockInitialValues({});
      final app = AppController(
        keys: MemoryKeyStore(),
        prefs: await SharedPreferences.getInstance(),
      );
      final p = await app.addProject(_plan());
      await app.setLastRender(
        p.id,
        RenderInfo(
          path: '/x.mp4',
          sizeBytes: 1,
          resolution: '1080p',
          aspectRatio: '9:16',
          durationSec: 10,
          fps: 30,
          createdAt: DateTime(2026),
          planSignature: planSignature(app.byId(p.id)!.planJson),
        ),
      );
      expect(app.byId(p.id)!.renderIsCurrent, isTrue);
      await app.updatePlan(p.id, _plan(d2: 3));
      expect(app.byId(p.id)!.renderIsCurrent, isFalse);
      // survives a restart
      final again = AppController(keys: MemoryKeyStore(), prefs: app.prefs);
      await again.load();
      expect(again.byId(p.id)!.lastRender!.resolution, '1080p');
      expect(again.byId(p.id)!.history, hasLength(1));
    });
  });

  group('accessibility tokens', () {
    test('contrast helper matches known WCAG values', () {
      expect(
        contrastRatio(const Color(0xFFA64B12), Colors.white),
        closeTo(5.77, 0.05),
      );
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.05));
    });
    test('primary actions, text and strong borders meet their minimums', () {
      for (final (pal, sem) in [
        (AppPalette.light, HookkadrSemanticColors.light),
        (AppPalette.dark, HookkadrSemanticColors.dark),
      ]) {
        expect(
          contrastRatio(sem.actionPrimaryForeground, sem.actionPrimary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(pal.textPrimary, pal.background),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(pal.textSecondary, pal.background),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(sem.borderStrong, pal.background),
          greaterThanOrEqualTo(3),
        );
      }
    });
  });
}
