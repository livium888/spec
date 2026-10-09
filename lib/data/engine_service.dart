import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/engine.dart';
import '../domain/prompt_template.dart';
import 'db/database.dart';
import 'settings_repo.dart';

const _day = 86400000;

/// EngineFeatures use case: per-domain signals for the future engine.
class EngineFeaturesService {
  EngineFeaturesService(this.db, this.settings);
  final AppDatabase db;
  final SettingsRepo settings;

  Future<EngineFeatures> compute({DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc();
    final nowMs = t.millisecondsSinceEpoch;
    final since = nowMs - 30 * _day;
    final dayEnd = (await settings.dayClock()).dayEndMs(t);
    final desired = await settings.getDouble(SettingsRepo.desiredRetention, 0.90);

    Future<Map<String, Object?>> one(String sql, List<Variable> vars) async =>
        (await db.customSelect(sql, variables: vars).getSingle()).data;

    final out = <DomainFeatures>[];
    for (final d in await (db.select(db.domains)..where((x) => x.active.equals(true))).get()) {
      final id = Variable.withInt(d.id);

      final logs = await one('''
        SELECT MAX(l.reviewed_at) AS last_at,
               SUM(CASE WHEN l.reviewed_at >= ? THEN 1 ELSE 0 END) AS n30,
               SUM(CASE WHEN l.reviewed_at >= ? AND l.state_before IN ('review','relearning') THEN 1 ELSE 0 END) AS rev30,
               SUM(CASE WHEN l.reviewed_at >= ? AND l.state_before IN ('review','relearning') AND l.rating > 1 THEN 1 ELSE 0 END) AS pass30,
               SUM(CASE WHEN l.reviewed_at >= ? AND l.state_before = 'review' THEN 1 ELSE 0 END) AS revonly30,
               SUM(CASE WHEN l.reviewed_at >= ? AND l.state_before = 'review' AND l.rating = 1 THEN 1 ELSE 0 END) AS lapse30
        FROM review_log l JOIN card c ON c.id = l.card_id JOIN note n ON n.id = c.note_id
        WHERE n.domain_id = ? AND l.revoked_at IS NULL''', [
        Variable.withInt(since), Variable.withInt(since), Variable.withInt(since),
        Variable.withInt(since), Variable.withInt(since), id,
      ]);
      int i(String k) => (logs[k] as int?) ?? 0;

      final cards = await one('''
        SELECT SUM(CASE WHEN c.lapses >= 8 THEN 1 ELSE 0 END) AS leeches,
               SUM(CASE WHEN c.state = 'review' AND c.suspended = 0 AND c.due < ? THEN 1 ELSE 0 END) AS backlog
        FROM card c JOIN note n ON n.id = c.note_id WHERE n.domain_id = ?''',
          [Variable.withInt(dayEnd), id]);

      final added = await one(
          'SELECT COUNT(*) AS n FROM card c JOIN note n ON n.id = c.note_id '
          'WHERE n.domain_id = ? AND n.created_at >= ?',
          [id, Variable.withInt(since)]);

      final interest = await one(
          'SELECT AVG(value) AS a FROM interest_log WHERE domain_id = ? AND ts >= ?',
          [id, Variable.withInt(since)]);

      final surviving = await one('''
        SELECT COUNT(*) AS n FROM card c JOIN note n ON n.id = c.note_id
        WHERE n.domain_id = ? AND c.state = 'review' AND c.suspended = 0
          AND (SELECT MIN(l.reviewed_at) FROM review_log l
               WHERE l.card_id = c.id AND l.revoked_at IS NULL) < ?''',
          [id, Variable.withInt(nowMs - 30 * _day)]);

      final lastAt = logs['last_at'] as int?;
      out.add(DomainFeatures(
        domainId: d.id,
        domainName: d.name,
        daysSinceLastSession: lastAt == null ? null : (nowMs - lastAt) / _day,
        reviews30d: i('n30'),
        retention30d: i('rev30') == 0 ? null : i('pass30') / i('rev30'),
        desiredRetention: desired,
        lapseRate30d: i('revonly30') == 0 ? null : i('lapse30') / i('revonly30'),
        leechCount: (cards['leeches'] as int?) ?? 0,
        dueBacklog: (cards['backlog'] as int?) ?? 0,
        newCardsAdded30d: added['n'] as int,
        avgInterest30d: (interest['a'] as num?)?.toDouble(),
        cardsSurviving30d: surviving['n'] as int,
      ));
    }
    return EngineFeatures(nowMs, out);
  }

  /// For the real engine later: persist what it saw, scored, and chose.
  Future<void> recordDecision({
    required String engineVersion,
    required int seed,
    required EngineFeatures features,
    required Map<String, Object?> scores,
    required Map<String, Object?> chosen,
    DateTime? now,
  }) =>
      db.into(db.engineDecisions).insert(EngineDecisionsCompanion.insert(
            ts: (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
            engineVersion: engineVersion,
            seed: seed,
            featuresJson: jsonEncode(features.toJson()),
            scoresJson: jsonEncode(scores),
            chosenJson: jsonEncode(chosen),
          ));
}

/// Prompt builder: renders the template and logs it to `prompt_log`.
class PromptService {
  PromptService(this.db, {this.settings});
  final AppDatabase db;

  /// When given, the learner's optional "about you" text is added to card prompts.
  final SettingsRepo? settings;

  Future<({int logId, String text})> build({
    required int domainId,
    int? syllabusItemId,
    required int n,
    String? sourceText,
    int round = 1,
    DateTime? now,
  }) async {
    final t = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final dom = await (db.select(db.domains)..where((d) => d.id.equals(domainId))).getSingle();
    String? syl;
    var practice = '';
    if (syllabusItemId != null) {
      final item = await (db.select(db.syllabusItems)..where((s) => s.id.equals(syllabusItemId))).getSingle();
      syl = item.title;
      practice = item.practice;
    }

    final titles = await recentTitles(domainId, syllabusItemId);

    final text = renderPrompt(
        domain: dom.name, syllabusItem: syl, n: n, recentTitles: titles, sourceText: sourceText, round: round,
        learnerProfile: await settings?.get(SettingsRepo.learnerProfile), practice: practice);

    // Prompts never imported within 14 days are abandoned.
    await (db.update(db.promptLogs)
          ..where((p) => p.status.equals('issued') & p.createdAt.isSmallerThanValue(t - 14 * _day)))
        .write(const PromptLogsCompanion(status: Value('abandoned')));

    final id = await db.into(db.promptLogs).insert(PromptLogsCompanion.insert(
          createdAt: t,
          domainId: Value(domainId),
          syllabusItemId: Value(syllabusItemId),
          templateVersion: round > 1 ? '$kPromptTemplateVersion+deeper' : kPromptTemplateVersion,
          promptText: text,
          cardsRequested: n,
        ));
    return (logId: id, text: text);
  }

  /// Titles the LLM must not repeat: this topic's cards first (up to 60),
  /// then the domain's most recent cards, 80 in total.
  Future<List<String>> recentTitles(int domainId, int? syllabusItemId) async {
    final out = <String>[];
    final seen = <String>{};
    void add(Iterable<Note> ns, int cap) {
      for (final n in ns) {
        if (out.length >= cap) return;
        final t = _short(_title(n));
        if (seen.add(t)) out.add(t);
      }
    }

    if (syllabusItemId != null) {
      add(
          await (db.select(db.notes)
                ..where((x) => x.syllabusItemId.equals(syllabusItemId))
                ..orderBy([(x) => OrderingTerm.desc(x.createdAt), (x) => OrderingTerm.desc(x.id)])
                ..limit(60))
              .get(),
          60);
    }
    add(
        await (db.select(db.notes)
              ..where((x) => x.domainId.equals(domainId))
              ..orderBy([(x) => OrderingTerm.desc(x.createdAt), (x) => OrderingTerm.desc(x.id)])
              ..limit(40))
            .get(),
        80);
    return out;
  }

  String _title(Note n) {
    final f = jsonDecode(n.fieldsJson) as Map<String, dynamic>;
    return ((n.type == 'cloze' ? f['cloze'] : f['front']) as String? ?? '').replaceAll('\n', ' ');
  }

  String _short(String s) => s.length <= 80 ? s : '${s.substring(0, 80)}…';
}

/// Interest signal, asked once per domain after a session.
class InterestService {
  InterestService(this.db);
  final AppDatabase db;

  Future<void> record(int domainId, int value, {DateTime? now}) {
    assert(value >= -1 && value <= 1);
    return db.into(db.interestLogs).insert(InterestLogsCompanion.insert(
        ts: (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
        domainId: domainId,
        value: value));
  }
}
