import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/background.dart';
import 'app/bootstrap.dart';
import 'app/providers.dart';
import 'presentation/app_shell.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bs = await Bootstrap.open();
  try {
    await initBackgroundBackup();
  } catch (_) {
    // Backups can still be triggered manually / on open; surfaced in Settings.
  }
  runApp(ProviderScope(
    overrides: [bootstrapProvider.overrideWithValue(bs)],
    child: const DailyLearningApp(),
  ));
}

class DailyLearningApp extends StatelessWidget {
  const DailyLearningApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Daily Learning',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const AppShell(),
      );
}
