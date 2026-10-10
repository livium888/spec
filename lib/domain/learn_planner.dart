/// "Learn something new": decides WHAT to ask the LLM for. Pure and
/// deterministic given its inputs + seed. Weights are hand-set in v1 (see
/// docs/DECISIONS.md D11); every decision is logged so they can be fitted later.
library;

enum LearnAction { newItem, deepen, remediate, revisit }

/// Per-topic facts gathered from the database.
class ItemStats {
  const ItemStats({
    required this.id,
    required this.domainId,
    required this.domainName,
    required this.title,
    required this.position,
    required this.status,
    required this.targetCards,
    required this.cardCount,
    this.reviews30d = 0,
    this.lapses30d = 0,
    this.leechCount = 0,
    this.prereqIds = const [],
    this.rounds = 1,
    this.daysSinceCovered,
  });
  final int id, domainId, position, targetCards, cardCount;

  /// 1 = first pass; each revisit adds one.
  final int rounds;

  /// Days since cards were last added to this topic (null: never).
  final double? daysSinceCovered;
  final String domainName, title;

  /// todo | active | done | skipped (already normalised by the service).
  final String status;
  final int reviews30d, lapses30d, leechCount;
  final List<int> prereqIds;

  double get lapseRate => reviews30d == 0 ? 0 : lapses30d / reviews30d;
}

class DomainInfo {
  const DomainInfo({
    required this.id,
    required this.name,
    this.avgInterest,
    this.daysSinceLastImport,
    this.itemCount = 0,
    this.weight = 2,
    this.revisit = true,
  });
  final int id;
  final String name;

  /// How often this subject is offered: 0 off, 1 low, 2 normal, 3 high.
  final int weight;

  /// Whether finished topics in this subject come back later.
  final bool revisit;
  final double? avgInterest; // -1..1, null if never rated
  final double? daysSinceLastImport; // null if nothing imported yet
  final int itemCount;
}

class Capacity {
  const Capacity({
    required this.dueReviews,
    required this.avgSecondsPerReview,
    required this.budgetMinutes,
  });
  final int dueReviews;
  final double avgSecondsPerReview;
  final int budgetMinutes;

  /// Each new card costs roughly this many reviews in its first week.
  static const reviewsPerNewCardFirstWeek = 3;

  double get dueSeconds => dueReviews * avgSecondsPerReview;
  double get freeSeconds => (budgetMinutes * 60 - dueSeconds).clamp(0, double.infinity);
  int get cardsRoom =>
      (freeSeconds / (reviewsPerNewCardFirstWeek * avgSecondsPerReview)).floor();
}

class LearnOption {
  const LearnOption({
    required this.action,
    required this.item,
    required this.score,
    required this.reasons,
    required this.count,
    this.explore = false,
    this.problemCount = 0,
  });
  final LearnAction action;
  final ItemStats item;
  final double score;
  final List<String> reasons;
  final int count;

  /// True when this slot was filled by seeded exploration instead of rank 2.
  final bool explore;
  final int problemCount; // remediate: how many cards need rewriting

  LearnOption withCount(int n) => LearnOption(
      action: action, item: item, score: score, reasons: reasons, count: n,
      explore: explore, problemCount: problemCount);

  String get key => '${action.name}:${item.id}';

  String get headline => switch (action) {
        LearnAction.newItem => '${item.domainName}: ${item.title}',
        LearnAction.deepen => '${item.domainName}: more on ${item.title}',
        LearnAction.remediate => '${item.domainName}: fix hard cards in ${item.title}',
        LearnAction.revisit => '${item.domainName}: revisit ${item.title}',
      };
}

enum EmptyReason { none, noDomains, noSyllabus, allDone, allPaused }

class LearnPlan {
  const LearnPlan({
    required this.options,
    required this.candidates,
    required this.capacity,
    required this.emptyReason,
    this.blockedReason,
    this.domainsWithoutSyllabus = const [],
    this.nextRevisitInDays,
  });

  /// Days until the earliest finished topic becomes due for a revisit (null: none will).
  final double? nextRevisitInDays;
  final List<LearnOption> options; // 0..2 shown to the user
  final List<LearnOption> candidates; // everything eligible, ranked (for the log)
  final Capacity capacity;
  final EmptyReason emptyReason;

  /// Set when reviews already use up the daily budget.
  final String? blockedReason;
  final List<DomainInfo> domainsWithoutSyllabus;
}

/// Deterministic [0,1) value (splitmix64 finaliser), same idea as the fuzz.
double unitFromSeed(int seed) {
  var z = seed + 0x1E3779B97F4A7C15;
  z = (z ^ (z >>> 30)) * 0x3F58476D1CE4E5B9;
  z = (z ^ (z >>> 27)) * 0x14D049BB133111EB;
  z = z ^ (z >>> 31);
  return (z & 0xFFFFFFFFFFFF) / 0x1000000000000;
}

class LearnPlanner {
  const LearnPlanner({
    this.baseCount = 10,
    this.wipLimit = 2,
    this.exploreEps = 0.15,
    this.prereqFraction = 0.7,
    this.minRoom = 3,
    this.revisitBaseMonths = 3,
    this.enforceTimeRoom = true,
  });

