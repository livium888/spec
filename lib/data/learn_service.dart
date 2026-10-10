import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show AssetBundle;

import '../domain/growth.dart';
import '../domain/learn_planner.dart';
import '../domain/map_prompt.dart';
import '../domain/prompt_template.dart';
import '../domain/study_advisor.dart';
import 'db/database.dart';
import 'engine_service.dart';
import 'outline_service.dart';
import 'pace.dart';
import 'queue_service.dart';
import 'starter_library.dart';
import 'settings_repo.dart';

const _day = 86400000;

class PendingPrompt {
  const PendingPrompt({
    required this.id,
    required this.text,
    required this.templateVersion,
    required this.domainName,
    required this.itemTitle,
    required this.createdAt,
  });
  final int id, createdAt;
  final String text, templateVersion, domainName;
  final String? itemTitle;
  bool get isOutline => templateVersion.startsWith('outline');
  bool get isMap => templateVersion.startsWith('map');
  PromptKind get kind => isMap ? PromptKind.plan : (isOutline ? PromptKind.outline : PromptKind.cards);
}

class LearnView {
  const LearnView(this.plan, this.pending, this.seed, this.advice, {this.growth});
  final LearnPlan plan;
  final PendingPrompt? pending;
  final int seed;

  /// Should you add new material now, and why.
  final Advice advice;

  /// How the library itself would grow (more topics, or a new subject). Used when
  /// there is nothing left to teach, and offered under "See all options".
  final GrowthOption? growth;
}

/// What the LLM's answer to a prompt should contain.
enum PromptKind { cards, outline, plan }

class GeneratedPrompt {
  const GeneratedPrompt(this.logId, this.text, this.headline,
      {this.reasons = const [], this.kind = PromptKind.cards});
  final PromptKind kind;
  final int logId;
  final String text, headline;

  /// Why the app picked this, in plain words.
  final List<String> reasons;
}

/// "Learn something new": gathers facts from the DB, runs the pure
/// [LearnPlanner], and turns the user's choice into a logged prompt.
class LearnService {
  LearnService(this.db, this.settings, this.queue,
      {this.planner = const LearnPlanner(), this.growth = const GrowthPlanner()});
  final AppDatabase db;
  final SettingsRepo settings;
  final QueueService queue;
  final LearnPlanner planner;
  final GrowthPlanner growth;

