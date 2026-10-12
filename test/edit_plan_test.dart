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
    {'id': 'm1', 'kind': 'logo', 'description': 'Logo PNG'},
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
}