  /// First revisit comes this many months after a topic was last extended;
  /// each later round waits twice as long (3, 6, 12, 24 ... months), capped at 12 years.
  final int revisitBaseMonths;

  /// When true, a prompt asks for fewer cards if the time budget is nearly used up. The app turns this
  /// off: how many cards to ask for is the learner's call ("cards per prompt", the daily limit).
  final bool enforceTimeRoom;

  static const maxCooldownDays = 12 * 365.0;

  LearnPlanner copyWith({int? revisitBaseMonths, int? baseCount, bool? enforceTimeRoom}) => LearnPlanner(
        baseCount: baseCount ?? this.baseCount,
        wipLimit: wipLimit,
        exploreEps: exploreEps,
        prereqFraction: prereqFraction,
        minRoom: minRoom,
        revisitBaseMonths: revisitBaseMonths ?? this.revisitBaseMonths,
        enforceTimeRoom: enforceTimeRoom ?? this.enforceTimeRoom,
      );

  /// Days a finished topic rests before it may be offered again.
  double cooldownDays(int rounds) {
    final d = revisitBaseMonths * 30.0 * (1 << (rounds - 1).clamp(0, 12));
    return d > maxCooldownDays ? maxCooldownDays : d;
  }

  /// Cards added in a revisit round.
  int revisitStep(int targetCards) => ((targetCards / 2).ceil()).clamp(5, 10);

  static const _weightFactor = {1: 0.6, 2: 1.0, 3: 1.4};

  final int baseCount;

  /// Max topics "in progress" per domain before a new one is opened.
  final int wipLimit;
  final double exploreEps;

  /// A prerequisite counts as met at this fraction of its target card count.
  final double prereqFraction;
  final int minRoom;

  static const version = 'planner-1';

  /// Status normalisation used by the service and the tests.
  static String effectiveStatus(String stored, int cards, int target) {
    if (stored == 'skipped') return 'skipped'; // the learner opted out of this topic
    if (stored == 'done') return 'done';
    if (cards >= target) return 'done';
    if (cards > 0) return 'active';
    return 'todo';
  }

