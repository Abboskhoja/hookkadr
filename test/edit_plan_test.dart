import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/analysis/domain/edit_plan.dart';

Map<String, dynamic> valid() => {
  'schemaVersion': 1,
  'title': 'Ad',
  'summary': 'Short ad',
  'durationSec': 15,
  'aspectRatio': '9:16',
  'shots': [
    {
      'id': 's1',
      'startSec': 0,
      'endSec': 5,
      'description': 'Logo',
      'mediaSlotId': 'm1',
    },
    {'id': 's2', 'startSec': 5, 'endSec': 15, 'description': 'Car'},
  ],
  'mediaSlots': [
    <String, dynamic>{'id': 'm1', 'kind': 'logo', 'description': 'Logo PNG'},
  ],
  'captions': [
    {'startSec': 0, 'endSec': 2, 'text': 'Hi'},
  ],
  'audioTracks': <Map<String, dynamic>>[],
  'export': {'resolution': '1080p', 'fps': 30},
};

void main() {
  test('parses a valid plan', () {
    final plan = EditPlan.fromJson(valid());
    expect(plan.shots, hasLength(2));
    expect(plan.shots.first.duration, 5);
  });

  test('rejects unsupported schema version', () {
    expect(
      () => EditPlan.fromJson(valid()..['schemaVersion'] = 2),
      throwsA(isA<EditPlanFormatException>()),
    );
  });

  test('rejects overlapping shots', () {
    final j = valid();
    (j['shots'] as List)[1]['startSec'] = 3;
    expect(() => EditPlan.fromJson(j), throwsA(isA<EditPlanFormatException>()));
  });

  test('rejects shot beyond duration', () {
    final j = valid();
    (j['shots'] as List)[1]['endSec'] = 20;
    expect(() => EditPlan.fromJson(j), throwsA(isA<EditPlanFormatException>()));
  });

  test('rejects unknown media slot reference', () {
    final j = valid();
    (j['shots'] as List)[0]['mediaSlotId'] = 'nope';
    expect(() => EditPlan.fromJson(j), throwsA(isA<EditPlanFormatException>()));
  });

  test('wrong field types become format exceptions', () {
    final j = valid()..['shots'] = 'bad';
    expect(() => EditPlan.fromJson(j), throwsA(isA<EditPlanFormatException>()));
  });

  test('rejects an array ordered differently from its timeline', () {
    final j = valid();
    j['shots'] = (j['shots'] as List).reversed.toList();
    expect(() => EditPlan.fromJson(j), throwsA(isA<EditPlanFormatException>()));
  });

  test(
    'rejects leading, internal, and trailing gaps the renderer cannot honor',
    () {
      for (final gap in ['leading', 'internal', 'trailing']) {
        final j = valid();
        final shots = j['shots'] as List;
        if (gap == 'leading') shots[0]['startSec'] = 1;
        if (gap == 'internal') shots[1]['startSec'] = 6;
        if (gap == 'trailing') j['durationSec'] = 16;
        expect(
          () => EditPlan.fromJson(j),
          throwsA(isA<EditPlanFormatException>()),
          reason: gap,
        );
      }
    },
  );

  test('rejects fractional FPS instead of silently truncating it', () {
    final j = valid();
    (j['export'] as Map)['fps'] = 30.9;
    expect(() => EditPlan.fromJson(j), throwsA(isA<EditPlanFormatException>()));
  });

  test('rejects nonfinite required and optional numbers before rendering', () {
    final mutations = <void Function(Map<String, dynamic>, double)>[
      (j, n) => j['durationSec'] = n,
      (j, n) => (j['shots'] as List)[0]['startSec'] = n,
      (j, n) => (j['shots'] as List)[0]['endSec'] = n,
      (j, n) => (j['shots'] as List)[0]['speed'] = n,
      (j, n) => (j['shots'] as List)[0]['volume'] = n,
      (j, n) => (j['shots'] as List)[0]['transitionSec'] = n,
      (j, n) {
        (j['shots'] as List)[0]['sourceIn'] = n;
        (j['shots'] as List)[0]['sourceOut'] = 5;
      },
      (j, n) => (j['captions'] as List)[0]['endSec'] = n,
      (j, n) => (j['mediaSlots'] as List)[0]['requiredDurationSec'] = n,
      (j, n) => (j['export'] as Map)['fps'] = n,
      (j, n) => j['grade'] = {'exposure': n},
      (j, n) => j['logo'] = {'clipId': 'logo', 'scale': n},
      (j, n) => j['music'] = {'path': '/m', 'name': 'm', 'fadeInSec': n},
      (j, n) => j['music'] = {
        'path': '/m',
        'name': 'm',
        'beats': [n],
      },
    ];
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      for (final (index, mutate) in mutations.indexed) {
        final j = valid();
        mutate(j, value);
        expect(
          () => EditPlan.fromJson(j),
          throwsA(isA<EditPlanFormatException>()),
          reason: 'mutation $index with $value',
        );
      }
    }
  });
}
