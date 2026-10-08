import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/learn_service.dart';
import 'package:daily_learning/data/outline_service.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/data/starter_library.dart';
import 'package:daily_learning/domain/growth.dart';
import 'package:daily_learning/domain/import_parser.dart' show normalizeText;
import 'package:daily_learning/domain/learn_planner.dart';
import 'package:daily_learning/domain/map_prompt.dart';
import 'package:daily_learning/domain/prompt_template.dart';
import 'package:daily_learning/domain/subject_catalog.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

DomainInfo dom(int id, String name, {int items = 5, int weight = 2, double? interest, double? stale}) =>
    DomainInfo(id: id, name: name, itemCount: items, weight: weight, avgInterest: interest, daysSinceLastImport: stale);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const planner = GrowthPlanner();

  group('catalog', () {
    test('is large, unique and spread over many areas', () {
      final names = kSubjectCatalog.map((c) => normalizeText(c.name)).toList();
      expect(names.toSet().length, names.length);
      expect(kSubjectCatalog.length, greaterThan(150));
      expect(kSubjectCatalog.map((c) => c.category).toSet().length, greaterThanOrEqualTo(10));
    });
    test('does not duplicate a bundled starter subject', () async {
      final starters = {for (final o in await StarterLibrary.load()) normalizeText(o.domain)};
      final overlap = [for (final c in kSubjectCatalog) if (starters.contains(normalizeText(c.name))) c.name];
      expect(overlap, isEmpty);
    });
  });

  group('GrowthPlanner (pure)', () {
    GrowthOption? plan(List<DomainInfo> d, {Set<String>? names, int steps = 0, Map<int, int> exp = const {}, int seed = 1}) =>
        planner.plan(domains: d, allSubjectNames: names ?? {for (final x in d) x.name}, growthSteps: steps, expansions: exp, seed: seed);

    test('a used-up subject is extended, with a different angle each time', () {
      final d = [dom(1, 'Biology')];
      final angles = {for (var r = 0; r < 6; r++) plan(d, exp: {1: r})!.goal};
      expect(angles.length, 6);
      expect(plan(d)!.kind, GrowthKind.expand);
      expect(plan(d)!.reasons.join(' '), contains('Biology'));
    });

    test('every third step asks the LLM for new subjects, steering it to untouched areas', () {
      final d = [dom(1, 'Biology'), dom(2, 'Music Theory Basics')];
      final kinds = [for (var s = 0; s < 6; s++) plan(d, steps: s)!.kind];
      expect(kinds, [GrowthKind.expand, GrowthKind.expand, GrowthKind.map, GrowthKind.expand, GrowthKind.expand, GrowthKind.map]);
      final g = plan(d, steps: 2)!;
      expect(g.ideas, isNotEmpty);
      expect(g.ideas, isNot(contains('Music Theory Basics'))); // already have it
      expect(g.ideas.every((n) => kSubjectCatalog.any((c) => c.name == n)), isTrue);
    });

    test('ideas are spread over many areas, not one', () {
      final g = plan([dom(1, 'Biology')], steps: 2)!;
      final cats = {for (final n in g.ideas) kSubjectCatalog.firstWhere((c) => c.name == n).category};
      expect(cats.length, greaterThanOrEqualTo(10));
    });

    test('same inputs and seed give the same answer', () {
      final d = [dom(1, 'A'), dom(2, 'B'), dom(3, 'C')];
      expect(plan(d, seed: 7)!.key, plan(d, seed: 7)!.key);
    });

    test('a high-priority, interesting, stale subject is preferred; paused ones never', () {
      final d = [dom(1, 'Dull', weight: 1), dom(2, 'Loved', weight: 3, interest: 0.8, stale: 400), dom(3, 'Paused', weight: 0)];
      for (var s = 0; s < 20; s++) {
        expect(plan(d, seed: s)!.domainName, 'Loved');
      }
    });

    test('a subject started without an outline is asked for again before anything else', () {
      final g = plan([dom(1, 'Biology'), dom(2, 'Astronomy and Cosmology', items: 0)], steps: 2)!;
      expect(g.kind, GrowthKind.resume);
      expect(g.domainName, 'Astronomy and Cosmology');
    });

    test('everything switched off on purpose -> nothing is proposed', () {
      expect(plan([dom(1, 'A', weight: 0), dom(2, 'B', weight: 0)]), isNull);
    });

    test('with no subjects at all, new subjects are requested', () {
      expect(plan([], names: {})!.kind, GrowthKind.map);
    });
  });

  test('outline prompt lists only the newest titles for a huge subject', () {
    final titles = [for (var i = 1; i <= 150; i++) 'Topic $i'];
    final text = renderOutlinePrompt(domain: 'Biology', existingTitles: titles);
    expect(text, contains('- Topic 150'));
    expect(text, contains('- Topic 51'));
    expect(text, isNot(contains('- Topic 50\n')));
    expect(text, contains('50 earlier topics not listed'));
  });

  group('end to end: the library never dead-ends', () {
    late AppDatabase db;
    late LearnService learn;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      final s = SettingsRepo(db);
      learn = LearnService(db, s, QueueService(db, s));
    });
    tearDown(() => db.close());

    Future<void> addOutline(String domain, List<String> titles) async {
      final svc = OutlineService(db);
      final json = '{"domain":"$domain","items":[${titles.map((t) => '{"title":"$t","target_cards":5}').join(',')}]}';
      await svc.commit(await svc.preview(json));
    }

    test('used-up subject -> outline prompt -> paste -> new topics are offered; repeat forever', () async {
      await addOutline('Biology', ['Cells', 'Genes']);
      for (final it in await db.select(db.syllabusItems).get()) {
        await learn.setTopicSkipped(it.id, true); // stand-in for "everything covered"
      }
      var v = await learn.view();
      expect(v.plan.options, isEmpty);
      expect(v.growth!.kind, GrowthKind.expand);

      final p1 = await learn.chooseGrowth(v.growth!, v);
      expect(p1.text, contains('Biology'));
      expect(p1.text, contains('- Cells'));
      expect(p1.text, contains(kExpansionAngles[0].substring(0, 20)));
      expect((await db.select(db.promptLogs).get()).single.templateVersion, kOutlineTemplateVersion);
      expect((await db.select(db.engineDecisions).get()).single.engineVersion, GrowthPlanner.version);

      await addOutline('Biology', ['Proteins', 'Enzymes', 'Membranes']);
      v = await learn.view();
      expect(v.plan.options, isNotEmpty); // new topics are now offered
      expect(v.plan.options.first.item.title, anyOf('Proteins', 'Enzymes', 'Membranes'));
    });

    test('third growth step is the map prompt: whole-library summary, no cards, logged without a subject', () async {
      await addOutline('Biology', ['Cells', 'Genes']);
      await addOutline('Music Theory Basics', ['Pitch']);
      for (final it in await db.select(db.syllabusItems).get()) {
        await learn.setTopicSkipped(it.id, true);
      }
      GrowthKind? kind;
      late GeneratedPrompt p;
      for (var i = 0; i < 3; i++) {
        final v = await learn.view();
        kind = v.growth!.kind;
        p = await learn.chooseGrowth(v.growth!, v);
      }
      expect(kind, GrowthKind.map);
      expect(p.text, contains('- Biology (2 topics, 0 cards'));
      expect(p.text, contains('Cells'));
      expect(p.text, contains('"subjects"'));
      expect(p.text, isNot(contains('"front"'))); // never asks for or contains cards
      final log = (await db.select(db.promptLogs).get()).last;
      expect(log.domainId, isNull);
      expect(log.templateVersion, kMapTemplateVersion);
      final pend = (await learn.pending())!;
      expect(pend.isMap, isTrue);
      expect(pend.domainName, 'Your whole library');
    });

    test('a subject whose outline never arrived is asked for again', () async {
      await addOutline('Biology', ['Cells']);
      for (final it in await db.select(db.syllabusItems).get()) {
        await learn.setTopicSkipped(it.id, true);
      }
      await learn.outlinePrompt('Astronomy'); // started, never answered
      final v = await learn.view();
      expect(v.growth!.kind, GrowthKind.resume);
      expect(v.growth!.domainName, 'Astronomy');
    });
  });
}
