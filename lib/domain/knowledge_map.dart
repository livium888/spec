/// The knowledge map of one subject (D44): its topics, what the learner knows of each, which topic
/// leans on which, where to go next and what is holding a topic back. Pure Dart, no Flutter.
library;

import 'fsrs_model.dart' show retrievability;

/// How well a topic is known, in words (never colour alone).
enum TopicState { notStarted, learning, solid, fading, attention, skipped }

/// Thresholds, in one place so the screen, the list and the advice agree.
const kSolidKnowledge = 0.70; // share of the topic known now (see [TopicNode.knowledge])
const kFadingRecall = 0.85; // below this, among the cards you have learned, a topic is fading
const kShakyRecall = 0.70; // below this it needs attention
const kMinLearnedForVerdict = 3; // fewer learned cards: too early to call a topic fading or shaky

/// One card's contribution, as read from the database.
class CardFact {
  const CardFact({required this.state, this.stability, this.lastReviewMs, this.lapses = 0, this.suspended = false, this.retired = false, this.leech = false});
  final String state; // new | learning | review | relearning
  final double? stability;
  final int? lastReviewMs;
  final int lapses;
  final bool suspended, retired, leech;
}

/// Chance of recalling [c] at [nowMs], 0 for a card not yet learned.
double cardRecall(CardFact c, List<double> weights, int nowMs) {
  final s = c.stability;
  final last = c.lastReviewMs;
  if (c.state == 'new' || s == null || s <= 0 || last == null || weights.length <= 20) return 0;
  final days = ((nowMs - last) / 86400000).clamp(0.0, 100000.0);
  return retrievability(weights, days, s).clamp(0.0, 1.0);
}

class TopicNode {
  TopicNode({
    required this.id,
    required this.title,
    required this.level,
    required this.position,
    required this.status,
    required this.targetCards,
    required this.cards,
    required this.learned,
    required this.knowledge,
    required this.recall,
    required this.state,
    this.leeches = 0,
    this.problems = false,
    this.foundations = 0,
    this.prereqs = const [],
    this.practice = '',
  });
  final int id, level, position, targetCards;
  final String title, status; // status: todo | active | done | skipped
  final int cards; // cards you have in this topic (not suspended, not retired)
  final int learned; // of them, answered at least once
  final double knowledge; // sum of recall / max(cards, target): "how much of this topic do you know now"
  final double? recall; // average recall of the learned cards, null when none
  final TopicState state;
  final int leeches;
  final bool problems; // has problem cards or is practised with problems
  final int foundations; // foundation cards made for cards of this topic
  final List<int> prereqs;
  final String practice; // '' (the AI decides) | concepts | problems | both
  int layer = 0;
}

class KnowledgeMap {
  KnowledgeMap({required this.nodes, required this.layers, required this.nextUp, required this.blockers});
  final Map<int, TopicNode> nodes;

  /// Topic ids by layer, top (no prerequisites) to bottom, in drawing order.
  final List<List<int>> layers;

  /// Topics ready to learn: not finished, not skipped, every prerequisite solid.
  final List<int> nextUp;

  /// For a topic held back by a weak prerequisite: the weakest one.
  final Map<int, int> blockers;

  bool get isEmpty => nodes.isEmpty;

  /// Prerequisite edges as (from, to).
  List<(int, int)> get edges => [
        for (final n in nodes.values)
          for (final p in n.prereqs)
            if (nodes.containsKey(p)) (p, n.id),
      ];
}

/// Where a topic stands, from its cards.
TopicState stateOf({required String status, required int cards, required int learned, required double knowledge, required double? recall, required int leeches}) {
  if (status == 'skipped') return TopicState.skipped;
  if (cards == 0 || learned == 0) return TopicState.notStarted;
  if (leeches > 0) return TopicState.attention;
  final r = recall ?? 0;
  if (learned >= kMinLearnedForVerdict) {
    if (r < kShakyRecall) return TopicState.attention;
    if (r < kFadingRecall) return TopicState.fading;
  }
  return knowledge >= kSolidKnowledge ? TopicState.solid : TopicState.learning;
}

/// Builds a topic node from its facts.
TopicNode buildNode({
  required int id,
  required String title,
  required int level,
  required int position,
  required String status,
  required int targetCards,
  required List<CardFact> facts,
  required List<double> weights,
  required int nowMs,
  required List<int> prereqs,
  required bool problems,
  required int foundations,
  String practice = '',
}) {
  // A suspended card is out of the topic, except a leech: that one is exactly what the learner should see.
  final live = [
    for (final f in facts)
      if (!f.retired && (!f.suspended || f.leech)) f,
  ];
  var sum = 0.0, learnedSum = 0.0;
  var learned = 0, leeches = 0;
  for (final f in live) {
    final r = cardRecall(f, weights, nowMs);
    sum += r;
    if (f.state != 'new') {
      learned++;
      learnedSum += r;
    }
    if (f.leech) leeches++;
  }
  final denom = live.length > targetCards ? live.length : targetCards;
  final knowledge = denom == 0 ? 0.0 : (sum / denom).clamp(0.0, 1.0);
  final recall = learned == 0 ? null : learnedSum / learned;
  return TopicNode(
    id: id,
    title: title,
    level: level,
    position: position,
    status: status,
    targetCards: targetCards,
    cards: live.length,
    learned: learned,
    knowledge: knowledge,
    recall: recall,
    state: stateOf(status: status, cards: live.length, learned: learned, knowledge: knowledge, recall: recall, leeches: leeches),
    leeches: leeches,
    problems: problems,
    foundations: foundations,
    prereqs: prereqs,
    practice: practice,
  );
}

