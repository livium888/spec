import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show AssetBundle;

import '../domain/learn_planner.dart';
import '../domain/prompt_template.dart';
import '../domain/study_advisor.dart';
import 'db/database.dart';
import 'engine_service.dart';
import 'outline_service.dart';
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
}

class LearnView {
  const LearnView(this.plan, this.pending, this.seed, this.advice);
  final LearnPlan plan;
  final PendingPrompt? pending;
  final int seed;

  /// Should you add new material now, and why.
  final Advice advice;
}

class GeneratedPrompt {
  const GeneratedPrompt(this.logId, this.text, this.headline, {this.reasons = const []});
  final int logId;
  final String text, headline;

  /// Why the app picked this, in plain words.
  final List<String> reasons;
}

/// "Learn something new": gathers facts from the DB, runs the pure
/// [LearnPlanner], and turns the user's choice into a logged prompt.
class LearnService {
  LearnService(this.db, this.settings, this.queue, {this.planner = const LearnPlanner()});
  final AppDatabase db;
  final SettingsRepo settings;
  final QueueService queue;
  final LearnPlanner planner;

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
    return LearnView(plan, await pending(now: t), seed, await advice(now: t));
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
    final rows = await db.customSelect('''
      SELECT s.id, s.status, s.target_cards,
        (SELECT COUNT(*) FROM card c JOIN note n ON n.id = c.note_id WHERE n.syllabus_item_id = s.id) AS cards
      FROM syllabus_item s''').get();
    for (final r in rows) {
      final stored = r.read<String>('status');
      final next = LearnPlanner.effectiveStatus(stored, r.read<int>('cards'), r.read<int>('target_cards'));
      if (next != stored) {
        await (db.update(db.syllabusItems)..where((x) => x.id.equals(r.read<int>('id'))))
            .write(SyllabusItemsCompanion(status: Value(next)));
      }
    }
  }

  Future<LearnPlanner> _planner() async => planner.copyWith(
      revisitBaseMonths: (await settings.getInt(SettingsRepo.revisitMonths, 3)).clamp(1, 24));

  /// 0 = never offer this subject, 1 low, 2 normal, 3 high.
  Future<void> setSubjectWeight(int domainId, int weight) =>
      (db.update(db.domains)..where((d) => d.id.equals(domainId)))
          .write(DomainsCompanion(learnWeight: Value(weight.clamp(0, 3))));

  /// Whether finished topics of this subject come back for deeper cards.
  Future<void> setSubjectRevisit(int domainId, bool on) =>
      (db.update(db.domains)..where((d) => d.id.equals(domainId)))
          .write(DomainsCompanion(revisit: Value(on)));

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
    final dom = await (db.select(db.domains)..where((d) => d.id.equals(row.domainId))).getSingle();
    String? title;
    if (row.syllabusItemId != null) {
      title = (await (db.select(db.syllabusItems)..where((s) => s.id.equals(row.syllabusItemId!))).getSingle()).title;
    }
    return PendingPrompt(
        id: row.id, text: row.promptText, templateVersion: row.templateVersion,
        domainName: dom.name, itemTitle: title, createdAt: row.createdAt);
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
    final prompts = PromptService(db);
    final int logId;
    final String text;

    if (option.action == LearnAction.remediate) {
      final problems = await _problemCards(it.id, option.problemCount);
      text = renderRemediatePrompt(domain: it.domainName, syllabusItem: it.title, problems: problems);
      logId = await db.into(db.promptLogs).insert(PromptLogsCompanion.insert(
            createdAt: t.millisecondsSinceEpoch,
            domainId: it.domainId,
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
          domainId: domainId,
          templateVersion: kOutlineTemplateVersion,
          promptText: text,
          cardsRequested: 0,
        ));
    return GeneratedPrompt(logId, text, 'Outline for $name');
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
      SELECT s.id, s.domain_id, d.name AS dname, s.title, s.position, s.status, s.target_cards, s.rounds,
        (SELECT MAX(n.created_at) FROM note n WHERE n.syllabus_item_id = s.id) AS last_covered,
        (SELECT COUNT(*) FROM card c JOIN note n ON n.id = c.note_id
           WHERE n.syllabus_item_id = s.id) AS cards,
        (SELECT COUNT(*) FROM card c JOIN note n ON n.id = c.note_id
           WHERE n.syllabus_item_id = s.id AND c.lapses >= 8) AS leeches,
        (SELECT COUNT(*) FROM review_log l JOIN card c ON c.id = l.card_id JOIN note n ON n.id = c.note_id
           WHERE n.syllabus_item_id = s.id AND l.revoked_at IS NULL AND l.reviewed_at >= ?
             AND l.state_before = 'review') AS rev30,
        (SELECT COUNT(*) FROM review_log l JOIN card c ON c.id = l.card_id JOIN note n ON n.id = c.note_id
           WHERE n.syllabus_item_id = s.id AND l.revoked_at IS NULL AND l.reviewed_at >= ?
             AND l.state_before = 'review' AND l.rating = 1) AS lap30
      FROM syllabus_item s JOIN domain d ON d.id = s.domain_id
      WHERE d.active = 1
      ORDER BY s.domain_id, s.position''',
        variables: [Variable.withInt(since), Variable.withInt(since)]).get();
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
          cardCount: r.read<int>('cards'),
          reviews30d: r.read<int>('rev30'),
          lapses30d: r.read<int>('lap30'),
          leechCount: r.read<int>('leeches'),
          prereqIds: prereqs[r.read<int>('id')] ?? const [],
          rounds: r.read<int>('rounds'),
          daysSinceCovered: r.read<int?>('last_covered') == null
              ? null
              : (nowMs - r.read<int>('last_covered')) / _day,
        )
    ];
  }

  /// Mean seconds per review over 30 days (12 s until 20 reviews exist).
  Future<double> _avgSeconds(DateTime t) async {
    final avg = await db.customSelect(
        'SELECT AVG(duration_ms) AS a, COUNT(*) AS n FROM review_log '
        'WHERE revoked_at IS NULL AND duration_ms BETWEEN 500 AND 120000 AND reviewed_at >= ?',
        variables: [Variable.withInt(t.millisecondsSinceEpoch - 30 * _day)]).getSingle();
    final n = avg.read<int>('n');
    return n >= 20 ? ((avg.data['a'] as num).toDouble() / 1000).clamp(4.0, 60.0) : 12.0;
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
      SELECT SUM(CASE WHEN state_before IN ('review','relearning') THEN 1 ELSE 0 END) AS answers,
             SUM(CASE WHEN state_before IN ('review','relearning') AND rating > 1 THEN 1 ELSE 0 END) AS passed,
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
