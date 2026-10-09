// Renders the card-learning screens for visual review. Skipped unless SCREENSHOT_DIR is set:
//   SCREENSHOT_DIR=/dir ART_IMAGE=/path/art.jpg flutter test test/screenshots/card_screens_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/media_service.dart';
import 'package:daily_learning/data/picture_finder.dart';
import 'package:daily_learning/domain/commons.dart';
import 'package:daily_learning/presentation/find_picture_screen.dart';
import 'package:daily_learning/presentation/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    await db.customStatement("UPDATE note SET fields_json = json_set(fields_json, '\$.image', '$sha', '\$.image_alt', 'A sunrise over a harbour, painted in loose brushstrokes', '\$.image_side', 'front', '\$.image_credit', 'Claude Monet · Public domain · Wikimedia Commons') "
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

  for (final dark in [false, true]) {
    testWidgets('find a picture screen (${dark ? 'dark' : 'light'})', (t) async {
      Directory(_dir!).createSync(recursive: true);
      final path = Platform.environment['ART_IMAGE'];
      final art = path != null && File(path).existsSync() ? File(path).readAsBytesSync() : Uint8List(0);
      t.view.physicalSize = const Size(411, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final key = GlobalKey();
      PictureCandidate c(String n) => PictureCandidate(
          title: 'File:$n.jpg', pageUrl: 'x', thumbUrl: 'https://upload.wikimedia.org/$n', mime: 'image/jpeg',
          width: 250, height: 190, credit: 'Claude Monet · Public domain · Wikimedia Commons',
          description: 'A sunrise over a harbour, painted in loose brushstrokes');
      final finder = _ArtFinder([c('Impression, Sunrise'), c('Impression Sunrise (detail)'), c('Monet - Harbour at Le Havre'), c('Le Havre sunrise study')], art);
      await t.pumpWidget(RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [pictureFinderProvider.overrideWithValue(finder)],
          child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: const FindPictureScreen(initialQuery: 'Monet Impression Sunrise'),
          ),
        ),
      ));
      await settle(t);
      final tag = dark ? 'dark' : 'light';
      await shot(t, key, 'c_find_${tag}_1results');
      await t.tap(find.text('Impression, Sunrise'));
      await settle(t);
      await shot(t, key, 'c_find_${tag}_2preview');
    }, skip: skip);
  }

  for (final dark in [false, true]) {
    testWidgets('long question, front and back (${dark ? 'dark' : 'light'})', (t) async {
      Directory(_dir!).createSync(recursive: true);
      final db = AppDatabase(NativeDatabase.memory());
      final imp = ImportService(db);
      await imp.commit(await imp.preview(jsonEncode({
        'domain': 'History and Power',
        'cards': [
          {
            'type': 'basic',
            'front': "Thomas Newcomen's steam engine of 1712 worked, but burned coal so greedily that only one kind of site could afford it. Which, and why?",
            'back': 'Coal mines, where fuel was effectively free and the engine pumped out flood water.',
            'why_it_matters': "Steam power began as a drainage tool for mines. Only when James Watt's separate condenser slashed fuel use could it spread to factories and, later, railways.",
            'example': 'A Cornish tin mine could burn its own waste coal while a mill owner paid for every sack.',
            'memory_hook': 'Newcomen: the mine that drank its own coal.',
            'source_type': 'model_memory',
            'confidence': 'low',
          }
        ]
      })));
      final key = GlobalKey();
      t.platformDispatcher.textScaleFactorTestValue = 1.2; // the learner's phone setting
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await boot(t, db, key, dark: dark);
      final tag = dark ? 'dark' : 'light';
      await t.tap(find.text('Start review'));
      await settle(t);
      await shot(t, key, 'd_long_${tag}_1front');
      await t.tapAt(const Offset(200, 380));
      await settle(t);
      await shot(t, key, 'd_long_${tag}_2back');
      await t.tap(find.text('Show the whole question'));
      await settle(t);
      await shot(t, key, 'd_long_${tag}_3expanded');
      await t.pumpWidget(const SizedBox());
      await t.runAsync(db.close);
    }, skip: skip);
  }
}


class _ArtFinder implements PictureFinder {
  _ArtFinder(this.results, this.bytes);
  final List<PictureCandidate> results;
  final Uint8List bytes;
  @override
  Future<PictureSearch> search(String query, {Set<String>? sources}) async => PictureSearch(results);
  @override
  Future<PictureCandidate?> forCard(PictureCandidate c) async => c;
  @override
  Future<Uint8List> download(String url, {required int maxBytes}) async => bytes;
}