/// Lays the topics out in layers (a topic sits one layer below its deepest prerequisite), and works out
/// "next up" and the blockers. Cycles (the importer prevents them, a damaged file could not) are cut.
KnowledgeMap buildKnowledgeMap(List<TopicNode> topics) {
  final nodes = {for (final t in topics) t.id: t};
  final depth = <int, int>{};
  int depthOf(int id, Set<int> path) {
    final known = depth[id];
    if (known != null) return known;
    if (!path.add(id)) return 0; // a cycle: stop here
    var d = 0;
    for (final p in nodes[id]!.prereqs) {
      if (nodes.containsKey(p)) {
        final pd = depthOf(p, path) + 1;
        if (pd > d) d = pd;
      }
    }
    path.remove(id);
    return depth[id] = d;
  }

  for (final id in nodes.keys) {
    depthOf(id, <int>{});
  }
  final byDepth = <int, List<TopicNode>>{};
  for (final n in nodes.values) {
    n.layer = depth[n.id] ?? 0;
    byDepth.putIfAbsent(n.layer, () => []).add(n);
  }
  final layers = <List<int>>[];
  final order = <int, int>{}; // position within its layer, for the next layer's ordering
  for (final d in (byDepth.keys.toList()..sort())) {
    final row = byDepth[d]!;
    double key(TopicNode n) {
      final xs = [for (final p in n.prereqs) if (order.containsKey(p)) order[p]!.toDouble()];
      return xs.isEmpty ? n.position.toDouble() : xs.reduce((a, b) => a + b) / xs.length;
    }

    row.sort((a, b) {
      final c = key(a).compareTo(key(b));
      return c != 0 ? c : (a.position != b.position ? a.position.compareTo(b.position) : a.id.compareTo(b.id));
    });
    for (final (i, n) in row.indexed) {
      order[n.id] = i;
    }
    layers.add([for (final n in row) n.id]);
  }

  // A prerequisite is solid enough when it is solid, or finished and not slipping.
  bool solid(int id) {
    final n = nodes[id];
    if (n == null) return true;
    if (n.state == TopicState.solid) return true;
    return n.status == 'done' && n.cards > 0 && n.state != TopicState.attention && n.state != TopicState.fading;
  }

  final nextUp = <int>[];
  final blockers = <int, int>{};
  for (final layer in layers) {
    for (final id in layer) {
      final n = nodes[id]!;
      if (n.state == TopicState.skipped) continue;
      final weak = [for (final p in n.prereqs) if (nodes.containsKey(p) && nodes[p]!.state != TopicState.skipped && !solid(p)) nodes[p]!];
      if (weak.isNotEmpty) {
        weak.sort((a, b) => a.knowledge.compareTo(b.knowledge));
        // Only say it for a topic that is not yet solid itself: a solid topic is not "held back".
        if (n.state != TopicState.solid) blockers[id] = weak.first.id;
      } else if ((n.state == TopicState.notStarted || n.state == TopicState.learning) && n.status != 'done') {
        nextUp.add(id);
      }
    }
  }
  return KnowledgeMap(nodes: nodes, layers: layers, nextUp: nextUp.take(4).toList(), blockers: blockers);
}

/// "Solid", "Fading"...: the word for a state.
String stateLabel(TopicState s) => switch (s) {
      TopicState.notStarted => 'Not started',
      TopicState.learning => 'Learning',
      TopicState.solid => 'Solid',
      TopicState.fading => 'Fading',
      TopicState.attention => 'Needs attention',
      TopicState.skipped => 'Not offered',
    };

/// One plain sentence on what the state means.
String stateMeaning(TopicState s) => switch (s) {
      TopicState.notStarted => 'You have no cards for this topic yet.',
      TopicState.learning => 'You are still building this topic. Keep reviewing and adding cards.',
      TopicState.solid => 'You know this topic well right now.',
      TopicState.fading => 'You knew this, and it is slipping. Reviews will bring it back.',
      TopicState.attention => 'You are forgetting cards here, or some are leeches. Fix the hard cards or build the foundations.',
      TopicState.skipped => 'You chose not to be offered this topic.',
    };
