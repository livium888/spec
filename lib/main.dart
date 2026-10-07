import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/background.dart';
import 'app/bootstrap.dart';
import 'app/providers.dart';
import 'presentation/home_screen.dart';

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
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D5AFE), brightness: b),
          visualDensity: VisualDensity.standard,
        );
    return MaterialApp(
      title: 'Daily Learning',
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
