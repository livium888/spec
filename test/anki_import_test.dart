import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/data/anki_import_service.dart';
import 'package:daily_learning/data/anki_package.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/domain/anki_import.dart';
import 'package:daily_learning/domain/anki_text.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/anki_fixture.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('anki_t'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('field text', () {
    test('HTML becomes the Markdown subset the app draws; entities decode; no tags survive', () {
      expect(ankiFieldToText('The <b>membrane</b>&nbsp;layer<br>and <i>more</i> &amp; &lt;tag&gt;').text, 'The **membrane** layer\nand *more* & <tag>');
      expect(ankiFieldToText('<div>one</div><div>two</div>').text, 'one\ntwo');
      expect(ankiFieldToText('<ul><li>a</li><li>b</li></ul>').text, '- a\n- b');
      expect(ankiFieldToText('<span style="color:red" onclick="x()">plain</span><script>alert(1)</script>').text, 'plainalert(1)');
      expect(ankiFieldToText('&#65;&#x42; &bogus; &#1114112;').text, 'AB &bogus; &#1114112;');
    });

    test('maths: Anki delimiters become dollar signs; a dollar amount in text stays text', () {
      expect(ankiFieldToText(r'Area is \(\pi r^2\) and \[x^2 + y^2\]').text, r'Area is $\pi r^2$ and $$x^2 + y^2$$');
      expect(ankiFieldToText(r'[$]a_1[/$] and [$$]b[/$$]').text, r'$a_1$ and $$b$$');
      expect(ankiFieldToText(r'It costs $5 or $6').text, r'It costs \$5 or \$6');
      expect(ankiFieldToText(r'a &lt; b: \(a &lt; b\)').text, r'a < b: $a < b$');
    });

    test('pictures are named, never loaded; sounds are counted and dropped; clozes stay as they are', () {
      final r = ankiFieldToText('See <img src="a.png"> and <img class=x src=\'b b.jpg\' > [sound:s.mp3] {{c1::DNA::hint}}');
      expect(r.images, ['a.png', 'b b.jpg']);
      expect(r.sounds, 1);
      expect(r.text, 'See  and   {{c1::DNA::hint}}');
    });

    test('plain text exports escape every symbol the card markup would read', () {
      expect(ankiFieldToText(r'a*b and $c and _d_', html: false).text, r'a\*b and \$c and \_d\_');
    });

    test('a huge field is cut, never thrown', () {
      expect(ankiFieldToText('x' * 100000).text.length, kMaxAnkiFieldChars);
    });
  });

  test('fuzz: any mix of HTML, maths, entities and control characters converts without an error, within the size limit', () {
    final pieces = [
      '<b>', '</b>', '<i>', '<div>', '</div>', '<br>', '<li>', '<ul>', '<img src="a.png">', '<img src=', '<', '>', '&', '&amp;', '&#',
      r'\(', r'\)', r'\[', r'\]', r'[$]', r'[/$]', r'$', r'$$', '{{c1::', '}}', '::', '[sound:', ']', '*', '_', '`', '\n', '\r\n', '\t', ' ',
      'word', 'x^2', '\u0001', '\u0002', '\u0003', '日本語', '\u{1F600}', '\\',
    ];
    final rnd = _Lcg(42);
    for (var i = 0; i < 3000; i++) {
      final buf = StringBuffer();
      for (var k = rnd.next(40); k > 0; k--) {
        buf.write(pieces[rnd.next(pieces.length)]);
      }
      for (final html in [true, false]) {
        final r = ankiFieldToText(buf.toString(), html: html);
        expect(r.text.length, lessThanOrEqualTo(kMaxAnkiFieldChars));
        expect(r.text, isNot(contains('\u0001')), reason: 'a maths placeholder must never leak: ${buf.toString()}');
        expect(r.text, isNot(contains('\u0003')));
      }
      final n = AnkiNote(model: 'Basic', fields: [buf.toString(), buf.toString()], deck: 'A::B');
      convertAnkiNote(n, 0); // must not throw
    }
  });

  test('a big text export (20,000 notes) is converted quickly', () {
    final text = StringBuffer();
    for (var i = 0; i < 20000; i++) {
      text.writeln('Question $i about <b>things</b>\tThe answer to $i &amp; more');
    }
    final sw = Stopwatch()..start();
    final notes = notesOfTextFile(parseAnkiTextFile('#html:true\n$text', maxRows: kMaxAnkiNotes + 1)!);
    var ok = 0;
    for (var i = 0; i < notes.length; i++) {
      if (convertAnkiNote(notes[i], i).draft != null) ok++;
    }
    expect(ok, 20000);
    expect(sw.elapsedMilliseconds, lessThan(10000), reason: 'took ${sw.elapsedMilliseconds} ms');
  });

  group('plain-text and CSV files', () {
    test('header lines, tab separator, tag and deck columns, quoted fields with lines and quotes', () {
      final f = parseAnkiTextFile('#separator:tab\n#html:true\n#tags column:3\n#deck column:4\nQ1\tA1\tt1 t2\tBio::Cells\n"Q ""2""\nline"\t"A\t2"\t\tBio\n')!;
      expect(f.html, isTrue);
      expect(f.rows.length, 2);
      expect(f.rows[1][0], 'Q "2"\nline');
      expect(f.rows[1][1], 'A\t2');
      final notes = notesOfTextFile(f);
      expect(notes[0].tags, ['t1', 't2']);
      expect(notes[0].deck, 'Bio::Cells');
      expect(notes[0].fields, ['Q1', 'A1']);
    });

    test('a spreadsheet CSV: separator is guessed, the Front,Back header row is not a card, a BOM is ignored', () {
      final notes = notesOfTextFile(parseAnkiTextFile('﻿Front,Back\nhola,hello\n"a, b",c\n')!, deckName: 'Spanish words');
      expect(notes.length, 2);
      expect(notes[1].fields, ['a, b', 'c']);
      expect(notes.first.deck, 'Spanish words');
      expect(parseAnkiTextFile('#separator:tab\n'), isNull);
    });

    test('a cloze notetype column makes cloze notes', () {
      final notes = notesOfTextFile(parseAnkiTextFile('#separator:tab\n#notetype column:1\nCloze\tThe {{c1::x}}\n')!);
      expect(notes.single.cloze, isTrue);
    });
  });

  group('one note', () {
    AnkiNote basic(List<String> f, {String model = 'Basic', List<String> names = const [], String deck = 'Biology::Cells', List<String> tags = const []}) =>
        AnkiNote(model: model, fields: f, fieldNames: names, deck: deck, tags: tags);

    test('basic, with the extra fields of a custom type added to the answer', () {
      final c = convertAnkiNote(basic(['hablar', 'to speak', 'Yo hablo.'], model: 'Vocab', deck: 'Spanish'), 0).draft!.card;
      expect((c.type, c.front, c.back), ('basic', 'hablar', 'to speak\n\nYo hablo.'));
      expect(c.confidence, 'high');
      expect(c.unverified, isFalse, reason: 'your own cards are not "unverified"');
      expect(c.sourceRef, 'Anki: Spanish');
    });

    test('cloze takes Text and Back Extra by name; a cloze without a gap is skipped', () {
      final ok = convertAnkiNote(AnkiNote(model: 'Cloze', cloze: true, fieldNames: ['Text', 'Back Extra'], fields: ['The {{c1::nucleus}} {{c2::holds}}', 'extra'], deck: 'Bio'), 0).draft!.card;
      expect((ok.type, ok.cloze, ok.back), ('cloze', 'The {{c1::nucleus}} {{c2::holds}}', 'extra'));
      expect(ok.clozeNumbers, {1, 2});
      expect(convertAnkiNote(AnkiNote(model: 'Cloze', cloze: true, fields: ['no gaps here'], deck: 'Bio'), 0).skip, AnkiSkip.noGap);
    });

    test('image occlusion and empty notes are skipped with a reason', () {
      expect(convertAnkiNote(basic(['x', '<img src="a.png">'], model: 'Image Occlusion'), 0).skip, AnkiSkip.occlusion);
      expect(convertAnkiNote(basic(['', '']), 0).skip, AnkiSkip.empty);
      expect(convertAnkiNote(basic(['q', '']), 0).skip, AnkiSkip.empty);
    });

    test('a picture-only side keeps a short text and names the picture; extra pictures are counted', () {
      final r = convertAnkiNote(basic(['<img src="a.png"><img src="b.png">', 'A cell']), 0).draft!;
      expect((r.card.front, r.imageFile, r.imageSide, r.extraImages), ('What is shown in the picture?', 'a.png', 'front', 1));
      final back = convertAnkiNote(basic(['What is this?', '<img src="z.png">']), 0).draft!;
      expect((back.card.back, back.imageSide), ('See the picture.', 'back'));
    });

    test('tags: the app\'s reserved ones cannot come across, hierarchy keeps the last part, sub-decks become tags', () {
      final c = convertAnkiNote(basic(['q', 'a'], tags: ['leech', 'marked', 'Bio::Cells::Membrane', 'exam'], deck: 'Biology::Cells::Parts'), 0).draft!.card;
      expect(c.tags, containsAll(['from_anki', 'membrane', 'exam', 'cells', 'parts']));
      expect(c.tags, isNot(contains('leech')));
      expect(c.tags, isNot(contains('marked')));
    });

    test('subject of a deck: the top-level deck; Default is not a name', () {
      expect(subjectOfDeck('Biology::Cells').subject, 'Biology');
      expect(subjectOfDeck('Default').subject, 'Imported from Anki');
      expect(subjectOfDeck('Default::Spanish::Verbs').subject, 'Spanish');
      expect(subjectOfDeck('').subject, 'Imported from Anki');
      expect(subjectOfDeck('x' * 100).subject.length, 60);
    });
  });

  group('reading a package', () {
    test('reads notes, note types, decks and the picture map from a legacy-format package', () async {
      final f = apkg(tmp, {'collection.anki21': collection(), 'media': utf8.encode('{"0":"cell.png"}'), '0': png});
      final r = await readAnkiFile(f, tmp);
      addTearDown(r.close);
      expect(r.notes.length, 6);
      final n1 = r.notes.first;
      expect((n1.model, n1.deck), ('Basic', 'Biology::Cells'));
      expect(n1.tags, ['cell', 'membrane']);
      expect(n1.fieldNames, ['Front', 'Back']);
      expect(r.notes[1].cloze, isTrue);
      expect(await r.picture('cell.png'), png);
      expect(await r.picture('missing.png'), isNull);
      expect(tmp.listSync().whereType<File>().where((x) => x.path.endsWith('.db')), isEmpty, reason: 'the temporary database is removed');
    });

    test('only the newest format (anki21b) and the "please update" placeholder both say how to re-export', () async {
      final newest = apkg(tmp, {'collection.anki21b': [1, 2, 3], 'meta': [8]}, name: 'n.apkg');
      await expectLater(readAnkiFile(newest, tmp), throwsA(isA<AnkiFileException>().having((e) => e.message, 'message', contains('Support older Anki versions'))));
      final dummy = apkg(tmp, {'collection.anki2': collection(dummy: true), 'collection.anki21b': [1]}, name: 'd.apkg');
      await expectLater(readAnkiFile(dummy, tmp), throwsA(isA<AnkiFileException>().having((e) => e.message, 'message', contains('Support older Anki versions'))));
    });

    test('damaged zips, empty files and a zip without a collection are refused with a message, never a crash', () async {
      final bad = File('${tmp.path}/bad.apkg')..writeAsBytesSync([0x50, 0x4B, 3, 4, 1, 2, 3, 4, 5, 6]);
      await expectLater(readAnkiFile(bad, tmp), throwsA(isA<AnkiFileException>()));
      final empty = File('${tmp.path}/e.txt')..writeAsBytesSync([]);
      await expectLater(readAnkiFile(empty, tmp), throwsA(isA<AnkiFileException>()));
      final none = apkg(tmp, {'readme.txt': utf8.encode('hi')}, name: 'none.apkg');
      await expectLater(readAnkiFile(none, tmp), throwsA(isA<AnkiFileException>()));
      final notDb = apkg(tmp, {'collection.anki21': utf8.encode('this is not a database at all, just text' * 5)}, name: 'x.apkg');
      await expectLater(readAnkiFile(notDb, tmp), throwsA(isA<AnkiFileException>()));
    });

    test('a text export is read as notes, the subject named after the file', () async {
      final f = File('${tmp.path}/Spanish_words.txt')..writeAsStringSync('hola\thello\nadios\tbye\n');
      final r = await readAnkiFile(f, tmp);
      expect(r.notes.length, 2);
      expect(subjectOfDeck(r.notes.first.deck).subject, 'Spanish words');
      expect(r.hasPictures, isFalse);
    });
  });

  group('importing', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<(AnkiPlan, AnkiRead)> open() async {
      final f = apkg(tmp, {'collection.anki21': collection(), 'media': utf8.encode('{"0":"cell.png"}'), '0': png});
      final r = await readAnkiFile(f, tmp);
      addTearDown(r.close);
      return (AnkiImportService(db).plan(r), r);
    }

    test('the plan groups by subject and counts what is left out', () async {
      final (plan, _) = await open();
      expect(plan.notes, 6);
      expect(plan.subjects.map((s) => (s.subject, s.count)).toList(), [('Biology', 3), ('Spanish', 1)]);
      expect(plan.skipped[AnkiSkip.occlusion], 1);
      expect(plan.skipped[AnkiSkip.empty], 1);
      expect(plan.sounds, 1);
      expect(plan.pictureNames, 1);
    });

    test('importing adds subjects, notes and one card per cloze gap, all new; pictures are stored once and shown on the right side', () async {
      final (plan, read) = await open();
      final seen = <int>[];
      final res = await AnkiImportService(db).import(plan, read, onProgress: (d, t) => seen.add(d));
      expect(res.notes, 4);
      expect(res.cards, 5, reason: 'basic + cloze with two gaps + vocab + picture card');
      expect(res.duplicates, 0);
      expect((res.pictures, res.picturesDropped), (1, 0));
      expect(seen.last, 4);
      expect((await db.select(db.domains).get()).map((d) => d.name).toSet(), {'Biology', 'Spanish'});
      expect((await db.select(db.cards).get()).every((c) => c.state == 'new' && c.reps == 0), isTrue);
      expect(await db.select(db.reviewLogs).get(), isEmpty, reason: 'no Anki history comes across');
      final withPic = (await db.select(db.notes).get()).firstWhere((n) => n.fieldsJson.contains('"image"'));
      final fields = jsonDecode(withPic.fieldsJson) as Map<String, dynamic>;
      expect((fields['image_side'], (fields['image'] as String).length), ('front', 64));
      expect(await db.select(db.mediaItems).get(), hasLength(1));
      final tags = (await db.select(db.notes).get()).expand((n) => n.tags.split(' ')).toSet();
      expect(tags, containsAll(['from_anki', 'cell', 'membrane', 'cells']));
    });

    test('importing the same file again adds nothing (duplicates are counted), and a subject can be left out or renamed', () async {
      final (plan, read) = await open();
      final svc = AnkiImportService(db);
      await svc.import(plan, read);
      final again = await svc.import(plan, read);
      expect((again.notes, again.duplicates), (0, 4));
      expect(await db.select(db.mediaItems).get(), hasLength(1), reason: 'no new copy of the picture');

      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(db2.close);
      final plan2 = AnkiImportService(db2).plan(read);
      plan2.subjects.firstWhere((s) => s.subject == 'Spanish').selected = false;
      plan2.subjects.firstWhere((s) => s.subject == 'Biology').subject = 'Life science';
      final r2 = await AnkiImportService(db2).import(plan2, read);
      expect(r2.subjects.keys, ['Life science']);
      expect((await db2.select(db2.domains).get()).map((d) => d.name), ['Life science']);
    });

    test('it never touches the prompt log, and never files cards under a subject it merely resembles', () async {
      final dom = await db.into(db.domains).insert(DomainsCompanion.insert(name: 'Biology and cells', createdAt: 1));
      final item = await db.into(db.syllabusItems).insert(SyllabusItemsCompanion.insert(domainId: dom, title: 'Cells'));
      await db.into(db.promptLogs).insert(PromptLogsCompanion.insert(
          createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
          domainId: Value(dom),
          syllabusItemId: Value(item),
          templateVersion: 'v',
          promptText: 'p',
          cardsRequested: 5,
          status: const Value('issued')));
      final (plan, read) = await open();
      await AnkiImportService(db).import(plan, read);
      expect((await db.select(db.promptLogs).getSingle()).status, 'issued');
      final names = (await db.select(db.domains).get()).map((d) => d.name).toSet();
      expect(names, contains('Biology'), reason: 'a separate subject, not the similar-named one the app had asked about');
    });
  });
}

/// A tiny deterministic generator, so a failure can be reproduced.
class _Lcg {
  _Lcg(this._s);
  int _s;
  int next(int n) {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return (_s >> 8) % n;
  }
}