  LearnPlan plan({
    required List<DomainInfo> domains,
    required List<ItemStats> items,
    required Capacity capacity,
    required int seed,
  }) {
    final byId = {for (final i in items) i.id: i};
    final domainById = {for (final d in domains) d.id: d};
    final cands = <LearnOption>[];

    bool prereqMet(ItemStats it) => it.prereqIds.every((id) {
          final p = byId[id];
          if (p == null) return true; // dangling edge: do not block forever
          return p.status == 'done' ||
              p.status == 'skipped' ||
              p.cardCount >= (p.targetCards * prereqFraction).ceil();
        });

    final room = capacity.cardsRoom;
    int sized(int wanted) => enforceTimeRoom
        ? wanted.clamp(1, 1 << 20).clamp(1, room < minRoom ? minRoom : room)
        : wanted.clamp(1, 1 << 20);
    double jitter(ItemStats it, int salt) => unitFromSeed(seed * 7919 + it.id * 31 + salt) * 1e-6;

    final byDomain = <int, List<ItemStats>>{};
    for (final it in items) {
      byDomain.putIfAbsent(it.domainId, () => []).add(it);
    }

    double? nextRevisit;
    for (final entry in byDomain.entries) {
      final dom = domainById[entry.key];
      final weight = dom?.weight ?? 2;
      final wf = _weightFactor[weight] ?? 1.0;
      final list = entry.value..sort((a, b) => a.position.compareTo(b.position));
      final active = list.where((i) => i.status == 'active').toList();

      // Revisit: finished topics come back after their cool-down, with new angles.
      // Tracked even for paused subjects so the "next revisit" hint stays honest.
      if (dom?.revisit ?? true) {
        ItemStats? best;
        var bestOver = 0.0;
        for (final it in list) {
          if (it.status != 'done' || it.cardCount == 0 || it.daysSinceCovered == null) continue;
          final cd = cooldownDays(it.rounds);
          final left = cd - it.daysSinceCovered!;
          if (left > 0) {
            if (weight > 0 && (nextRevisit == null || left < nextRevisit)) nextRevisit = left;
            continue;
          }
          final over = it.daysSinceCovered! / cd;
          if (best == null || over > bestOver) {
            best = it;
            bestOver = over;
          }
        }
        if (best != null && weight > 0) {
          final months = (best.daysSinceCovered! / 30).floor();
          final ago = months >= 24
              ? '${(months / 12).floor()} years ago'
              : months >= 2
                  ? '$months months ago'
                  : '${best.daysSinceCovered!.floor()} days ago';
          cands.add(LearnOption(
            action: LearnAction.revisit,
            item: best,
            score: (0.5 + 0.2 * (bestOver.clamp(1.0, 3.0) - 1.0) + 0.1 * ((dom?.avgInterest ?? 0).clamp(0.0, 1.0))) * wf +
                jitter(best, 4),
            reasons: [
              'You last added cards to ${best.title} $ago (round ${best.rounds}). Time for a deeper pass with new angles.'
            ],
            count: sized(revisitStep(best.targetCards)),
          ));
        }
      }
      if (weight == 0) continue; // paused subject: nothing else is offered

      // Deepen: finish what you started.
      for (final it in active) {
        final remaining = it.targetCards - it.cardCount;
        if (remaining <= 0) continue;
        cands.add(LearnOption(
          action: LearnAction.deepen,
          item: it,
          score: (0.2 + 0.8 * (remaining / it.targetCards)) * wf + jitter(it, 1),
          reasons: ['${it.title} has ${it.cardCount} of ${it.targetCards} cards.'],
          count: sized(remaining < baseCount ? remaining : baseCount),
        ));
      }

      // New topic: the first eligible one in curriculum order, if there is WIP room.
      if (active.length < wipLimit) {
        final next = list.where((i) => i.status == 'todo' && prereqMet(i)).firstOrNull;
        if (next != null) {
          final stale = dom?.daysSinceLastImport;
          final staleBonus = stale == null ? 0.2 : 0.2 * (stale / 7).clamp(0, 1);
          final interest = dom?.avgInterest ?? 0;
          final why = <String>[];
          final prereqTitles = [for (final id in next.prereqIds) if (byId[id] != null) byId[id]!.title];
          why.add(prereqTitles.isEmpty
              ? 'Next uncovered topic in ${next.domainName}.'
              : 'Next uncovered topic; ${prereqTitles.join(', ')} ${prereqTitles.length == 1 ? 'is' : 'are'} covered.');
          if (stale == null) {
            why.add('Nothing imported in ${next.domainName} yet.');
          } else if (stale >= 3) {
            why.add('${next.domainName} untouched for ${stale.floor()} days.');
          }
          if (interest > 0.3) why.add('You rated ${next.domainName} as interesting lately.');
          cands.add(LearnOption(
            action: LearnAction.newItem,
            item: next,
            score: (1.0 + 0.3 * interest + staleBonus) * wf + jitter(next, 2),
            reasons: why,
            count: sized(next.targetCards < baseCount ? next.targetCards : baseCount),
          ));
        }
      }

      // Remediate: leeches or a high lapse rate on enough data.
      for (final it in list) {
        if (it.status == 'skipped') continue;
        final lapsey = it.reviews30d >= 10 && it.lapseRate >= 0.25;
        if (it.leechCount < 2 && !lapsey) continue;
        final severity = (it.leechCount / 5 + it.lapseRate).clamp(0.0, 1.5);
        final problems = it.leechCount >= 2 ? it.leechCount : 5;
        cands.add(LearnOption(
          action: LearnAction.remediate,
          item: it,
          score: (0.9 + severity) * wf + jitter(it, 3),
          reasons: [
            if (it.leechCount >= 2) '${it.leechCount} stuck cards in ${it.title}.',
            if (lapsey) 'You forget ${(it.lapseRate * 100).round()}% of ${it.title} reviews.',
          ],
          count: problems.clamp(1, 10),
          problemCount: problems.clamp(1, 10),
        ));
      }
    }

    cands.sort((a, b) => b.score.compareTo(a.score));

    // Pick two: best, then runner-up on a different topic (or a seeded explore pick).
    final options = <LearnOption>[];
    if (cands.isNotEmpty) {
      options.add(cands.first);
      final rest = cands.skip(1).where((c) => c.item.id != cands.first.item.id).toList();
      if (rest.isNotEmpty) {
        final explore = rest.length > 1 && unitFromSeed(seed * 131 + 17) < exploreEps;
        if (explore) {
          final pick = rest.skip(1).toList();
          final idx = (unitFromSeed(seed * 211 + 5) * pick.length).floor().clamp(0, pick.length - 1);
          final c = pick[idx];
          options.add(LearnOption(
              action: c.action, item: c.item, score: c.score, reasons: c.reasons,
              count: c.count, explore: true, problemCount: c.problemCount));
        } else {
          options.add(rest.first);
        }
      }
    }

    final noSyllabus = [for (final d in domains) if (d.itemCount == 0) d];
    var empty = EmptyReason.none;
    if (options.isEmpty) {
      if (domains.isEmpty) {
        empty = EmptyReason.noDomains;
      } else if (domains.every((d) => d.weight == 0)) {
        empty = EmptyReason.allPaused;
      } else if (items.isEmpty) {
        empty = EmptyReason.noSyllabus;
      } else {
        empty = EmptyReason.allDone;
      }
    }

    String? blocked;
    if (room < minRoom) {
      final mins = (capacity.dueSeconds / 60).round();
      blocked = capacity.dueReviews == 0
          ? 'Your daily study budget is very small. New cards can wait.'
          : 'About $mins min of reviews are due, which uses most of your ${capacity.budgetMinutes}-minute budget. '
              'Finish reviews first, or add a few cards anyway.';
    }

    return LearnPlan(
      options: options,
      candidates: cands,
      capacity: capacity,
      emptyReason: empty,
      blockedReason: blocked,
      domainsWithoutSyllabus: noSyllabus,
      nextRevisitInDays: nextRevisit,
    );
  }
}
