import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/services.dart';

import '../app/providers.dart';
import '../data/stats_service.dart';
import '../domain/card_text.dart';
import '../domain/models.dart';
import '../domain/review_timing.dart';
import '../domain/study_advisor.dart';
import '../domain/study_card.dart';
import 'advice_card.dart';
import 'format.dart';
import 'theme/app_theme.dart';
import 'theme/subject_style.dart';
import 'card_picture.dart';
import 'widgets/card_parts.dart';
import 'edit_card_screen.dart';
import 'theme/tokens.dart';
import 'widgets/confetti.dart';
import 'widgets/progress_ring.dart';
import 'widgets/soft_card.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  DailyQueue? _queue;
  StudyCard? _current;
  Map<int, Duration> _preview = {};
  bool _revealed = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final _stopwatch = Stopwatch();
  final _touched = <int>{};
  int _answered = 0;
  int _totalMs = 0;
  Timer? _poll;
  bool _sessionEnded = false;
  Advice? _advice;
  ProgressStats? _stats;
  final _domainNames = <int, String>{};

  /// Per subject: the language to read aloud and which side is in it.
  final _speech = <int, (String, String)>{};
  bool _speakAuto = false;
  CardTextSize _textSize = CardTextSize.medium;
  bool _questionOpen = false; // a long question folded after the reveal, shown whole again by a tap
  final _ratings = <int>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({StudyCard? force}) async {
    try {
      final q = await ref.read(queueServiceProvider).build();
      final next = force ?? q.next;
      Map<int, Duration> pv = {};
      if (next != null) {
        final params = ref.read(paramsRepoProvider);
        final sched = await params.schedulerForDomain(next.domainId);
        pv = sched.preview(next.snapshot, DateTime.now().toUtc());
      }
      if (!mounted) return;
      final adv = next == null ? await ref.read(learnServiceProvider).advice() : null;
      final stats = next == null && _answered > 0 ? await ref.read(statsServiceProvider).compute() : null;
      if (_domainNames.isEmpty) {
        final db = ref.read(dbProvider);
        for (final d in await db.select(db.domains).get()) {
          _domainNames[d.id] = d.name;
          if (d.speechLang != null) _speech[d.id] = (d.speechLang!, d.speechSide);
        }
      }
      _speakAuto = await ref.read(settingsRepoProvider).get('speak_auto') == '1';
      _textSize = cardTextSizeFrom(await ref.read(settingsRepoProvider).get(kCardTextSizeKey));
      if (!mounted) return;
      setState(() {
        _advice = adv;
        _stats = stats;
        _queue = q;
        _current = next;
        _preview = pv;
        _revealed = false;
        _questionOpen = false;
        _loading = false;
        _error = null;
      });
      _stopwatch
        ..reset()
        ..start();
      if (next != null) _autoSpeak(next, revealed: false);
      _poll?.cancel();
      if (next == null && q.nextLearningDue != null) {
        // Waiting on a learning step: re-check shortly.
        _poll = Timer.periodic(const Duration(seconds: 20), (_) => _load());
      } else if (next == null && _answered > 0 && !_sessionEnded) {
        _sessionEnded = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _askInterest());
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _answer(int rating) async {
    final c = _current;
    if (c == null || _busy) return;
    setState(() => _busy = true);
    rating == Rating.again ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
    _stopwatch.stop();
    final ms = cappedCardMs(_stopwatch.elapsedMilliseconds); // an idle card must not count as hours
    try {
      final res = await ref.read(reviewServiceProvider).review(
            cardId: c.id,
            rating: rating,
            durationMs: ms,
          );
      _touched.add(c.domainId);
      _ratings.add(rating);
      _answered++;
      _totalMs += ms;
      if (res.becameLeech && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This card is a leech: suspended and tagged.')));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        _stopwatch.start();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save that answer: $e. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undo() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final restored = await ref.read(reviewServiceProvider).undoLast();
      if (restored == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to undo.')));
        }
      } else {
        if (_answered > 0) _answered--;
        if (_ratings.isNotEmpty) _ratings.removeLast();
        _sessionEnded = false;
        await _load(force: await ref.read(queueServiceProvider).cardById(restored.id));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final c = _current;
    if (c == null) return;
    final outcome = await Navigator.of(context)
        .push<EditOutcome>(MaterialPageRoute(builder: (_) => EditCardScreen(noteId: c.noteId)));
    if (outcome == null || !mounted) return;
    if (outcome == EditOutcome.deleted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card deleted.')));
    }
    await _load();
  }

  Future<void> _suspend() async {
    final c = _current;
    if (c == null) return;
    await ref.read(reviewServiceProvider).setSuspended(c.id, true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Card suspended.')));
    }
    await _load();
  }

  /// One-tap interest per domain touched; skippable. Feeds the future engine.
  Future<void> _askInterest() async {
    if (_touched.isEmpty || !mounted) return;
    final db = ref.read(dbProvider);
    final names = <int, String>{};
    for (final id in _touched) {
      names[id] = (await (db.select(db.domains)..where((d) => d.id.equals(id))).getSingle()).name;
    }
    if (!mounted) return;
    final choices = <int, int>{};
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('How did that feel?'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final e in names.entries) ...[
                Text(e.value, style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 4),
                SegmentedButton<int>(
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: -1, label: Text('Less'), icon: Icon(Icons.thumb_down_outlined)),
                    ButtonSegment(value: 0, label: Text('Same'), icon: Icon(Icons.remove)),
                    ButtonSegment(value: 1, label: Text('More'), icon: Icon(Icons.thumb_up_outlined)),
                  ],
                  selected: choices.containsKey(e.key) ? {choices[e.key]!} : <int>{},
                  onSelectionChanged: (s) => setS(() {
                    if (s.isEmpty) {
                      choices.remove(e.key);
                    } else {
                      choices[e.key] = s.first;
                    }
                  }),
                ),
                const SizedBox(height: 12),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
            FilledButton(
              onPressed: () async {
                final svc = ref.read(interestServiceProvider);
                for (final e in choices.entries) {
                  await svc.record(e.key, e.value);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _reveal() {
    if (_revealed) return;
    HapticFeedback.selectionClick();
    setState(() => _revealed = true);
    final c = _current;
    if (c != null) _autoSpeak(c, revealed: true);
  }

  /// The text of the side written in the subject's language (a cloze is read as the whole sentence).
  String? _speechText(StudyCard c, {required bool revealed}) {
    final s = _speech[c.domainId];
    if (s == null) return null;
    if (s.$2 == 'back' && !revealed) return null; // never read the answer out before it is shown
    final text = s.$2 == 'front' && c.noteType != 'cloze' ? c.front : c.back;
    return text.trim().isEmpty ? null : text;
  }

  void _autoSpeak(StudyCard c, {required bool revealed}) {
    if (!_speakAuto) return;
    final s = _speech[c.domainId];
    if (s == null) return;
    final wantsNow = (s.$2 == 'front' && !revealed) || (s.$2 == 'back' && revealed);
    if (wantsNow) _speak(c, revealed: revealed);
  }

  Future<void> _speak(StudyCard c, {required bool revealed}) async {
    final text = _speechText(c, revealed: revealed);
    final lang = _speech[c.domainId]?.$1;
    if (text == null || lang == null) return;
    final problem = await ref.read(speakerProvider).speak(text, lang);
    if (problem != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final left = _queue?.ordered.length ?? 0;
    final total = _answered + left;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(children: [
              IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).maybePop()),
              Expanded(
                child: Semantics(
                  label: 'Session progress',
                  value: total == 0 ? '0%' : '${(_answered / total * 100).round()}%',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Rd.pill),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: total == 0 ? 0 : _answered / total),
                      duration: const Duration(milliseconds: 350),
                      builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: c.accent, backgroundColor: c.line),
                    ),
                  ),
                ),
              ),
              IconButton(tooltip: 'Undo last answer', icon: const Icon(Icons.undo), onPressed: _busy ? null : _undo),
              if (_current != null)
                IconButton(tooltip: 'Edit or delete this card', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
              if (_current != null)
                IconButton(tooltip: 'Suspend this card', icon: const Icon(Icons.pause_circle_outline), onPressed: _suspend),
            ]),
          ),
          if (!_loading && _error == null && _current != null) _progressCaption(context, left),
          Expanded(child: _content(context)),
        ]),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Something went wrong: $_error'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }
    final card = _current;
    if (card == null) return _done(context);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Column(children: [
      Expanded(
        child: AnimatedSwitcher(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 280),
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(key: ValueKey(card.id), child: _cardView(context, card, reduce)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: _revealed ? _ratingRow(context) : _showAnswerButton(),
      ),
    ]);
  }

  /// "7 left · about 2 min": what is still ahead, from the pace of this very session.
  Widget _progressCaption(BuildContext context, int left) {
    final avg = _answered >= 3 ? _totalMs / _answered / 1000.0 : 10.0;
    final mins = (left * avg / 60).ceil().clamp(1, 100000);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$left left · about $mins min',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.of(context).inkSoft),
        ),
      ),
    );
  }

  String _stateLabel(StudyCard c) => switch (c.snapshot.state) {
        CardState.newCard => 'New',
        CardState.learning => 'Learning',
        CardState.review => 'Review',
        CardState.relearning => 'Relearning',
      };

  Widget _cardView(BuildContext context, StudyCard card, bool reduce) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final name = _domainNames[card.domainId] ?? '';
    final style = SubjectStyle.of(card.domainId, name, c.brightness);
    final isCloze = card.noteType == 'cloze';
    final questionText = isCloze ? (card.fields['cloze'] as String? ?? '') : card.front;
    final questionStyle = AppText.serif(questionFontSize(questionText.length, _textSize), weight: 600, height: 1.4, color: c.ink);
    // With the answer showing, a long question is folded so the answer gets the room.
    final fold = _revealed && !isCloze && shouldCollapseQuestion(card.front) && !_questionOpen;
    final foldedStyle = AppText.sans(15 * cardTextScale(_textSize), weight: 500, height: 1.4, color: c.inkSoft);
    final frontPicture = card.imageSha != null && card.imageOnFront;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _revealed ? null : _reveal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: SoftCard(
          radius: Rd.hero,
          padding: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 300),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Picture first: artwork gets the top of the card, edge to edge, never cropped.
              if (frontPicture) CardPicture(sha: card.imageSha!, alt: card.imageAlt, credit: _revealed ? card.imageCredit : '', maxHeight: 320, flush: true),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (name.isNotEmpty) _Tag(icon: style.icon, text: name, fg: style.strong, bg: style.tint),
                    _Tag(text: _stateLabel(card), fg: c.inkSoft, bg: c.surfaceDim),
                    if (card.unverified) _Tag(icon: Icons.help_outline, text: 'Unverified', fg: c.warn, bg: c.warnTint),
                    if (_speech[card.domainId] != null)
                      Semantics(
                        button: true,
                        label: 'Read aloud',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(Rd.pill),
                          // A tap on a disabled speaker must not fall through to the card and reveal the answer.
                          onTap: _speechText(card, revealed: _revealed) == null ? () {} : () => _speak(card, revealed: _revealed),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.volume_up_outlined,
                                size: 24, color: _speechText(card, revealed: _revealed) == null ? c.line : c.accent),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 22),
                  // Plain Text only: card content comes from an LLM and is never interpreted as markup.
                  // Not selectable on purpose: selectable text swallows taps, and a tap anywhere on the card reveals the answer.
                  if (isCloze)
                    ClozeSentence(
                        parts: card.clozeParts, revealed: _revealed, style: questionStyle, strong: style.strong, tint: style.tint)
                  else if (_revealed && shouldCollapseQuestion(card.front))
                    Semantics(
                      button: true,
                      label: fold ? 'Question, folded. Double tap to show all of it' : 'Question. Double tap to fold it',
                      excludeSemantics: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Rd.card),
                        onTap: () => setState(() => _questionOpen = !_questionOpen),
                        child: AnimatedSize(
                          duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
                          alignment: Alignment.topLeft,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(card.front,
                                style: fold ? foldedStyle : questionStyle,
                                maxLines: fold ? 3 : null,
                                overflow: fold ? TextOverflow.ellipsis : null),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(fold ? 'Show the whole question' : 'Fold the question',
                                  style: t.labelSmall?.copyWith(color: style.strong)),
                            ),
                          ]),
                        ),
                      ),
                    )
                  else
                    Text(card.front, style: questionStyle),
                  if (_revealed) RevealPanel(accent: style.strong, child: _answerSide(context, card, style)),
                  if (!_revealed) ...[
                    const SizedBox(height: 28),
                    Row(children: [
                      Icon(Icons.touch_app_outlined, size: 18, color: c.inkSoft),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Think of your answer, then tap to reveal', style: t.bodySmall)),
                    ]),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// The answer side. A cloze fills its gap in the sentence above, so only the extras are added here.
  Widget _answerSide(BuildContext context, StudyCard card, SubjectStyle style) {
    final c = AppColors.of(context);
    final isCloze = card.noteType == 'cloze';
    final back = isCloze ? card.clozeExtra : card.back;
    final source = card.fields['supporting_quote'] as String? ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (card.imageSha != null && !card.imageOnFront) ...[
        CardPicture(sha: card.imageSha!, alt: card.imageAlt, credit: card.imageCredit),
        const SizedBox(height: 16),
      ],
      if (back.isNotEmpty) SelectableText(back, style: AppText.sans(answerFontSize(_textSize), weight: 650, height: 1.4, color: c.ink)),
      ExtrasStack(extras: card.extras, strong: style.strong, scale: extrasScale(_textSize)),
      if (source.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Text('Source: “$source”', style: Theme.of(context).textTheme.bodySmall),
        ),
    ]);
  }

  Widget _showAnswerButton() => FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
        onPressed: _reveal,
        child: const Text('Show answer'),
      );

  Widget _ratingRow(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final looks = {
      Rating.again: (c.dangerTint, c.danger),
      Rating.hard: (c.warnTint, c.warn),
      Rating.good: (c.goodTint, c.good),
      Rating.easy: (c.infoTint, c.info),
    };
    return Row(children: [
      for (final r in Rating.all)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Semantics(
              button: true,
              label: '${ratingName(r)}, next in ${formatInterval(_preview[r] ?? Duration.zero)}',
              excludeSemantics: true,
              child: Material(
                color: looks[r]!.$1,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _busy ? null : () => _answer(r),
                  child: SizedBox(
                    height: 68,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(ratingName(r), style: AppText.sans(15, weight: 700, color: looks[r]!.$2)),
                      const SizedBox(height: 2),
                      Text(formatInterval(_preview[r] ?? Duration.zero),
                          style: t.labelSmall?.copyWith(color: looks[r]!.$2)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _done(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final waiting = _queue?.nextLearningDue;
    final mins = waiting == null
        ? null
        : ((waiting - DateTime.now().millisecondsSinceEpoch) / 60000).ceil().clamp(1, 100000);
    final passed = _ratings.where((r) => r > Rating.again).length;
    final pct = _ratings.isEmpty ? null : (passed / _ratings.length * 100).round();
    final stats = _stats;
    final celebrate = _answered > 0 && waiting == null;
    final tomorrow = stats != null && stats.forecast.length > 1 ? stats.forecast[1] : null;

    return Stack(children: [
      if (celebrate) Positioned.fill(child: ConfettiBurst(colors: [c.accent, c.good, c.info, c.warn])),
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ProgressRing(
              value: 1,
              size: 112,
              stroke: 12,
              color: waiting == null ? c.good : c.warn,
              track: waiting == null ? c.goodTint : c.warnTint,
              semanticLabel: 'Session complete',
              child: Icon(waiting == null ? Icons.check_rounded : Icons.hourglass_bottom,
                  size: 48, color: waiting == null ? c.good : c.warn),
            ),
            const SizedBox(height: 20),
            Text(waiting == null ? (_answered > 0 ? 'Nicely done' : 'All done for today') : 'Next card in about $mins min',
                textAlign: TextAlign.center, style: t.headlineMedium),
            if (_answered > 0) ...[
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _SummaryStat('$_answered', _answered == 1 ? 'card' : 'cards'),
                _SummaryStat(_formatMs(_totalMs), 'studied'),
                if (pct != null) _SummaryStat('$pct%', 'remembered'),
                if (_answered > 1) _SummaryStat(_formatMs(_totalMs ~/ _answered), 'per card'),
              ]),
              const SizedBox(height: 16),
              SizedBox(width: 300, child: RatingBreakdown(ratings: _ratings)),
            ],
            if (stats != null && stats.streak.current > 0) ...[
              const SizedBox(height: 18),
              SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_fire_department_rounded, color: c.accent),
                  const SizedBox(width: 8),
                  Text('${stats.streak.current}-day streak', style: t.titleSmall),
                  if (tomorrow != null && tomorrow > 0) ...[
                    const SizedBox(width: 14),
                    Text('$tomorrow ${tomorrow == 1 ? 'review' : 'reviews'} tomorrow', style: t.bodySmall),
                  ],
                ]),
              ),
            ],
            if (_advice != null) ...[
              const SizedBox(height: 14),
              AdviceCard(_advice!, compact: true),
            ],
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(220, 56)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to home'),
            ),
          ]),
        ),
      ),
    ]);
  }

  static String _formatMs(int ms) {
    final s = (ms / 1000).round();
    if (s < 60) return '${s}s';
    return '${(s / 60).round()} min';
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.fg, required this.bg, this.icon});
  final String text;
  final Color fg, bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rd.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 5)],
          Text(text, style: AppText.sans(12.5, weight: 650, color: fg)),
        ]),
      );
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat(this.value, this.label);
  final String value, label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(children: [
          Text(value, style: AppText.serif(28, weight: 700, color: AppColors.of(context).ink)),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ]),
      );
}
