import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/review_service.dart';
import '../data/settings_repo.dart';
import '../domain/card_memory.dart';
import '../domain/memory_summary.dart';
import '../domain/study_card.dart';
import 'format.dart';
import 'prompt_result_screen.dart';
import 'theme/tokens.dart';

/// "About this card": the state in plain words, the model's three numbers for this card
/// (strength, difficulty, chance of recall now), a forgetting curve and the last answers.
/// The numbers are estimates from the FSRS model, not measurements; the sheet says so.
Future<void> showCardInfo(BuildContext context, StudyCard card) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CardInfoSheet(card: card),
    );

class _Loaded {
  const _Loaded(this.w, this.target, this.history, this.learning, this.relearning, this.foundations);
  final List<double> w;
  final double target;
  final CardHistory history;
  final List<int> learning, relearning;
  final int foundations; // foundation cards already made for this card
}

class CardInfoSheet extends ConsumerStatefulWidget {
  const CardInfoSheet({super.key, required this.card});
  final StudyCard card;
  @override
  ConsumerState<CardInfoSheet> createState() => _CardInfoSheetState();
}

class _CardInfoSheetState extends ConsumerState<CardInfoSheet> {
  late final Future<_Loaded> _f = _load();

  Future<_Loaded> _load() async {
    final params = ref.read(paramsRepoProvider);
    final cfg = await params.configFor(await params.idForDomain(widget.card.domainId));
    final history = await ref.read(reviewServiceProvider).history(widget.card.id);
    final s = ref.read(settingsRepoProvider);
    return _Loaded(
      cfg.weights,
      cfg.desiredRetention,
      history,
      await s.getIntList(SettingsRepo.learningSteps, [1, 10]),
      await s.getIntList(SettingsRepo.relearningSteps, [10]),
      await ref.read(foundationServiceProvider).countFor(widget.card.noteId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_Loaded>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(padding: const EdgeInsets.all(24), child: Text('Could not load the card details: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
          }
          return _body(context, snap.data!);
        },
      ),
    );
  }

  Widget _body(BuildContext context, _Loaded d) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    final card = widget.card;
    final now = DateTime.now().millisecondsSinceEpoch;
    final m = memoryStats(card.snapshot, d.w, now);
    final stage = bucketOf(
        MemoryFact(state: card.snapshot.state.dbValue, stability: card.snapshot.stability, lastReviewMs: card.snapshot.lastReview, suspended: card.suspended),
        d.w,
        now);
    final e = explainState(card.snapshot.state, learningSteps: d.learning, relearningSteps: d.relearning, stage: stage);

