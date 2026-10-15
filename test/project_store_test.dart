import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookkadr/features/projects/project.dart';
import 'package:hookkadr/features/projects/project_store.dart';

void main() {
  final project = Project(
    id: 'p1',
    name: 'Original',
    createdAt: DateTime(2026),
    planJson: {'title': 'Original'},
  );

  test('invalid recovery archive is never overwritten', () async {
    final disk = <String, String>{
      'projects_v1': 'broken',
      ProjectStore.recoveryKey: 'also broken',
    };
    final store = ProjectStore(
      read: (key) => disk[key],
      write: (key, value) async {
        disk[key] = value;
        return true;
      },
    );
    await expectLater(store.save([project]), throwsFormatException);
    expect(disk['projects_v1'], 'broken');
    expect(disk[ProjectStore.recoveryKey], 'also broken');
  });

  test('failed main write is reported and keeps recovery data', () async {
    final disk = <String, String>{'projects_v1': 'broken'};
    final store = ProjectStore(
      read: (key) => disk[key],
      write: (key, value) async {
        if (key == ProjectStore.projectsKey) return false;
        disk[key] = value;
        return true;
      },
    );
    await expectLater(store.save([project]), throwsStateError);
    expect(disk['projects_v1'], 'broken');
    expect(jsonDecode(disk[ProjectStore.recoveryKey]!), ['broken']);
  });

  test(
    'saving recovered projects retains exact corrupt source across restarts',
    () async {
      final raw = jsonEncode([
        project.toJson(),
        {'id': 'broken'},
        42,
      ]);
      final disk = <String, String>{'projects_v1': raw};
      ProjectStore store() => ProjectStore(
        read: (key) => disk[key],
        write: (key, value) async {
          disk[key] = value;
          return true;
        },
      );
      expect(store().load().map((p) => p.id), ['p1']);
      await store().save([project.copyWith(name: 'Renamed')]);
      expect(store().load().single.name, 'Renamed');
      expect(jsonDecode(disk[ProjectStore.recoveryKey]!), [raw]);
      await store().save([]);
      expect(jsonDecode(disk[ProjectStore.recoveryKey]!), [raw]);
    },
  );

  for (final raw in ['{interrupted', '{"unexpected":"shape"}']) {
    test('malformed root survives next save: $raw', () async {
      final disk = <String, String>{'projects_v1': raw};
      final store = ProjectStore(
        read: (key) => disk[key],
        write: (key, value) async {
          disk[key] = value;
          return true;
        },
      );
      expect(store.load(), isEmpty);
      await store.save([project]);
      expect(jsonDecode(disk[ProjectStore.recoveryKey]!), [raw]);
    });
  }

  test('failed backup prevents overwriting the original', () async {
    const raw = '{interrupted';
    final disk = <String, String>{'projects_v1': raw};
    final store = ProjectStore(
      read: (key) => disk[key],
      write: (key, value) async {
        if (key == ProjectStore.recoveryKey) return false;
        disk[key] = value;
        return true;
      },
    );
    await expectLater(store.save([project]), throwsStateError);
    expect(disk['projects_v1'], raw);
  });

  test(
    'successive corrupt snapshots are retained without duplicates',
    () async {
      final disk = <String, String>{'projects_v1': 'bad-one'};
      final store = ProjectStore(
        read: (key) => disk[key],
        write: (key, value) async {
          disk[key] = value;
          return true;
        },
      );
      await store.save([project]);
      disk['projects_v1'] = 'bad-two';
      await store.save([project]);
      disk['projects_v1'] = 'bad-one';
      await store.save([project]);
      expect(jsonDecode(disk[ProjectStore.recoveryKey]!), [
        'bad-one',
        'bad-two',
      ]);
    },
  );
}
