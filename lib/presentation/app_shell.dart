import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/share_service.dart';
import 'home_screen.dart';
import 'import_screen.dart';
import 'library_screen.dart';
import 'progress_screen.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkShared());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkShared();
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
