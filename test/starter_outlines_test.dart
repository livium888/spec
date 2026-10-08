import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/outline_service.dart';
import 'package:daily_learning/domain/outline_parser.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final files = Directory('docs/starter-outlines')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('starter outlines exist', () => expect(files.length, 11));

  for (final f in files) {
    test('imports cleanly: ${f.uri.pathSegments.last}', () async {
      final raw = f.readAsStringSync();
      final p = parseOutlineJson(raw);
      expect(p.hasFatal, isFalse, reason: p.fatalErrors.join('; '));
      expect(p.items.every((i) => i.valid), isTrue);

      // Every prerequisite names an EARLIER topic in the same file.
      final seen = <String>{};
      for (final it in p.items) {
        for (final pre in it.prerequisites) {
          expect(seen, contains(pre), reason: '${it.title} -> $pre');
        }
        seen.add(it.title);
      }

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final svc = OutlineService(db);
      final preview = await svc.preview(raw);
      expect(preview.warnings, isEmpty);
      final wantEdges = p.items.fold<int>(0, (n, i) => n + i.prerequisites.length);
      final s = await svc.commit(preview);
      expect(s.items, p.items.length);
      expect(s.edges, wantEdges);
      expect(s.droppedEdges, 0);
      expect(jsonDecode(raw)['domain'], isNotEmpty);
    });
  }
}