    Widget stat(String label, String value, {String? hint}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 5,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: t.bodyMedium),
                if (hint != null) Text(hint, style: t.bodySmall?.copyWith(color: c.inkSoft)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: Text(value, textAlign: TextAlign.end, style: t.titleSmall)),
          ]),
        );

    final stab = m.stabilityDays;
    final horizon = stab == null ? 0.0 : math.max(stab * 2.5, 3.0);
    final curve = stab == null ? const <(double, double)>[] : forgettingCurve(d.w, stab, horizon);
    final elapsed = m.lastReviewMs == null ? null : (now - m.lastReviewMs!) / 86400000.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(header: true, child: Text(e.title, style: t.headlineSmall)),
        const SizedBox(height: 6),
        Text(e.body, style: t.bodyLarge),
        const SizedBox(height: 14),
        _foundations(context, d),
        const SizedBox(height: 18),
        Semantics(header: true, child: Text('Memory statistics', style: t.titleMedium)),
        if (!m.hasModel)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Nothing to show yet: the numbers appear after your first answer.', style: t.bodyMedium),
          )
        else ...[
          if (m.recallNow != null)
            stat('Chance you remember it now', '${(m.recallNow! * 100).round()}%',
                hint: 'The model\'s estimate, right now.'),
          stat('Memory strength', 'about ${_days(stab!)}',
              hint: 'After this long without a review, the chance of remembering falls to 90%.'),
          if (m.difficulty != null)
            stat('Difficulty', '${m.difficulty!.toStringAsFixed(1)} of 10 · ${difficultyWord(m.difficulty!)}'),
          stat('Next review', dueWords(m.dueMs, now)),
        ],
        stat('Times answered', '${m.reps}'),
        stat('Times forgotten', '${m.lapses}', hint: 'Answers of "Again" on a card you knew.'),
        if (d.history.total > 0) ...[
          stat('Remembered', '${(d.history.passRate! * 100).round()}% of ${d.history.total} answers',
              hint: 'Any answer except "Again".'),
          stat('Average time', '${(d.history.avgMs / 1000).toStringAsFixed(1)} s per answer'),
        ],
        if (curve.isNotEmpty) ...[
          const SizedBox(height: 14),
          Semantics(header: true, child: Text('How this memory fades', style: t.titleMedium)),
          const SizedBox(height: 8),
          Semantics(
            label: 'Forgetting curve. The chance of remembering starts at 100% and falls to '
                '${(curve.last.$2 * 100).round()}% after ${_days(horizon)}. '
                '${m.recallNow == null ? '' : 'Today it is about ${(m.recallNow! * 100).round()}%.'}',
            excludeSemantics: true,
            child: SizedBox(
              height: 150,
              child: CustomPaint(
                size: Size.infinite,
                painter: _CurvePainter(curve: curve, horizon: horizon, nowDays: elapsed, target: d.target, line: c.accent, grid: c.line, text: c.inkSoft, dot: c.danger, label: t.labelSmall ?? const TextStyle(fontSize: 10)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('Days since your last answer →   dashed line: your target of ${(d.target * 100).round()}%${elapsed == null ? '' : '   dot: today'}',
              style: t.bodySmall?.copyWith(color: c.inkSoft)),
        ],
        if (d.history.entries.isNotEmpty) ...[
          const SizedBox(height: 18),
          Semantics(header: true, child: Text('Your last answers', style: t.titleMedium)),
          const SizedBox(height: 4),
          for (final r in d.history.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(flex: 4, child: Text(_date(r.at), style: t.bodyMedium)),
                Expanded(flex: 3, child: Text(ratingName(r.rating), style: t.titleSmall)),
                Expanded(flex: 4, child: Text(r.rating == 1 ? 'back soon' : 'next gap ${_days(r.scheduledDays)}', textAlign: TextAlign.end, style: t.bodySmall)),
              ]),
            ),
        ],
        const SizedBox(height: 18),
        Text(
          'These numbers are the model\'s estimates (FSRS-6), not measurements. They use the same three ideas as SuperMemo: '
          'how strong the memory is, how likely you are to recall it now, and how hard the card is for you.',
          style: t.bodySmall?.copyWith(color: c.inkSoft),
        ),
      ]),
    );
  }

  /// "Build the foundations": a prompt for 2 to 4 cards on the ideas this card rests on.
  Widget _foundations(BuildContext context, _Loaded d) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    final isFoundation = widget.card.fields['foundation_of'] != null;
    if (isFoundation) {
      return Text('This card is a foundation: it prepares you for a harder card.', style: t.bodyMedium?.copyWith(color: c.inkSoft));
    }
    if (d.foundations > 0) {
      return Row(children: [
        Icon(Icons.check_circle_outline, color: c.good),
        const SizedBox(width: 8),
        Expanded(child: Text('Foundations added: ${d.foundations} ${d.foundations == 1 ? 'card' : 'cards'} that prepare you for this one.', style: t.bodyMedium)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Hard, but you like the idea? Get 2 to 4 short cards on the ideas it rests on, from your own AI.', style: t.bodyMedium),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        icon: const Icon(Icons.layers_outlined),
        label: const Text('Build the foundations'),
        onPressed: () async {
          final nav = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          try {
            final g = await ref.read(foundationServiceProvider).promptFor(widget.card.noteId);
            nav.pop();
            await nav.push(MaterialPageRoute<void>(builder: (_) => PromptResultScreen(prompt: g)));
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text('Could not build the prompt: $e')));
          }
        },
      ),
    ]);
  }

  static String _days(double d) {
    if (d < 1) return '${(d * 24).round().clamp(1, 23)} h';
    if (d < 60) return '${d.round()} ${d.round() == 1 ? 'day' : 'days'}';
    if (d < 730) return '${(d / 30.4).round()} months';
    return '${(d / 365).toStringAsFixed(1)} years';
  }

  static String _date(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    const mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${mon[dt.month - 1]} ${dt.year}';
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({required this.curve, required this.horizon, required this.nowDays, required this.target, required this.line, required this.grid, required this.text, required this.dot, required this.label});
  final List<(double, double)> curve;
  final double horizon, target;
  final double? nowDays;
  final Color line, grid, text, dot;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0, bottom = 18.0, top = 6.0;
    final w = size.width - left - 4, h = size.height - bottom - top;
    // The vertical scale starts just under the lowest point (the labels say so), so a slow fade is visible.
    final lowest = math.min(curve.last.$2, target);
    final yMin = math.max(0.0, ((lowest * 10).floor() - 1) / 10);
    Offset p(double x, double y) => Offset(left + w * (x / horizon).clamp(0.0, 1.0), top + h * (1 - (y - yMin) / (1 - yMin)));
    final gridPaint = Paint()..color = grid..strokeWidth = 1;
    for (final y in [yMin, (yMin + 1) / 2, 1.0]) {
      canvas.drawLine(p(0, y), p(horizon, y), gridPaint);
      final tp = TextPainter(text: TextSpan(text: '${(y * 100).round()}%', style: label.copyWith(fontSize: 10, color: text)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(0, p(0, y).dy - tp.height / 2));
    }
    // The learner's target, dashed.
    final dash = Paint()..color = text..strokeWidth = 1;
    final a = p(0, target), b = p(horizon, target);
    for (var x = a.dx; x < b.dx; x += 8) {
      canvas.drawLine(Offset(x, a.dy), Offset(math.min(x + 4, b.dx), a.dy), dash);
    }
    final path = Path()..moveTo(p(curve.first.$1, curve.first.$2).dx, p(curve.first.$1, curve.first.$2).dy);
    for (final c in curve.skip(1)) {
      final o = p(c.$1, c.$2);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, Paint()..color = line..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeJoin = StrokeJoin.round);
    final n = nowDays;
    if (n != null && n <= horizon) {
      // Recall now: interpolate on the drawn curve.
      var y = curve.last.$2;
      for (var i = 1; i < curve.length; i++) {
        if (curve[i].$1 >= n) {
          final f = (n - curve[i - 1].$1) / (curve[i].$1 - curve[i - 1].$1);
          y = curve[i - 1].$2 + (curve[i].$2 - curve[i - 1].$2) * f;
          break;
        }
      }
      canvas.drawCircle(p(n, y), 6, Paint()..color = dot);
    }
  }

  @override
  bool shouldRepaint(_CurvePainter o) => o.curve != curve || o.nowDays != nowDays || o.target != target;
}
