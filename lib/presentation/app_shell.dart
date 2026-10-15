import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/launch_service.dart';
import '../app/providers.dart';
import '../app/share_service.dart';
import 'home_screen.dart';
import 'pause_summary.dart';
import 'import_screen.dart';
import 'library_screen.dart';
import 'progress_screen.dart';
import 'review_screen.dart';
import 'socratic_pause_screen.dart';

/// Three places: Today, Progress, Library. Settings lives in the Today header.
/// Also the one place that notices text shared into the app (an AI's answer) and opens the
/// import preview for it, at launch and whenever the app comes back to the front.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _checking = false;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LaunchRelay.pending.addListener(_checkLaunch);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(pauseSettingsProvider).push().ignore(); // the pause service runs without the app (D58)
      await _checkLaunch(coldStart: true);
      await _checkTalk();
      await _checkShared();
    });
  }

  @override
  void dispose() {
    LaunchRelay.pending.removeListener(_checkLaunch);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(pauseSummaryProvider); // back from LinkedIn or Android's settings: fresh counts and status (D59)
      ref.read(pauseSettingsProvider).push().ignore(); // reviewed cards since last time may make the conversation available (D66)
      _checkLaunch().then((_) => _checkTalk());
      _checkShared();
    }
  }

  /// A shortcut, the widget, the Quick Settings tile or the reminder asked to open the review (D51). Never twice
  /// at once, and never on top of a review that is already open.
  Future<void> _checkLaunch({bool coldStart = false}) async {
    if (_launching || !mounted) return;
    _launching = true;
    LaunchRoute? route;
    try {
      route = LaunchRelay.take();
      route ??= await ref.read(launchInboxProvider).take();
      if (route == null && coldStart && await ref.read(notificationLaunchProvider).openedFromReminder()) {
        route = LaunchRoute.review;
      }
    } finally {
      _launching = false; // not held while the review is open: the route is already taken
    }
    if (route == LaunchRoute.pauseTalk) {
      if (mounted && SocraticPauseScreen.open == 0 && ReviewScreen.open == 0) {
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SocraticPauseScreen()));
      }
      return;
    }
    if (route == null || !mounted || ReviewScreen.open > 0) return;
    final quick = route == LaunchRoute.review ? null : kQuickSessionCards;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReviewScreen(quick: quick, fromPause: route == LaunchRoute.pause)));
    if (mounted) ref.read(refreshProvider.notifier).bump();
  }

  /// The learner left for an AI app in the middle of a Socratic pause (D66) and the app was closed meanwhile, or they
  /// opened this app by hand: if a conversation has been started, bring its screen back so the time earned is not lost.
  Future<void> _checkTalk() async {
    if (!mounted || SocraticPauseScreen.open > 0 || ReviewScreen.open > 0) return;
    final v = await ref.read(pauseBridgeProvider).visit();
    if (v == null || v.kind != 'talk' || !v.started || !mounted || SocraticPauseScreen.open > 0) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SocraticPauseScreen()));
  }

  Future<void> _checkShared() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final text = await ref.read(shareInboxProvider).take();
      if (text == null || text.trim().isEmpty || !mounted) return;
      if (text.length > kMaxSharedChars) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That shared text is too large to import. Copy the JSON instead.')));
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ImportScreen(initialText: text)));
      if (mounted) ref.read(refreshProvider.notifier).bump();
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [HomeScreen(), ProgressScreen(), LibraryScreen()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny), label: 'Today'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Progress'),
            NavigationDestination(icon: Icon(Icons.collections_bookmark_outlined), selectedIcon: Icon(Icons.collections_bookmark), label: 'Library'),
          ],
        ),
      );
}
