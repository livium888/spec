import 'dart:io';

import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/presentation/anki_import_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'screenshots/screens_test.dart' show settle;
import 'support/anki_fixture.dart';

List<Override> _dbOverrides(AppDatabase db, Directory tmp) => [bootstrapProvider.overrideWithValue(Bootstrap(File('x'), tmp, db))];

/// D50: the import screen, end to end with a package built by the fixture (no file picker on a test machine).
void main() {
  testWidgets('choose a package, rename a subject, leave one out, import, open the result', (t) async {
    final tmp = Directory.systemTemp.createTempSync('anki_ui');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final pkg = apkg(tmp, {'collection.anki21': collection(), 'media': [...'{"0":"cell.png"}'.codeUnits], '0': png}, name: 'deck.apkg');
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async => t.runAsync(db.close));

    await t.pumpWidget(ProviderScope(
      overrides: [
        ankiFilePickerProvider.overrideWithValue(() async {
          final copy = File('${tmp.path}/picked.apkg')..writeAsBytesSync(pkg.readAsBytesSync());
          return (copy, 'deck.apkg');
        }),
        ..._dbOverrides(db, tmp),
      ],
      child: const MaterialApp(home: AnkiImportScreen()),
    ));
    await settle(t, rounds: 3);

    expect(find.text('Bring your Anki cards in'), findsOneWidget);
    await t.tap(find.text('Choose a file'));
    await settle(t, rounds: 12);

    expect(find.text('6 notes found'), findsOneWidget);
    expect(find.textContaining('4 can be imported'), findsOneWidget);
    expect(find.textContaining('1 audio clip'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Biology'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Import 4 cards'), findsOneWidget);

    await t.tap(find.byType(Checkbox).last); // leave Spanish out
    await settle(t, rounds: 2);
    expect(find.widgetWithText(FilledButton, 'Import 3 cards'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Biology'), 'Life science');
    await t.tap(find.widgetWithText(FilledButton, 'Import 3 cards'));
    await settle(t, rounds: 14);

    expect(find.text('3 notes added'), findsOneWidget);
    expect(find.textContaining('Open Life science'), findsOneWidget);
    final names = await t.runAsync(() async => [for (final d in await db.select(db.domains).get()) d.name]);
    expect(names, ['Life science']);
    final left = await t.runAsync(() async => tmp.listSync().whereType<File>().where((f) => f.path.endsWith('picked.apkg')).length);
    expect(left, 0, reason: 'the copy of the file is deleted after the import');
  });

  testWidgets('a file in the newest format shows how to export it again, and the learner can try another file', (t) async {
    final tmp = Directory.systemTemp.createTempSync('anki_ui2');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async => t.runAsync(db.close));
    await t.pumpWidget(ProviderScope(
      overrides: [
        ankiFilePickerProvider.overrideWithValue(() async {
          final f = apkg(tmp, {'collection.anki21b': [1, 2, 3]}, name: 'new.apkg');
          return (f, 'new.apkg');
        }),
        ..._dbOverrides(db, tmp),
      ],
      child: const MaterialApp(home: AnkiImportScreen()),
    ));
    await settle(t, rounds: 3);
    await t.tap(find.text('Choose a file'));
    await settle(t, rounds: 8);
    expect(find.textContaining('Support older Anki versions'), findsWidgets);
    expect(find.text('Choose a file'), findsOneWidget);
  });
}
