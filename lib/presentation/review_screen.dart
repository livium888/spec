import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/services.dart';

import '../app/launch_service.dart' show kQuickSessionCards;
import '../data/pause_bridge.dart';
import '../domain/pause_stats.dart' show pausePreview;
import '../domain/site_rule.dart' show pauseEarned;
import '../app/providers.dart';
import '../data/stats_service.dart';
import '../domain/card_markup.dart' show plainFromMarkup;
import '../domain/card_text.dart';
import '../domain/memory_summary.dart';
import '../domain/models.dart';
import '../domain/review_timing.dart';
import '../domain/study_advisor.dart';
import '../domain/study_card.dart';
import 'advice_card.dart';
import 'format.dart';
import 'talk_sheet.dart';
import 'theme/app_theme.dart';
import 'theme/subject_style.dart';
import 'card_info_sheet.dart';
import 'card_picture.dart';
import 'widgets/card_parts.dart';
import 'widgets/rich_card_text.dart';
import 'edit_card_screen.dart';
import 'theme/tokens.dart';
import 'widgets/confetti.dart';
import 'widgets/progress_ring.dart';
import 'widgets/soft_card.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  /// [quick]: a short session of this many cards (the "Quick 5" entry points, D51); null = the whole day.
  const ReviewScreen({super.key, this.quick, this.fromPause = false});
  final int? quick;

  /// Opened by "Do 5 cards" on the pause before an app (D58): at the end, the free time is offered once the
  /// answers are counted.
  final bool fromPause;

  /// How many review screens are open now: an outside entry point never opens a second one on top (D51).
  static int open = 0;
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  DailyQueue? _queue;
  StudyCard? _current;
  Map<int, Duration> _preview = {};
  MemoryBucket? _stage; // where the current card stands (needs the subject's own weights)
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
  int _hints = 0; // problem cards: extra steps shown before the solution
  bool _questionOpen = false; // a long question folded after the reveal, shown whole again by a tap
  final _ratings = <int>[];
  int? _lastRating; // shown in the undo bar for a few seconds after an answer
  Timer? _undoTimer;

  /// The card just answered "Again" for at least the second time: the undo bar then offers to talk it through (D60).
  /// Holds the ANSWERED card, not the one on screen now.
  ({int noteId, int ord})? _talkNudge;

  /// A short session stops after this many answers; "Keep going" lifts the limit (D51).
  late int? _limit = widget.quick;

  /// The pause that sent the learner here, and whether its five cards are done (D58).
  PauseVisit? _visit;
  bool _earned = false;
  bool get _quotaDone => _limit != null && _answered >= _limit!;

  @override
  void initState() {
    super.initState();
    ReviewScreen.open++;
    _load();
  }

  @override
  void dispose() {
    ReviewScreen.open--;
    _poll?.cancel();
    _undoTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({StudyCard? force}) async {
    try {
      final q = await ref.read(queueServiceProvider).build();
      final next = _quotaDone ? null : (force ?? q.next);
      _publishDue(q);
      Map<int, Duration> pv = {};
      MemoryBucket? stage;
      if (next != null) {
        final params = ref.read(paramsRepoProvider);
        final sched = await params.schedulerForDomain(next.domainId);
        pv = sched.preview(next.snapshot, DateTime.now().toUtc());
        final w = (await params.configFor(await params.idForDomain(next.domainId))).weights;
        stage = bucketOf(
            MemoryFact(
                state: next.snapshot.state.dbValue,
                stability: next.snapshot.stability,
                lastReviewMs: next.snapshot.lastReview,
                suspended: next.suspended),
            w,
            DateTime.now().millisecondsSinceEpoch);
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
      if (widget.fromPause && next == null) await _checkPause(q);
      if (!mounted) return;
      setState(() {
        _advice = adv;
        _stats = stats;
        _queue = q;
        _current = next;
        _preview = pv;
        _stage = stage;
        _hints = 0;
        // A worked example (level 1 of a problem) is shown whole from the start.
        _revealed = next != null && next.isProblem && next.problemSteps.isNotEmpty && next.stepsGiven >= next.problemSteps.length;
        _questionOpen = false;
        _loading = false;
        _error = null;
      });
      _stopwatch
        ..reset()
        ..start();
      if (next != null) _autoSpeak(next, revealed: false);
      _poll?.cancel();
      if (!_quotaDone && next == null && q.nextLearningDue != null) {
        // Waiting on a learning step: re-check shortly.
        _poll = Timer.periodic(const Duration(seconds: 20), (_) => _load());
      } else if (next == null && _answered > 0 && !_sessionEnded) {
        _sessionEnded = true;
        // A short session ending with cards still waiting does not interrupt with a question (D51).
        if (!_quotaDone) WidgetsBinding.instance.addPostFrameCallback((_) => _askInterest());
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  /// "Do 5 cards" from the pause (D58): free time only for answers really given since the pause opened.
  Future<void> _checkPause(DailyQueue q) async {
    final visit = await ref.read(pauseBridgeProvider).visit();
    if (visit == null || visit.kind != 'cards') return;
    final n = await ref.read(pauseSettingsProvider).answersSince(visit.atMs);
    _visit = visit;
    _earned = pauseEarned(answersSincePause: n, quota: kQuickSessionCards, nothingLeft: q.ordered.isEmpty);
  }

  Future<void> _backToPaused() async {
    final ok = await ref.read(pauseBridgeProvider).grantAll();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open it again. Open it yourself: it is free for now.')));
    }
  }

  /// Tell the home-screen widget and the Quick Settings tile how many cards are waiting (fire and forget).
  Future<void> _publishDue(DailyQueue q) async {
    try {
      final clock = await ref.read(settingsRepoProvider).dayClock();
      final now = DateTime.now().toUtc();
      final n = q.ordered.length;
      await ref.read(dueBridgeProvider).publish(
          due: n, minutes: (n * 10 / 60).ceil(), dayEndMs: clock.dayEndMs(now), next: q.next == null ? null : pausePreview(q.next!.front));
    } catch (_) {}
  }

  Future<void> _answer(int rating) async {
    final c = _current;
    if (c == null || _busy) return;
    setState(() => _busy = true);
    rating == Rating.again ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
    _stopwatch.stop();
    final ms = c.isProblem
        ? cappedProblemMs(_stopwatch.elapsedMilliseconds)
        : cappedCardMs(_stopwatch.elapsedMilliseconds); // an idle card must not count as hours
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
      _talkNudge = rating == Rating.again && res.card.lapses >= 2 ? (noteId: c.noteId, ord: c.ord) : null;
      _showUndoBar(rating);
      if (res.becameLeech && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This card keeps being forgotten, so it is paused and marked. Rewriting it, or building its foundations, usually helps.')));
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

  /// "Rated Good · Undo" for a few seconds after an answer. The undo button in the top bar stays.
  void _showUndoBar(int rating) {
    _undoTimer?.cancel();
    if (mounted) setState(() => _lastRating = rating);
    // The nudge to talk a forgotten card through has no timer (WCAG 2.2.1): it stays until the next answer, Undo, or its
    // own dismiss button, because a few seconds is too short to decide, and a screen reader needs longer still.
    if (_talkNudge != null) return;
    _undoTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _lastRating = null;
          _talkNudge = null;
        });
      }
    });
  }

  void _hideUndoBar() {
    _undoTimer?.cancel();
    _talkNudge = null;
    if (_lastRating != null && mounted) setState(() => _lastRating = null);
  }

  Future<void> _undo() async {
    if (_busy) return;
    _hideUndoBar();
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

  /// "Talk it through with an AI" (D60). The preview shows the answer, so a card still showing its question counts as
  /// revealed first (a rating given afterwards must not pass for recall from memory). The stopwatch stops while the
  /// sheet is open: the time spent talking is not the time the card took to answer.
  Future<void> _talk(int noteId, int ord) async {
    if (!_revealed && _current != null && _current!.noteId == noteId) _reveal();
    _stopwatch.stop();
    await showTalkSheet(context, noteId: noteId, ord: ord);
    if (mounted && _current != null) _stopwatch.start();
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

  /// Note ids whose mark was flipped on this screen (the queue's own copy of the tags is older).
  final _markFlips = <int>{};
  bool _isMarked(StudyCard c) => c.marked != _markFlips.contains(c.noteId);

  Future<void> _toggleMark() async {
    final c = _current;
    if (c == null) return;
    final now = !_isMarked(c);
    await ref.read(reviewServiceProvider).setMarked(c.noteId, now);
    if (!mounted) return;
    setState(() => _markFlips.contains(c.noteId) ? _markFlips.remove(c.noteId) : _markFlips.add(c.noteId));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(now ? 'Marked. Find it under Library > Browse cards > Marked only.' : 'Mark removed.')));
  }

  /// "Paused" is the word Progress uses (D52). It can be undone from the message, as from a mis-tap.
  Future<void> _pause() async {
    final c = _current;
    if (c == null) return;
    await ref.read(reviewServiceProvider).setSuspended(c.id, true);
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Card paused. Bring it back under Library > Browse cards > Paused only.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await ref.read(reviewServiceProvider).setSuspended(c.id, false);
              if (mounted) await _load(force: c);
            },
          ),
        ));
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
    final text = plainFromMarkup(s.$2 == 'front' && c.noteType != 'cloze' ? c.front : c.back);
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
    final waiting = _queue?.ordered.length ?? 0;
    final left = _quotaDone ? 0 : (_limit == null ? waiting : (waiting < _limit! - _answered ? waiting : _limit! - _answered));
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
              // Undo is the one action used while answering; the rest live in one menu, with "Pause" apart from "Edit"
              // so a tap meant for one cannot land on the other (D52).
              if (_current != null)
                PopupMenuButton<String>(
                  tooltip: 'More actions for this card',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (v) {
                    switch (v) {
                      case 'mark':
                        _toggleMark();
                      case 'edit':
                        _edit();
                      case 'info':
                        showCardInfo(context, _current!);
                      case 'talk':
                        _talk(_current!.noteId, _current!.ord);
                      case 'pause':
                        _pause();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'mark',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_isMarked(_current!) ? Icons.bookmark : Icons.bookmark_outline),
                        title: Text(_isMarked(_current!) ? 'Remove the mark' : 'Mark to look at later'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Edit or delete')),
                    ),
                    const PopupMenuItem(
                      value: 'info',
                      child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.info_outline), title: Text('About this card')),
                    ),
                    const PopupMenuItem(
                      value: 'talk',
                      child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.forum_outlined), title: Text('Talk it through with an AI')),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'pause',
                      child: ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.pause_circle_outline), title: Text('Pause this card')),
                    ),
                  ],
                ),
            ]),
          ),
          if (!_loading && _error == null && _current != null) _progressCaption(context, left),
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: _content(context)),
              if (_lastRating != null)
                Positioned(
                  left: 16,
                  right: 16,
                  // Above the answer buttons, so nothing the learner is about to tap moves or is covered.
                  bottom: _current == null ? 16 : 104,
                  child: _undoBar(context, _lastRating!),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _undoBar(BuildContext context, int rating) {
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        key: const Key('undo-bar'),
        color: c.ink,
        elevation: 3,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
          child: Row(children: [
            Expanded(child: Text('Rated ${ratingName(rating)}', style: t.bodyMedium?.copyWith(color: c.surface))),
            if (_talkNudge != null)
              TextButton(
                key: const Key('talk-nudge'),
                style: TextButton.styleFrom(foregroundColor: c.surface, minimumSize: const Size(64, 48)),
                onPressed: _busy
                    ? null
                    : () {
                        final n = _talkNudge!;
                        _hideUndoBar();
                        _talk(n.noteId, n.ord);
                      },
                child: const Text('Talk it through'),
              ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: c.surface, minimumSize: const Size(64, 48)),
              onPressed: _busy ? null : _undo,
              child: const Text('Undo'),
            ),
            if (_talkNudge != null)
              IconButton(
                key: const Key('talk-nudge-dismiss'),
                tooltip: 'Dismiss',
                color: c.surface,
                icon: const Icon(Icons.close),
                onPressed: _hideUndoBar,
              ),
          ]),
        ),
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
        child: _revealed ? _ratingRow(context) : (card.isProblem ? _problemButtons(card) : _showAnswerButton()),
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

  /// The same words as Progress (D52): New, Learning, Growing, Long-term, Fading ("Learning again" after a lapse).
  String _stateLabel(StudyCard c) {
    if (c.snapshot.state == CardState.relearning) return 'Learning again';
    return (_stage ?? _fallbackStage(c)).label;
  }

  MemoryBucket _fallbackStage(StudyCard c) => switch (c.snapshot.state) {
        CardState.newCard => MemoryBucket.fresh,
        CardState.learning || CardState.relearning => MemoryBucket.learning,
        CardState.review => MemoryBucket.growing,
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
      onTap: _revealed || card.isProblem ? null : _reveal, // a problem is revealed with its buttons, never by a stray tap
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
                    if (card.isProblem) _Tag(icon: Icons.calculate_outlined, text: _problemLabel(card), fg: style.strong, bg: style.tint),
                    // The mark lives in the menu now, so the card itself shows that it is marked.
                    if (_isMarked(card)) _Tag(icon: Icons.bookmark, text: 'Marked', fg: c.accent, bg: c.accentTint),
                    _Tag(
                        text: _stateLabel(card),
                        fg: c.inkSoft,
                        bg: c.surfaceDim,
                        icon: Icons.info_outline,
                        semanticLabel: '${_stateLabel(card)}. About this card\'s memory',
                        onTap: () => showCardInfo(context, card)),
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
                  // Card content comes from an LLM: only a small safe Markdown subset and LaTeX formulas are drawn (RichCardText, D42); never HTML, links or images.
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
                            RichCardText(card.front,
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
                    RichCardText(card.front, style: questionStyle),
                  if (card.isProblem) _problemSteps(context, card, style),
                  if (_revealed) RevealPanel(accent: style.strong, child: _answerSide(context, card, style)),
                  if (!_revealed) ...[
                    const SizedBox(height: 28),
                    Row(children: [
                      Icon(Icons.touch_app_outlined, size: 18, color: c.inkSoft),
                      const SizedBox(width: 6),
                      Expanded(child: Text(card.isProblem ? 'Work it out on paper. Use a hint if you are stuck.' : 'Think of your answer, then tap to reveal', style: t.bodySmall)),
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
      if (card.isProblem && back.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('Answer', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: style.strong, fontWeight: FontWeight.w700)),
        ),
      if (back.isNotEmpty)
        RichCardText(back, selectable: true, style: AppText.sans(answerFontSize(_textSize), weight: 650, height: 1.4, color: c.ink)),
      if (card.isProblem && card.problemLevel > 1)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
              _hints == 0
                  ? 'No hints used. If you got it right, Good or Easy is fair.'
                  : 'You used $_hints ${_hints == 1 ? 'hint' : 'hints'}. If you needed them, Hard is a fair rating.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.inkSoft)),
        ),
      ExtrasStack(extras: card.extras, strong: style.strong, scale: extrasScale(_textSize)),
      if (source.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Text('Source: “$source”', style: Theme.of(context).textTheme.bodySmall),
        ),
    ]);
  }

  String _problemLabel(StudyCard c) {
    if (c.fields['variant_of'] != null) return 'Practice problem';
    return c.problemLevel == 1 ? 'Worked example' : 'Problem · level ${c.problemLevel} of $kProblemLevels';
  }

  /// The worked steps: the ones already given, the ones unlocked by hints, the rest hidden.
  Widget _problemSteps(BuildContext context, StudyCard card, SubjectStyle style) {
    final steps = card.problemSteps;
    if (steps.isEmpty) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final t = Theme.of(context).textTheme;
    final shown = _revealed ? steps.length : (card.stepsGiven + _hints).clamp(0, steps.length);
    final body = AppText.sans(16 * cardTextScale(_textSize), height: 1.4, color: c.ink);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(header: true, child: Text('Steps', style: t.labelMedium?.copyWith(color: style.strong, fontWeight: FontWeight.w700))),
        const SizedBox(height: 6),
        for (final (i, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: i < shown ? style.tint : c.surfaceDim, shape: BoxShape.circle),
                child: Text('${i + 1}', style: t.labelMedium?.copyWith(color: i < shown ? style.strong : c.inkSoft)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: i < shown
                    ? RichCardText(step, selectable: true, style: body)
                    : Semantics(
                        label: 'Step ${i + 1}, hidden',
                        excludeSemantics: true,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(children: [
                            Icon(Icons.lock_outline, size: 16, color: c.inkSoft),
                            const SizedBox(width: 6),
                            Text('Hidden: work it out', style: t.bodyMedium?.copyWith(color: c.inkSoft)),
                          ]),
                        ),
                      ),
              ),
            ]),
          ),
      ]),
    );
  }

  /// Problem cards: ask for the next step, or open the whole solution.
  Widget _problemButtons(StudyCard card) {
    final hidden = card.problemSteps.length - (card.stepsGiven + _hints);
    return Row(children: [
      if (hidden > 0) ...[
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
            onPressed: () => setState(() => _hints++),
            child: const Text('Show next step'),
          ),
        ),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
          onPressed: _reveal,
          child: const Text('Show solution'),
        ),
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
    final waiting = _quotaDone ? null : _queue?.nextLearningDue;
    final leftover = _quotaDone ? (_queue?.ordered.length ?? 0) : 0;
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
            Text(
                _quotaDone
                    ? 'That was your $_answered'
                    : (waiting == null ? (_answered > 0 ? 'Nicely done' : 'All done for today') : 'Next card in about $mins min'),
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
            if (_visit != null && _earned) ...[
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(220, 56)),
                onPressed: _backToPaused,
                child: Text('Back to ${_visit!.label} · free for ${_visit!.freeMinutes} min'),
              ),
              const SizedBox(height: 8),
            ],
            if (leftover > 0) ...[
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(220, 56)),
                onPressed: () {
                  setState(() {
                    _limit = null;
                    _sessionEnded = false;
                    _loading = true;
                  });
                  _load();
                },
                child: Text('Keep going · $leftover waiting'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to home')),
            ] else
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
  const _Tag({required this.text, required this.fg, required this.bg, this.icon, this.onTap, this.semanticLabel});
  final String text;
  final Color fg, bg;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rd.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 5)],
        Text(text, style: AppText.sans(12.5, weight: 650, color: fg)),
      ]),
    );
    if (onTap == null) return pill;
    // A tappable tag keeps a 48 dp target (WCAG 2.2 target size) around the small pill.
    return Semantics(
      button: true,
      label: semanticLabel ?? text,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rd.pill),
        onTap: onTap,
        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Center(widthFactor: 1, child: pill)),
      ),
    );
  }
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
