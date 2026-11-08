import 'dart:convert';
import 'dart:io';

import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/import_service.dart';
import 'package:daily_learning/data/primer_service.dart';
import 'package:daily_learning/data/source_service.dart';
import 'package:daily_learning/domain/import_parser.dart';
import 'package:daily_learning/domain/primer_parser.dart';
import 'package:daily_learning/domain/transcript.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

const srt = '''1
00:00:01,000 --> 00:00:04,000
Risk is the likelihood of a threat exploiting a vulnerability.

2
00:00:04,500 --> 00:00:08,000
Multiply that by the impact to get the risk.
''';

String primerJson({String domain = 'CISSP', String topic = 'Risk basics', String title = 'Risk in five minutes', List<Map<String, String>>? pretest}) => jsonEncode({
      'primer': {
        'domain': domain,
        'topic': topic,
        'title': title,
        'level': 2,
        'pretest': pretest ?? [{'question': 'What is risk?', 'answer': 'Likelihood times impact.'}, {'question': 'What is a threat?', 'answer': 'Something that can exploit a weakness.'}],
        'sections': [{'heading': 'Risk', 'text': 'Risk is likelihood times impact. ' * 20}],
        'key_points': ['Risk combines likelihood and impact.'],
        'sources': ['Lecture 1'],
      }
    });

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('lecture transcripts (D67)', () {
    test('a subject is found without regard to case and made when it is new; lectures are numbered in order', () async {
      final svc = SourceService(db);
      final id = await svc.ensureDomain('CISSP');
      expect(await svc.ensureDomain('  cissp '), id);
      expect(await svc.nextNumber(id), 1);
      final a = await svc.add(domainId: id, title: 'Security and risk', text: srt, note: 'https://example.com/v1');
      final b = await svc.add(domainId: id, title: 'Assets', text: 'Plain text lecture about assets.');
      expect(a, isNotNull);
      final all = await svc.forDomain(id);
      expect(all.map((s) => (s.number, s.title)), [(1, 'Security and risk'), (2, 'Assets')]);
      expect(all.first.body, startsWith('[0:01] Risk is the likelihood'));
      expect(all.first.body, isNot(contains('-->')));
      expect(all.first.note, 'https://example.com/v1');
      expect(await svc.count(id), 2);
      expect(b, isNot(a));
    });

    test('an empty text or a missing title saves nothing', () async {
      final svc = SourceService(db);
      final id = await svc.ensureDomain('X');
      expect(await svc.add(domainId: id, title: 'T', text: '   \n  '), isNull);
      expect(await svc.add(domainId: id, title: '  ', text: 'text'), isNull);
      expect(await svc.count(id), 0);
      expect(await svc.indexFor(id), isNull, reason: 'no transcripts, nothing to check against');
    });

    test('lecture references for the course map, and deleting', () async {
      final svc = SourceService(db);
      final id = await svc.ensureDomain('CISSP');
      await svc.add(domainId: id, title: 'One', text: 'a b c d e');
      final two = await svc.add(domainId: id, title: 'Two', text: 'f g h');
      final refs = await svc.lectureRefs(id);
      expect(refs.map((r) => (r.number, r.title, r.excerpt)), [(1, 'One', 'a b c d e'), (2, 'Two', 'f g h')]);
      await svc.delete(two!);
      expect(await svc.count(id), 1);
      expect(await svc.get(two), isNull);
    });
  });

  group('the quote check in the card preview (D67)', () {
    Future<String> cards(String quote, {String sourceType = 'quote'}) async => jsonEncode({
          'domain': 'CISSP',
          'syllabus_item': 'Risk basics',
          'cards': [
            {'type': 'basic', 'front': 'What is risk?', 'back': 'Likelihood times impact.', 'source_type': sourceType, 'source_ref': '', 'supporting_quote': quote, 'confidence': 'high', 'tags': []},
          ]
        });

    test('with transcripts, a quote that is there is found and a paraphrase is not', () async {
      final svc = SourceService(db);
      final id = await svc.ensureDomain('CISSP');
      await svc.add(domainId: id, title: 'L1', text: srt);
      final imp = ImportService(db);
      final ok = await imp.preview(await cards('Risk is the likelihood of a threat exploiting a vulnerability.'));
      expect(ok.quote[0], QuoteCheck.found);
      final bad = await imp.preview(await cards('Risk means how probable it is that attackers use a weakness against you.'));
      expect(bad.quote[0], QuoteCheck.notFound);
      expect(bad.status[0], PreviewStatus.ok, reason: 'a card whose quote is not found is still importable: the screen decides what to tick');
    });

    test('nothing is checked without transcripts, for model memory, for an empty or very short quote', () async {
      final imp = ImportService(db);
      expect((await imp.preview(await cards('Risk is the likelihood of a threat exploiting a vulnerability.'))).quote, isEmpty);
      final svc = SourceService(db);
      await svc.add(domainId: await svc.ensureDomain('CISSP'), title: 'L1', text: srt);
      expect((await imp.preview(await cards('whatever the AI remembers about risk today', sourceType: 'model_memory'))).quote, isEmpty);
      expect((await imp.preview(await cards(''))).quote, isEmpty);
      expect((await imp.preview(await cards('risk is'))).quote, isEmpty);
    });
  });

  group('primers (D68)', () {
    late int domainId;
    setUp(() async {
      domainId = await SourceService(db).ensureDomain('CISSP');
      await db.into(db.syllabusItems).insert(SyllabusItemsCompanion.insert(domainId: domainId, title: 'Risk basics', position: const Value(1)));
    });

    test('the preview says what each primer would do', () async {
      final svc = PrimerService(db);
      var plan = await svc.preview(primerJson());
      expect(plan.rows.single.status, PrimerStatus.ok);
      expect(plan.rows.single.topicTitle, 'Risk basics');
      expect((await svc.preview(primerJson(topic: '  risk BASICS '))).rows.single.status, PrimerStatus.ok, reason: 'matched like card topics: case and spacing do not matter');
      expect((await svc.preview(primerJson(topic: 'Something new'))).rows.single.status, PrimerStatus.newTopic);
      expect((await svc.preview(primerJson(domain: 'Unknown subject'))).rows.single.status, PrimerStatus.noSubject);
      expect((await svc.preview(jsonEncode({'primer': {'domain': 'CISSP'}}))).rows.single.status, PrimerStatus.invalid);
      await svc.commit(plan, {0});
      plan = await svc.preview(primerJson());
      expect(plan.rows.single.status, PrimerStatus.replaces);
      expect(svc.preview('nope'), completion(isA<PrimerPlan>()));
    });

    test('commit adds a primer, replaces one (unread again), and makes a new topic at the end of the subject', () async {
      final svc = PrimerService(db);
      var r = await svc.commit(await svc.preview(primerJson()), {0});
      expect((r.added, r.replaced, r.topicsCreated), (1, 0, 0));
      final topicId = (await db.select(db.syllabusItems).get()).single.id;
      var stored = (await svc.forTopic(topicId))!;
      expect(stored.primer.title, 'Risk in five minutes');
      expect(stored.primer.pretest.length, 2);
      expect(stored.read, isFalse);

      await svc.markRead(stored.id);
      await svc.markRead(stored.id);
      stored = (await svc.forTopic(topicId))!;
      expect((stored.read, stored.readCount), (true, 2));

      r = await svc.commit(await svc.preview(primerJson(title: 'Risk, second version')), {0});
      expect((r.added, r.replaced), (0, 1));
      stored = (await svc.forTopic(topicId))!;
      expect(stored.primer.title, 'Risk, second version');
      expect(stored.read, isFalse, reason: 'new content is unread');
      expect(stored.readCount, 2, reason: 'the count of readings is kept');
      expect(await db.select(db.primers).get().then((x) => x.length), 1, reason: 'one primer per topic');

      r = await svc.commit(await svc.preview(primerJson(topic: 'A brand new topic')), {0});
      expect((r.added, r.topicsCreated), (1, 1));
      final items = await db.select(db.syllabusItems).get();
      final fresh = items.firstWhere((i) => i.title == 'A brand new topic');
      expect((fresh.position, fresh.level), (2, 2));
      expect((await svc.forDomain(domainId)).length, 2);
    });

    test('two primers for the same new topic in one file make one topic', () async {
      final svc = PrimerService(db);
      final raw = jsonEncode({
        'primers': [
          (jsonDecode(primerJson(topic: 'New one')) as Map)['primer'],
          (jsonDecode(primerJson(topic: 'new   one', title: 'Second')) as Map)['primer'],
        ]
      });
      final plan = await svc.preview(raw);
      final r = await svc.commit(plan, {0, 1});
      expect(r.topicsCreated, 1);
      expect((await db.select(db.syllabusItems).get()).where((i) => i.title.toLowerCase().contains('new')).length, 1);
      expect((await db.select(db.primers).get()).length, 1);
    });

    test('only the ticked primers are saved', () async {
      final svc = PrimerService(db);
      final raw = jsonEncode({
        'primers': [
          (jsonDecode(primerJson(topic: 'Risk basics')) as Map)['primer'],
          (jsonDecode(primerJson(topic: 'Other')) as Map)['primer'],
        ]
      });
      final r = await svc.commit(await svc.preview(raw), {1});
      expect((r.added, r.topicsCreated), (1, 1));
      expect((await db.select(db.primers).get()).length, 1);
    });

    test('the pretest questions become ordinary cards in the topic, once', () async {
      final svc = PrimerService(db);
      await svc.commit(await svc.preview(primerJson()), {0});
      final id = (await db.select(db.primers).getSingle()).id;
      expect(await svc.addPretestAsCards(id), 2);
      final notes = await db.select(db.notes).get();
      expect(notes.length, 2);
      expect(notes.every((n) => n.tags.contains('primer')), isTrue);
      expect(notes.first.syllabusItemId, (await db.select(db.syllabusItems).getSingle()).id);
      expect(await db.select(db.cards).get().then((c) => c.length), 2);
      expect(await svc.addPretestAsCards(id), 0, reason: 'a question already in the subject is not added twice');
      await svc.commit(await svc.preview(primerJson(topic: 'No pretest', pretest: [])), {0});
      final other = (await db.select(db.primers).get()).firstWhere((p) => p.id != id).id;
      expect(await svc.addPretestAsCards(other), 0);
    });

    test('a damaged stored primer reads back without throwing', () async {
      final p = primerFromStored(domain: 'D', topic: 'T', title: 'x', level: 9, content: '{"sections": [5, {"text": 7}, {"heading": "h", "text": "ok"}], "pretest": "no", "key_points": [1, "k"]}');
      expect(p.level, 3);
      expect(p.sections.single.text, 'ok');
      expect(p.pretest, isEmpty);
      expect(p.keyPoints, ['k']);
      expect(primerFromStored(domain: 'D', topic: 'T', title: '', level: 1, content: 'not json').sections, isEmpty);
    });
  });

  test('migration v9 -> v10 creates the two tables and keeps the data', () async {
    final dir = Directory.systemTemp.createTempSync('mig10');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/m.db');
    var d = AppDatabase(NativeDatabase(f));
    final dom = await d.into(d.domains).insert(DomainsCompanion.insert(name: 'Old', createdAt: 1));
    await d.into(d.syllabusItems).insert(SyllabusItemsCompanion.insert(domainId: dom, title: 'T'));
    await d.close();

    final raw = sql.sqlite3.open(f.path);
    raw.execute('DROP TABLE source');
    raw.execute('DROP TABLE primer');
    raw.execute('PRAGMA user_version = 9');
    raw.close();

    d = AppDatabase(NativeDatabase(f));
    addTearDown(d.close);
    expect((await d.select(d.domains).getSingle()).name, 'Old');
    expect(await d.select(d.sources).get(), isEmpty);
    expect(await d.select(d.primers).get(), isEmpty);
    final src = await d.into(d.sources).insert(SourcesCompanion.insert(domainId: dom, title: 'L', body: 'text', createdAt: 1));
    expect(src, greaterThan(0));
  });
}
