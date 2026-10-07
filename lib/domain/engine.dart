/// Engine hooks. v1 ships only the data contract and a trivial implementation;
/// the real engine must record every choice in `engine_decision`.
class DomainFeatures {
  const DomainFeatures({
    required this.domainId,
    required this.domainName,
    required this.daysSinceLastSession,
    required this.reviews30d,
    required this.retention30d,
    required this.desiredRetention,
    required this.lapseRate30d,
    required this.leechCount,
    required this.dueBacklog,
    required this.newCardsAdded30d,
    required this.avgInterest30d,
    required this.cardsSurviving30d,
  });

  final int domainId;
  final String domainName;

  /// null if the domain has never been reviewed.
  final double? daysSinceLastSession;
  final int reviews30d;

  /// Actual retention: share of review-state answers rated Hard/Good/Easy. null if no data.
  final double? retention30d;
  final double desiredRetention;

  /// Lapses (Again on a review-state card) / review-state answers. null if no data.
  final double? lapseRate30d;
  final int leechCount;
  final int dueBacklog;
  final int newCardsAdded30d;

  /// Mean of interest_log values (-1..1). null if none logged.
  final double? avgInterest30d;

  /// Cards first answered more than 30 days ago that are currently in `review`
  /// and not suspended. (Definition chosen in v1; spec left it open — see DECISIONS D9.)
  final int cardsSurviving30d;

  Map<String, Object?> toJson() => {
        'domain_id': domainId,
        'domain': domainName,
        'days_since_last_session': daysSinceLastSession,
        'reviews_30d': reviews30d,
        'retention_30d': retention30d,
        'desired_retention': desiredRetention,
        'lapse_rate_30d': lapseRate30d,
        'leech_count': leechCount,
        'due_backlog': dueBacklog,
        'new_cards_added_30d': newCardsAdded30d,
        'avg_interest_30d': avgInterest30d,
        'cards_surviving_30d': cardsSurviving30d,
      };
}

class EngineFeatures {
  const EngineFeatures(this.tsMs, this.domains);
  final int tsMs;
  final List<DomainFeatures> domains;
  Map<String, Object?> toJson() => {
        'ts': tsMs,
        'domains': [for (final d in domains) d.toJson()],
      };
}

class Recommendation {
  const Recommendation(this.domainId, this.reason);
  final int? domainId; // null = nothing to recommend (no active domains)
  final String reason;
}

abstract interface class Engine {
  String get version;
  Recommendation next(EngineFeatures f, int seed);
}

/// Trivial placeholder: cycles through domains in id order; `seed` is the position.
class RoundRobinEngine implements Engine {
  @override
  String get version => 'round-robin-1';

  @override
  Recommendation next(EngineFeatures f, int seed) {
    if (f.domains.isEmpty) return const Recommendation(null, 'no active domains');
    final sorted = [...f.domains]..sort((a, b) => a.domainId.compareTo(b.domainId));
    final d = sorted[seed.abs() % sorted.length];
    return Recommendation(d.domainId, 'round-robin slot ${seed.abs() % sorted.length}');
  }
}
