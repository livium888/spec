// Renders the card-learning screens for visual review. Skipped unless SCREENSHOT_DIR is set:
//   SCREENSHOT_DIR=/dir ART_IMAGE=/path/art.jpg flutter test test/screenshots/card_screens_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/media_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens_test.dart' show boot, settle, shot;

final _dir = Platform.environment['SCREENSHOT_DIR'];

Future<AppDatabase> seedCards() async {
  final db = AppDatabase(NativeDatabase.memory());
  final imp = ImportService(db);
  final now = DateTime.now().toUtc();
  Future<void> add(String domain, Map<String, Object?> card, int daysAgo) async => imp.commit(
      await imp.preview(jsonEncode({'domain': domain, 'syllabus_item': null, 'cards': [card]})),
      now: now.subtract(Duration(days: daysAgo)));
  Map<String, Object?> base(Map<String, Object?> extra) =>
      {'source_type': 'model_memory', 'source_ref': '', 'supporting_quote': '', 'confidence': 'high', ...extra};

  await add('Thinking and Decisions', base({
    'type': 'basic',
    'front': 'Why do people keep paying for a gym they never use, even though cancelling would save money?',
    'back': 'Sunk-cost thinking: the past spend feels like a reason to continue.',
    'why_it_matters': 'The money is gone either way. Only future costs and benefits should decide what you do next.',
    'example': 'Finishing a bad film because you already paid for the ticket.',
    'memory_hook': 'The past bill is a ghost: it cannot vote.',
  }), 4);
  await add('Languages', base({
    'type': 'cloze',
    'cloze': 'In Spanish, "extrañar" means {{c1::to miss someone::feel the absence}}, while "extraño" as an adjective means {{c2::strange}}.',
    'back': 'Same root, two meanings: context tells you which.',
    'why_it_matters': 'Learners translate "I miss you" word for word and get it wrong.',
    'example': 'Te extraño mucho. (I miss you a lot.)',
  }), 3);
  await add('Arts and Design', base({
    'type': 'basic',
    'front': 'Who painted this, and which movement is it named after?',
    'back': 'Claude Monet: "Impression, Sunrise" gave Impressionism its name.',
    'why_it_matters': 'A critic mocked the painting as a mere "impression", and the painters adopted the word.',
  }), 2);

  final path = Platform.environment['ART_IMAGE'];
  final bytes = path != null && File(path).existsSync() ? File(path).readAsBytesSync() : Uint8List(0);
  if (bytes.isNotEmpty) {
    final sha = await MediaService(db).save(bytes);
    await db.customStatement("UPDATE note SET fields_json = json_set(fields_json, '\$.image', '$sha', '\$.image_alt', 'A sunrise over a harbour, painted in loose brushstrokes', '\$.image_side', 'front') "
        "WHERE fields_json LIKE '%Who painted this%'");
  }
  return db;
}

void main() {
  final bool? skip = _dir == null ? true : null;

  for (final dark in [false, true]) {
    testWidgets('card learning screens (${dark ? 'dark' : 'light'})', (t) async {
      Directory(_dir!).createSync(recursive: true);
      final db = (await t.runAsync(seedCards))!;
      final key = GlobalKey();
      await boot(t, db, key, dark: dark);
      final tag = dark ? 'dark' : 'light';
      await t.tap(find.text('Start review'));
      await settle(t);

      Future<void> card(String name) async {
        await shot(t, key, 'b_${name}_${tag}_1front');
        await t.tapAt(const Offset(200, 380)); // tap the card: reveal
        await settle(t);
        await shot(t, key, 'b_${name}_${tag}_2back');
        if (find.text('Example').evaluate().isNotEmpty) {
          await t.tap(find.text('Example'));
          await settle(t);
          await shot(t, key, 'b_${name}_${tag}_3example');
        }
        await t.tap(find.text('Good').first);
        await settle(t);
      }

      await card('1basic');
      await card('2cloze');
      await card('3art');
      await settle(t, rounds: 14);
      await shot(t, key, 'b_4summary_$tag');
      await t.pumpWidget(const SizedBox());
      await t.runAsync(db.close);
    }, skip: skip);
  }
}
