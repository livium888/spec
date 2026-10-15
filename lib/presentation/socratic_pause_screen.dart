import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/pause_bridge.dart';
import '../domain/talk_prompt.dart';
import 'theme/tokens.dart';
import 'widgets/soft_card.dart';

/// "Talk it through, then open" (D66): the pause's Socratic way out. The app picks one card the learner struggled with,
/// the learner takes it to an AI app for a purely Socratic conversation, and after the minimum time they open the paused
/// app for a few minutes. Nothing here checks that the conversation happened: the minimum time only stops a tap-through,
/// and a learner who skips it has only fooled themselves.
///
/// Everything that must outlive this screen lives on the phone side (the card, the minute counter, the expiry): the
/// learner leaves for an AI app, Android may close this app meanwhile, and the app reopens this screen when they come back.
class SocraticPauseScreen extends ConsumerStatefulWidget {
  const SocraticPauseScreen({super.key});

  /// How many of these screens are open now (the shell does not open a second one on top).
  static int open = 0;

  @override
  ConsumerState<SocraticPauseScreen> createState() => _SocraticPauseScreenState();
}

enum _Phase { loading, noVisit, notTalk, noCard, ready, error }

class _SocraticPauseScreenState extends ConsumerState<SocraticPauseScreen> with WidgetsBindingObserver {
  _Phase _phase = _Phase.loading;
  PauseVisit? _visit;
  TalkCard? _card;
  String? _profile;
  int _noteId = 0, _ord = 0;
  bool _started = false;
  int _left = kTalkMinSeconds;
  String? _message, _error;
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    SocraticPauseScreen.open++;
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    SocraticPauseScreen.open--;
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the AI app: ask the phone side how long is left (the clock there kept running).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _phase == _Phase.ready && _started) _resync();
  }

  Future<void> _resync() async {
    final v = await ref.read(pauseBridgeProvider).visit();
    if (!mounted) return;
    if (v == null || v.kind != 'talk') {
      setState(() => _phase = _Phase.noVisit);
      return;
    }
    setState(() {
      _visit = v;
      _left = v.secondsLeft;
    });
  }

  Future<void> _load() async {
    try {
      final bridge = ref.read(pauseBridgeProvider);
      final v = await bridge.visit();
      if (!mounted) return;
      if (v == null) return setState(() => _phase = _Phase.noVisit);
      if (v.kind != 'talk') return setState(() => _phase = _Phase.notTalk);
      final service = ref.read(socraticServiceProvider);
      int noteId, ord;
      if (v.started && v.noteId != null) {
        // Back after leaving for the AI app (or after the app was closed): the same card, not a new pick.
        noteId = v.noteId!;
        ord = v.ord;
      } else {
        final settings = ref.read(pauseSettingsProvider);
        final days = await settings.week();
        final clock = await ref.read(settingsRepoProvider).dayClock();
        final pick = await service.pick(now: DateTime.now(), clock: clock, talksToday: days.isEmpty ? 0 : days.last.talk);
        if (pick == null) return setState(() => _phase = _Phase.noCard);
        noteId = pick.noteId;
        ord = pick.ord;
      }
      final card = await service.load(noteId, ord);
      final profile = await ref.read(talkServiceProvider).profile();
      if (!mounted) return;
      if (card == null) return setState(() => _phase = _Phase.noCard);
      setState(() {
        _visit = v;
        _card = card;
        _profile = profile;
        _noteId = noteId;
        _ord = ord;
        _started = v.started;
        _left = v.started ? v.secondsLeft : kTalkMinSeconds;
        _phase = _Phase.ready;
      });
      if (v.started) _startTicker();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _phase = _Phase.error;
        });
      }
    }
  }

  void _startTicker() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left > 0) setState(() => _left--);
    });
  }

  String get _prompt => renderSocraticPrompt(_card!, learnerProfile: _profile);

  /// The first Share or Copy: tag the note (best effort), and have the phone side keep the card and start its clock.
  Future<void> _begin() async {
    try {
      await ref.read(reviewServiceProvider).markTalkedThrough(_noteId);
    } catch (_) {}
    final left = await ref.read(pauseBridgeProvider).talkStart(_noteId, _ord);
    if (!mounted) return;
    setState(() {
      _started = true;
      _left = left;
      _message = null;
    });
    _startTicker();
  }

  Future<void> _share() async {
    final text = _prompt;
    await _begin();
    try {
      await ref.read(promptSharerProvider).send(text, title: 'Talk through a card');
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not open the share sheet: $e. Use Copy instead.');
    }
  }

  Future<void> _copy() async {
    final text = _prompt;
    await _begin();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _message = 'Copied. Paste it into your AI app.');
  }

  Future<void> _openApp() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final g = await ref.read(pauseBridgeProvider).grantTalk();
    if (!mounted) return;
    if (g.ok) {
      Navigator.of(context).maybePop(); // the phone side has already brought the app back to the front
      return;
    }
    setState(() {
      _busy = false;
      if (g.reason == 'early') {
        _left = g.secondsLeft;
        _message = 'A little longer: the conversation needs at least ${kTalkMinSeconds ~/ 60} minutes.';
      } else {
        _message = 'This pause has run out. Open the app or site again to start a new one.';
        _phase = _Phase.noVisit;
      }
    });
  }

  Future<void> _notNow() async {
    await ref.read(pauseBridgeProvider).dropVisit();
    if (mounted) Navigator.of(context).maybePop();
  }

  String get _clock => '${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    Widget closeOnly(String title, String text) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleLarge),
            const SizedBox(height: 8),
            Text(text, style: t.bodyLarge),
            const SizedBox(height: 16),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), onPressed: () => Navigator.of(context).maybePop(), child: const Text('Close')),
          ]),
        );

    final Widget body;
    switch (_phase) {
      case _Phase.loading:
        body = const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading the card'));
      case _Phase.noVisit:
        body = closeOnly('This pause has run out', _message ?? 'Open the app or site again to start a new pause.');
      case _Phase.notTalk:
        body = closeOnly('This pause asked for cards', 'It was not a conversation. Open the app or site again.');
      case _Phase.noCard:
        body = closeOnly('No card to talk about', 'A conversation needs a card you have reviewed. Do a few cards first, then try again.');
      case _Phase.error:
        body = closeOnly('This could not be read', _error ?? '');
      case _Phase.ready:
        final label = _visit?.label ?? 'the app';
        final minutes = _visit?.freeMinutes ?? 5;
        final card = _card!;
        final ready = _started && _left <= 0;
        body = ListView(padding: const EdgeInsets.all(16), children: [
          Semantics(header: true, child: Text('Before you open $label', style: t.headlineSmall)),
          const SizedBox(height: 8),
          Text(
            'Your AI will ask you questions about this card, one at a time. It will not explain it or tell you the answer. '
            'Then $label is free for $minutes ${minutes == 1 ? 'minute' : 'minutes'}.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 16),
          SoftCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text([card.domain, if ((card.syllabusItem ?? '').isNotEmpty) card.syllabusItem!].join(' · '), style: t.labelMedium?.copyWith(color: c.inkSoft)),
              const SizedBox(height: 6),
              Text(card.question, style: t.titleMedium),
            ]),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.share),
            label: Text(_started ? 'Share again' : 'Share to an AI app'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _busy ? null : _copy,
            icon: const Icon(Icons.copy),
            label: const Text('Copy prompt'),
          ),
          if (_message != null)
            Semantics(liveRegion: true, child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!, style: t.bodyMedium))),
          if (_started) ...[
            const SizedBox(height: 20),
            if (!ready)
              Semantics(
                liveRegion: false,
                child: Text('Talk for at least ${kTalkMinSeconds ~/ 60} minutes, then come back here. You can open $label in $_clock.', style: t.bodyLarge),
              ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: ready && !_busy ? _openApp : null,
              child: Text(ready ? 'I talked it through: open $label for $minutes ${minutes == 1 ? 'minute' : 'minutes'}' : 'Open $label (in $_clock)'),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Nothing checks that the conversation happened. The wait only stops you tapping through, and if you skip the conversation, '
            'you have only fooled yourself.',
            style: t.bodySmall?.copyWith(color: c.inkSoft),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(style: TextButton.styleFrom(minimumSize: const Size(64, 48)), onPressed: _busy ? null : _notNow, child: const Text('Not now')),
          ),
        ]);
    }
    return Scaffold(appBar: AppBar(title: const Text('Talk it through')), body: SafeArea(child: body));
  }
}