  Future<LearnView> view({DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc();
    await refreshStatuses();
    final clock = await settings.dayClock();
    final seed = clock.dayIndex(t); // same day => same plan; next day may differ among ties
    final plan = (await _planner()).plan(
      domains: await _domains(t),
      items: await _items(t),
      capacity: await _capacity(t),
      seed: seed,
    );
    return LearnView(plan, await pending(now: t), seed, await advice(now: t),
        growth: await growthOption(seed: seed, now: t));
  }

  /// What would extend the library: more topics for a subject you have used up, a brand-new
  /// subject, or a subject whose outline never arrived. Null only if nothing can grow.
  Future<GrowthOption?> growthOption({required int seed, DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc();
    final names = [for (final d in await db.select(db.domains).get()) d.name];
    final steps = (await db.customSelect(
            "SELECT COUNT(*) AS n FROM prompt_log WHERE template_version LIKE 'outline-%'").getSingle())
        .read<int>('n');
    final per = await db.customSelect(
        "SELECT domain_id, COUNT(*) AS n FROM prompt_log WHERE template_version LIKE 'outline-%' GROUP BY domain_id").get();
    return growth.plan(
      domains: await _domains(t),
      allSubjectNames: names.toSet(),
      growthSteps: steps,
      expansions: {for (final r in per) r.read<int>('domain_id'): r.read<int>('n')},
      seed: seed,
    );
  }

  /// Turn a growth step into a prompt (outline for one subject, or the library-wide map prompt) and log why.
  Future<GeneratedPrompt> chooseGrowth(GrowthOption g, LearnView view, {DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc();
    final GeneratedPrompt out;
    if (g.kind == GrowthKind.map) {
      final text = renderMapPrompt(
        subjects: await appMap(t),
        ideas: g.ideas,
        learnerProfile: await settings.get(SettingsRepo.learnerProfile),
      );
      final id = await db.into(db.promptLogs).insert(PromptLogsCompanion.insert(
            createdAt: t.millisecondsSinceEpoch,
            templateVersion: kMapTemplateVersion,
            promptText: text,
            cardsRequested: 0,
          ));
      out = GeneratedPrompt(id, text, g.headline, kind: PromptKind.plan);
    } else {
      out = await outlinePrompt(g.domainName, goal: g.goal, now: t);
    }
    await db.into(db.engineDecisions).insert(EngineDecisionsCompanion.insert(
          ts: t.millisecondsSinceEpoch,
          engineVersion: GrowthPlanner.version,
          seed: view.seed,
          featuresJson: jsonEncode({'growth': true, 'domain': g.domainName, 'ideas': g.ideas}),
          scoresJson: '{}',
          chosenJson: jsonEncode({'key': g.key, 'kind': g.kind.name, 'prompt_log_id': out.logId}),
        ));
    return GeneratedPrompt(out.logId, out.text, g.headline, reasons: g.reasons, kind: out.kind);
  }

  /// Bounded summary of the whole library for the map prompt: subjects, counts, newest
  /// topic titles. Most recently active subjects first. Never includes cards.
  Future<List<MapSubject>> appMap(DateTime t) async {
    final topics = {
      for (final r in await db.customSelect(
          'SELECT domain_id AS d, COUNT(*) AS n FROM syllabus_item GROUP BY domain_id').get())
        r.read<int>('d'): r.read<int>('n')
    };
    final cards = {
      for (final r in await db.customSelect(
          'SELECT n.domain_id AS d, COUNT(*) AS c FROM card c JOIN note n ON n.id = c.note_id GROUP BY n.domain_id').get())
        r.read<int>('d'): r.read<int>('c')
    };
    final interest = {
      for (final r in await db.customSelect('SELECT domain_id AS d, AVG(value) AS a FROM interest_log GROUP BY domain_id').get())
        r.read<int>('d'): (r.data['a'] as num?)?.toDouble()
    };
    final active = {
      for (final r in await db.customSelect(
          'SELECT domain_id AS d, MAX(created_at) AS m FROM note GROUP BY domain_id').get())
        r.read<int>('d'): r.read<int?>('m') ?? 0
    };
    final doms = await db.select(db.domains).get()
      ..sort((a, b) => (active[b.id] ?? b.createdAt).compareTo(active[a.id] ?? a.createdAt));
    final out = <MapSubject>[];
    for (var i = 0; i < doms.length; i++) {
      final d = doms[i];
      // Titles only for the subjects that will be shown in detail; the rest are listed by name.
      final titles = i >= kMapDetailedSubjects + 40
          ? const <String>[]
          : [
              for (final r in await db.customSelect(
                  'SELECT title FROM syllabus_item WHERE domain_id = ? ORDER BY id DESC LIMIT ?',
                  variables: [Variable.withInt(d.id), Variable.withInt(kMapTitlesDetailed)]).get())
                r.read<String>('title')
            ];
      out.add(MapSubject(
        name: d.name,
        topics: topics[d.id] ?? 0,
        cards: cards[d.id] ?? 0,
        interest: interest[d.id],
        paused: !d.active || d.learnWeight == 0,
        recentTitles: titles,
      ));
    }
    return out;
  }

  /// First use: add every bundled subject (except name-it-yourself templates) so the
  /// very first press of "Learn something new" has something to pick from.
  /// Returns how many subjects were added. Safe to call repeatedly.
  Future<int> ensureStarterSubjects({AssetBundle? bundle}) async {
    final svc = OutlineService(db);
    var added = 0;
    for (final o in await StarterLibrary.load(bundle)) {
      if (o.askName) continue;
      final p = await svc.preview(o.raw);
      if (p.hasFatal || p.importable.isEmpty) continue;
      await svc.commit(p);
      added++;
    }
    return added;
  }

  /// Persist todo -> active -> done transitions derived from card counts.
  Future<void> refreshStatuses() async {
    final cards = await db.customSelect(_cardsPerItemSql).get();
    final count = {for (final r in cards) r.read<int>('item'): r.read<int>('cards')};
    final rows = await db.customSelect('SELECT id, status, target_cards FROM syllabus_item').get();
    for (final r in rows) {
      final stored = r.read<String>('status');
      final next =
          LearnPlanner.effectiveStatus(stored, count[r.read<int>('id')] ?? 0, r.read<int>('target_cards'));
      if (next != stored) {
        await (db.update(db.syllabusItems)..where((x) => x.id.equals(r.read<int>('id'))))
            .write(SyllabusItemsCompanion(status: Value(next)));
      }
    }
  }

  // One grouped pass each, never a correlated subquery per topic: the per-topic form
  // rescanned note/card/review_log once per topic and took 34 s at 25,000 cards.
  static const _cardsPerItemSql = '''
      SELECT n.syllabus_item_id AS item, COUNT(*) AS cards,
             SUM(CASE WHEN c.lapses >= 8 THEN 1 ELSE 0 END) AS leeches
      FROM card c JOIN note n ON n.id = c.note_id
      WHERE n.syllabus_item_id IS NOT NULL
      GROUP BY n.syllabus_item_id''';

  Future<LearnPlanner> _planner() async => planner.copyWith(
      revisitBaseMonths: (await settings.getInt(SettingsRepo.revisitMonths, 3)).clamp(1, 24),
      baseCount: (await settings.getInt(SettingsRepo.cardsPerPrompt, 10)).clamp(1, 200),
      enforceTimeRoom: false);

  /// 0 = never offer this subject, 1 low, 2 normal, 3 high.
  Future<void> setSubjectWeight(int domainId, int weight) =>
      (db.update(db.domains)..where((d) => d.id.equals(domainId)))
          .write(DomainsCompanion(learnWeight: Value(weight.clamp(0, 3))));

  /// Target recall for one subject (0.70 to 0.97); null = the app-wide target. A lower target means
  /// longer gaps and fewer reviews. Applies to reviews from now on.
  Future<void> setSubjectRetention(int domainId, double? retention) =>
      (db.update(db.domains)..where((d) => d.id.equals(domainId)))
          .write(DomainsCompanion(retention: Value(retention == null ? null : double.parse(retention.clamp(0.70, 0.97).toStringAsFixed(3)))));

  /// Read this subject's cards aloud in [lang] (BCP-47) from the written-in-that-language [side]
  /// ('front' or 'back'); null lang turns it off.
  Future<void> setSubjectSpeech(int domainId, String? lang, {String side = 'back'}) =>
      (db.update(db.domains)..where((d) => d.id.equals(domainId))).write(DomainsCompanion(
          speechLang: Value(lang), speechSide: Value(side == 'front' ? 'front' : 'back')));

  /// Whether finished topics of this subject come back for deeper cards.
  Future<void> setSubjectRevisit(int domainId, bool on) =>
      (db.update(db.domains)..where((d) => d.id.equals(domainId)))
          .write(DomainsCompanion(revisit: Value(on)));

  /// A prompt to make cards for one topic chosen by hand (the map and the topic list use it).
  Future<GeneratedPrompt> promptForTopic(int itemId, {DateTime? now}) async {
    final it = await (db.select(db.syllabusItems)..where((x) => x.id.equals(itemId))).getSingle();
    final dom = await (db.select(db.domains)..where((d) => d.id.equals(it.domainId))).getSingle();
    final cards = (await db.customSelect(
            'SELECT COUNT(*) AS n FROM card c JOIN note n ON n.id = c.note_id WHERE n.syllabus_item_id = ?',
            variables: [Variable.withInt(itemId)])
        .getSingle())
        .read<int>('n');
    final stats = ItemStats(
      id: it.id, domainId: it.domainId, domainName: dom.name, title: it.title,
      position: it.position, status: it.status, targetCards: it.targetCards, cardCount: cards, rounds: it.rounds,
    );
    final deeper = it.status == 'done' && cards > 0;
    final opt = LearnOption(
      action: deeper ? LearnAction.revisit : (cards == 0 ? LearnAction.newItem : LearnAction.deepen),
      item: stats,
      score: 0,
      reasons: const ['Chosen by you.'],
      count: deeper ? const LearnPlanner().revisitStep(it.targetCards) : (cards == 0 ? it.targetCards.clamp(1, 10) : (it.targetCards - cards).clamp(1, 10)),
    );
    return choose(opt, await view(), manual: true, now: now);
  }

  /// What a topic is practised with: '' (the AI decides), 'concepts', 'problems' or 'both' (D43).
  Future<void> setTopicPractice(int itemId, String practice) =>
      (db.update(db.syllabusItems)..where((x) => x.id.equals(itemId)))
          .write(SyllabusItemsCompanion(practice: Value(const {'concepts', 'problems', 'both'}.contains(practice) ? practice : '')));

  /// Opt out of a topic (never offered), or put it back.
  Future<void> setTopicSkipped(int itemId, bool skipped) async {
    await (db.update(db.syllabusItems)..where((x) => x.id.equals(itemId)))
        .write(SyllabusItemsCompanion(status: Value(skipped ? 'skipped' : 'todo')));
    await refreshStatuses();
  }

  /// For the Topics screen: days until each finished topic returns (<= 0: due now).
  Future<Map<int, double>> returnsInDays({DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc();
    final p = await _planner();
    final doms = {for (final d in await _domains(t)) d.id: d};
    return {
      for (final it in await _items(t))
        if (it.status == 'done' &&
            it.cardCount > 0 &&
            it.daysSinceCovered != null &&
            (doms[it.domainId]?.revisit ?? true) &&
            (doms[it.domainId]?.weight ?? 2) > 0)
          it.id: p.cooldownDays(it.rounds) - it.daysSinceCovered!
    };
  }

  Future<void> setItemStatus(int itemId, String status) =>
      (db.update(db.syllabusItems)..where((x) => x.id.equals(itemId)))
          .write(SyllabusItemsCompanion(status: Value(status)));

  /// An issued prompt from the last 24h that has not been imported yet.
  Future<PendingPrompt?> pending({DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final row = await (db.select(db.promptLogs)
          ..where((p) => p.status.equals('issued') & p.createdAt.isBiggerOrEqualValue(t - _day))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt), (p) => OrderingTerm.desc(p.id)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    final dom = row.domainId == null
        ? null
        : await (db.select(db.domains)..where((d) => d.id.equals(row.domainId!))).getSingle();
    String? title;
    if (row.syllabusItemId != null) {
      title = (await (db.select(db.syllabusItems)..where((s) => s.id.equals(row.syllabusItemId!))).getSingle()).title;
    }
    return PendingPrompt(
        id: row.id, text: row.promptText, templateVersion: row.templateVersion,
        domainName: dom?.name ?? 'Your whole library', itemTitle: title, createdAt: row.createdAt);
  }

  Future<void> abandonPending(int promptId) =>
      (db.update(db.promptLogs)..where((p) => p.id.equals(promptId)))
          .write(const PromptLogsCompanion(status: Value('abandoned')));

  /// The user picked one of the shown options (or, with [manual], a topic of their own).
  Future<GeneratedPrompt> choose(
    LearnOption option,
    LearnView view, {
    bool manual = false,
    DateTime? now,
  }) async {
    final t = (now ?? DateTime.now()).toUtc();
    final it = option.item;
    final prompts = PromptService(db, settings: settings);
    final int logId;
    final String text;

    if (option.action == LearnAction.remediate) {
      final problems = await _problemCards(it.id, option.problemCount);
      text = renderRemediatePrompt(domain: it.domainName, syllabusItem: it.title, problems: problems);
      logId = await db.into(db.promptLogs).insert(PromptLogsCompanion.insert(
            createdAt: t.millisecondsSinceEpoch,
            domainId: Value(it.domainId),
            syllabusItemId: Value(it.id),
            templateVersion: kRemediateTemplateVersion,
            promptText: text,
            cardsRequested: option.count,
          ));
    } else {
      var round = 1;
      if (option.action == LearnAction.revisit) {
        // Raise the target and open a new round BEFORE building the prompt, so the
        // topic shows as "in progress" until the new cards arrive.
        round = it.rounds + 1;
        await (db.update(db.syllabusItems)..where((x) => x.id.equals(it.id))).write(
            SyllabusItemsCompanion(
                targetCards: Value(it.cardCount + option.count),
                rounds: Value(round),
                status: const Value('active')));
      }
      final r = await prompts.build(
          domainId: it.domainId,
          syllabusItemId: it.id,
          n: option.count,
          round: round,
          now: t);
      text = r.text;
      logId = r.logId;
    }

    await _logDecision(view, option, logId, manual: manual, now: t);
    return GeneratedPrompt(logId, text, option.headline, reasons: option.reasons);
  }

  /// Outline prompt for a new subject, or to add topics to an existing one.
  Future<GeneratedPrompt> outlinePrompt(String domainName, {String? goal, DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final name = domainName.trim();
    var dom = await (db.select(db.domains)..where((d) => d.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
    final domainId = dom?.id ??
        await db.into(db.domains).insert(DomainsCompanion.insert(name: name, createdAt: t));
    final existing = await (db.select(db.syllabusItems)
          ..where((s) => s.domainId.equals(domainId))
          ..orderBy([(s) => OrderingTerm.asc(s.position)]))
        .get();
    final text = renderOutlinePrompt(
        domain: dom?.name ?? name, goal: goal, existingTitles: [for (final e in existing) e.title]);
    final logId = await db.into(db.promptLogs).insert(PromptLogsCompanion.insert(
          createdAt: t,
          domainId: Value(domainId),
          templateVersion: kOutlineTemplateVersion,
          promptText: text,
          cardsRequested: 0,
        ));
    return GeneratedPrompt(logId, text, 'Outline for $name', kind: PromptKind.outline);
  }

  // ---- internals -----------------------------------------------------------

  Future<List<DomainInfo>> _domains(DateTime t) async {
    final nowMs = t.millisecondsSinceEpoch;
    final out = <DomainInfo>[];
    for (final d in await (db.select(db.domains)..where((x) => x.active.equals(true))).get()) {
      final interest = await db.customSelect(
          'SELECT AVG(value) AS a FROM interest_log WHERE domain_id = ? AND ts >= ?',
          variables: [Variable.withInt(d.id), Variable.withInt(nowMs - 30 * _day)]).getSingle();
      final last = await db.customSelect(
          'SELECT MAX(created_at) AS m FROM note WHERE domain_id = ?',
          variables: [Variable.withInt(d.id)]).getSingle();
      final count = await db.customSelect(
          'SELECT COUNT(*) AS n FROM syllabus_item WHERE domain_id = ?',
          variables: [Variable.withInt(d.id)]).getSingle();
      final lastMs = last.read<int?>('m');
      out.add(DomainInfo(
        id: d.id,
        name: d.name,
        avgInterest: (interest.data['a'] as num?)?.toDouble(),
        daysSinceLastImport: lastMs == null ? null : (nowMs - lastMs) / _day,
        itemCount: count.read<int>('n'),
        weight: d.learnWeight,
        revisit: d.revisit,
      ));
    }
    return out;
  }

  Future<List<ItemStats>> _items(DateTime t) async {
    final since = t.millisecondsSinceEpoch - 30 * _day;
    final prereqs = <int, List<int>>{};
    for (final e in await db.select(db.syllabusPrereqs).get()) {
      prereqs.putIfAbsent(e.itemId, () => []).add(e.prereqId);
    }
    final rows = await db.customSelect('''
      SELECT s.id, s.domain_id, d.name AS dname, s.title, s.position, s.status, s.target_cards, s.rounds
      FROM syllabus_item s JOIN domain d ON d.id = s.domain_id
      WHERE d.active = 1
      ORDER BY s.domain_id, s.position''').get();
    final cards = {
      for (final r in await db.customSelect(_cardsPerItemSql).get()) r.read<int>('item'): r
    };
    final lastCovered = {
      for (final r in await db.customSelect(
          'SELECT syllabus_item_id AS item, MAX(created_at) AS m FROM note '
          'WHERE syllabus_item_id IS NOT NULL GROUP BY syllabus_item_id').get())
        r.read<int>('item'): r.read<int?>('m')
    };
    // Only the last 30 days of the log are read (review_log_time_idx), then grouped.
    final recent = {
      for (final r in await db.customSelect('''
        SELECT n.syllabus_item_id AS item, COUNT(*) AS rev,
               SUM(CASE WHEN l.rating = 1 THEN 1 ELSE 0 END) AS lap
        FROM review_log l JOIN card c ON c.id = l.card_id JOIN note n ON n.id = c.note_id
        WHERE l.reviewed_at >= ? AND l.revoked_at IS NULL AND l.state_before = 'review'
          AND n.syllabus_item_id IS NOT NULL
        GROUP BY n.syllabus_item_id''', variables: [Variable.withInt(since)]).get())
        r.read<int>('item'): r
    };
    final nowMs = t.millisecondsSinceEpoch;
    return [
      for (final r in rows)
        ItemStats(
          id: r.read<int>('id'),
          domainId: r.read<int>('domain_id'),
          domainName: r.read<String>('dname'),
          title: r.read<String>('title'),
          position: r.read<int>('position'),
          status: r.read<String>('status'),
          targetCards: r.read<int>('target_cards'),
          cardCount: cards[r.read<int>('id')]?.read<int>('cards') ?? 0,
          reviews30d: recent[r.read<int>('id')]?.read<int>('rev') ?? 0,
          lapses30d: (recent[r.read<int>('id')]?.data['lap'] as num?)?.toInt() ?? 0,
          leechCount: (cards[r.read<int>('id')]?.data['leeches'] as num?)?.toInt() ?? 0,
          prereqIds: prereqs[r.read<int>('id')] ?? const [],
          rounds: r.read<int>('rounds'),
          daysSinceCovered: lastCovered[r.read<int>('id')] == null
              ? null
              : (nowMs - lastCovered[r.read<int>('id')]!) / _day,
        )
    ];
  }

  /// Typical (median) seconds per ordinary review over 30 days (12 s until 20 reviews exist), as on Today (D55).
  Future<double> _avgSeconds(DateTime t) async {
    return ordinarySeconds(db, sinceMs: t.millisecondsSinceEpoch - 30 * _day, fallback: 12, min: 4, max: 60);
  }

  Future<Capacity> _capacity(DateTime t) async {
    final q = await queue.build(now: t);
    return Capacity(
      dueReviews: q.learning.length + q.reviews.length,
      avgSecondsPerReview: await _avgSeconds(t),
      budgetMinutes: await settings.getInt(SettingsRepo.dailyMinutes, 20),
    );
  }

  /// Whether to add new material now: go / go gently / hold off / done for today.
  Future<Advice> advice({DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc();
    final nowMs = t.millisecondsSinceEpoch;
    final clock = await settings.dayClock();
    final dayStart = clock.dayStartMs(t);
    final dayEnd = clock.dayEndMs(t);
    final q = await queue.build(now: t);

    Future<Map<String, Object?>> one(String sql, List<Variable> v) async =>
        (await db.customSelect(sql, variables: v).getSingle()).data;

    final spent = await one(
        'SELECT COALESCE(SUM(duration_ms), 0) AS ms FROM review_log WHERE revoked_at IS NULL AND reviewed_at >= ?',
        [Variable.withInt(dayStart)]);
    final upcoming = await one(
        "SELECT COUNT(*) AS n FROM card WHERE state = 'review' AND suspended = 0 AND due >= ? AND due < ?",
        [Variable.withInt(dayEnd), Variable.withInt(dayEnd + 7 * _day)]);
    final since = nowMs - 30 * _day;
    final r = await one('''
      SELECT SUM(CASE WHEN state_before = 'review' THEN 1 ELSE 0 END) AS answers,
             SUM(CASE WHEN state_before = 'review' AND rating > 1 THEN 1 ELSE 0 END) AS passed,
             SUM(CASE WHEN state_before = 'review' THEN 1 ELSE 0 END) AS revonly,
             SUM(CASE WHEN state_before = 'review' AND rating = 1 THEN 1 ELSE 0 END) AS lapsed,
             MAX(reviewed_at) AS last_at
      FROM review_log WHERE revoked_at IS NULL AND reviewed_at >= ?''', [Variable.withInt(since)]);
    final last = await one('SELECT MAX(reviewed_at) AS m FROM review_log WHERE revoked_at IS NULL', const []);
    final leech = await one('SELECT COUNT(*) AS n FROM card WHERE lapses >= 8', const []);
    int i(Object? v) => (v as num?)?.toInt() ?? 0;
    final answers = i(r['answers']);
    final lastMs = last['m'] as int?;

    return const StudyAdvisor().advise(AdviceInput(
      dueToday: q.learning.length + q.reviews.length,
      avgSecondsPerReview: await _avgSeconds(t),
      budgetMinutes: await settings.getInt(SettingsRepo.dailyMinutes, 20),
      spentSecondsToday: i(spent['ms']) / 1000,
      newIntroducedToday: q.newIntroducedToday,
      newLimit: q.newLimit,
      upcoming7dReviews: i(upcoming['n']),
      desiredRetention: await settings.getDouble(SettingsRepo.desiredRetention, 0.90),
      retention30d: answers == 0 ? null : i(r['passed']) / answers,
      answers30d: answers,
      lapseRate30d: i(r['revonly']) == 0 ? null : i(r['lapsed']) / i(r['revonly']),
      leechCount: i(leech['n']),
      daysSinceLastSession: lastMs == null ? null : (nowMs - lastMs) / _day,
      baseCount: (await settings.getInt(SettingsRepo.cardsPerPrompt, 10)).clamp(1, 200),
      limitShrinks: await settings.get(SettingsRepo.backlogShrink) == '1',
    ));
  }

  Future<List<({String front, String back})>> _problemCards(int itemId, int limit) async {
    final rows = await db.customSelect('''
      SELECT n.fields_json, n.type, c.ord FROM card c JOIN note n ON n.id = c.note_id
      WHERE n.syllabus_item_id = ? AND c.lapses >= 2
      ORDER BY c.lapses DESC, c.id LIMIT ?''',
        variables: [Variable.withInt(itemId), Variable.withInt(limit)]).get();
    return [
      for (final r in rows)
        () {
          final f = jsonDecode(r.read<String>('fields_json')) as Map<String, dynamic>;
          final isCloze = r.read<String>('type') == 'cloze';
          return (
            front: (isCloze ? f['cloze'] : f['front']) as String? ?? '',
            back: (isCloze ? f['back'] : f['back']) as String? ?? '',
          );
        }()
    ];
  }

  Future<void> _logDecision(LearnView v, LearnOption chosen, int promptLogId,
      {required bool manual, required DateTime now}) {
    final plan = v.plan;
    return db.into(db.engineDecisions).insert(EngineDecisionsCompanion.insert(
          ts: now.millisecondsSinceEpoch,
          engineVersion: LearnPlanner.version,
          seed: v.seed,
          featuresJson: jsonEncode({
            'capacity': {
              'due_reviews': plan.capacity.dueReviews,
              'avg_seconds_per_review': plan.capacity.avgSecondsPerReview,
              'budget_minutes': plan.capacity.budgetMinutes,
              'cards_room': plan.capacity.cardsRoom,
            },
            'blocked': plan.blockedReason != null,
            'candidates': [
              for (final c in plan.candidates)
                {
                  'key': c.key,
                  'domain_id': c.item.domainId,
                  'cards': c.item.cardCount,
                  'target': c.item.targetCards,
                  'leeches': c.item.leechCount,
                  'lapse_rate': c.item.lapseRate,
                }
            ],
          }),
          scoresJson: jsonEncode({for (final c in plan.candidates) c.key: c.score}),
          chosenJson: jsonEncode({
            'key': chosen.key,
            'manual': manual,
            'shown': [for (final o in plan.options) o.key],
            'explore_slot': [for (final o in plan.options) o.explore],
            'explore_eps': planner.exploreEps,
            'n_candidates': plan.candidates.length,
            'count': chosen.count,
            'prompt_log_id': promptLogId,
          }),
        ));
  }
}
