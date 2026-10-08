/// "Never runs out": decides how the library itself grows once there is nothing
/// left to teach right now. Pure and deterministic given its inputs and seed.
/// Hand-set rules (see docs/DECISIONS.md D23); every choice is logged.
library;

import 'import_parser.dart' show normalizeText;
import 'learn_planner.dart' show DomainInfo, unitFromSeed;
import 'subject_catalog.dart';

enum GrowthKind { expand, discover, resume }

/// Different angles, used in turn, so successive batches for one subject differ.
const kExpansionAngles = [
  'advanced and specialised topics that build on the foundations',
  'real-world applications, case studies and worked examples',
  'the people, history and turning points behind the ideas',
  'common misconceptions, edge cases and things experts argue about',
  'neighbouring areas that connect this subject to others',
  'practical skills, technique and how to actually do it',
];

class GrowthOption {
  const GrowthOption({
    required this.kind,
    required this.domainName,
    required this.reasons,
    required this.headline,
    this.domainId,
    this.goal,
    this.category,
  });
  final GrowthKind kind;
  final String domainName, headline;
  final int? domainId;

  /// Passed to the outline prompt as the learner goal (the angle for this batch).
  final String? goal;
  final String? category;
  final List<String> reasons;
  String get key => '${kind.name}:${domainId ?? domainName}';
}

class GrowthPlanner {
  const GrowthPlanner({this.catalog = kSubjectCatalog, this.discoverEvery = 3});
  final List<CatalogSubject> catalog;

  /// Every Nth growth step starts a new subject; the rest deepen one you already have.
  final int discoverEvery;

  static const version = 'growth-v1';

  /// [growthSteps]: outline prompts issued so far. [expansions]: per-subject count of them.
  /// [allSubjectNames]: every subject that exists, including paused ones.
  GrowthOption? plan({
    required List<DomainInfo> domains,
    required Set<String> allSubjectNames,
    required int growthSteps,
    required Map<int, int> expansions,
    required int seed,
  }) {
    // 1. A subject that was started but never got its outline: ask for it again.
    final empty = [for (final d in domains) if (d.weight > 0 && d.itemCount == 0) d];
    if (empty.isNotEmpty) {
      final d = empty[(unitFromSeed(seed) * empty.length).floor() % empty.length];
      return GrowthOption(
        kind: GrowthKind.resume,
        domainId: d.id,
        domainName: d.name,
        headline: 'Outline for ${d.name}',
        reasons: ['You started ${d.name} but its list of topics has not been added yet. Here is the prompt again.'],
      );
    }

    final used = {for (final n in allSubjectNames) normalizeText(n)};
    final fresh = [for (final c in catalog) if (!used.contains(normalizeText(c.name))) c];
    final usable = [for (final d in domains) if (d.weight > 0 && d.itemCount > 0) d];

    final wantDiscover = fresh.isNotEmpty &&
        (usable.isEmpty || growthSteps % discoverEvery == discoverEvery - 1);
    if (wantDiscover) return _discover(fresh, allSubjectNames, growthSteps, seed);
    if (usable.isNotEmpty) return _expand(usable, expansions, seed);
    return null; // nothing to grow from and nothing new to start
  }

  GrowthOption _expand(List<DomainInfo> usable, Map<int, int> expansions, int seed) {
    double score(DomainInfo d) {
      final stale = ((d.daysSinceLastImport ?? 0) / 365).clamp(0.0, 2.0);
      return d.weight + (d.avgInterest ?? 0) + stale - d.itemCount / 150 + unitFromSeed(seed * 31 + d.id) * 0.5;
    }

    final best = ([...usable]..sort((a, b) => score(b).compareTo(score(a)))).first;
    final round = expansions[best.id] ?? 0;
    final angle = kExpansionAngles[round % kExpansionAngles.length];
    return GrowthOption(
      kind: GrowthKind.expand,
      domainId: best.id,
      domainName: best.name,
      headline: 'More topics for ${best.name}',
      goal: 'continue this subject with new topics; this batch should lean towards $angle',
      reasons: [
        'You have worked through the topics in ${best.name} that were available (${best.itemCount} so far), '
            'so the next step is a fresh batch.',
        'This batch leans towards $angle.',
        if (best.weight >= 3) 'You gave this subject a high priority.'
        else if ((best.avgInterest ?? 0) > 0.3) 'You have rated it as interesting.',
      ],
    );
  }

  GrowthOption _discover(List<CatalogSubject> fresh, Set<String> existing, int growthSteps, int seed) {
    final cats = ({for (final c in fresh) c.category}.toList())..sort();
    final cat = cats[((growthSteps ~/ discoverEvery) + (unitFromSeed(seed) * cats.length).floor()) % cats.length];
    final pool = [for (final c in fresh) if (c.category == cat) c];
    final pick = pool[(unitFromSeed(seed * 17 + 5) * pool.length).floor() % pool.length];
    return GrowthOption(
      kind: GrowthKind.discover,
      domainName: pick.name,
      category: cat,
      headline: 'A new subject: ${pick.name}',
      goal: 'a rich, engaging first outline for someone curious who is new to it',
      reasons: [
        'Time for something new: ${pick.name} (${pick.category}).',
        'The app rotates through ${cats.length} areas so none gets left out; ${existing.length} subject${existing.length == 1 ? '' : 's'} exist so far.',
      ],
    );
  }
}
