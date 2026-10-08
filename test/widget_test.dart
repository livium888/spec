import 'package:daily_learning/app/bootstrap.dart';
import 'package:daily_learning/app/providers.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/main.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  testWidgets('home shows empty state and backup warning on a fresh install', (tester) async {
    tester.view.physicalSize = const Size(411, 900); // a phone, not the 800x600 default
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    final bs = Bootstrap(File('unused'), Directory.systemTemp, db);
    await tester.pumpWidget(ProviderScope(
      overrides: [bootstrapProvider.overrideWithValue(bs)],
      child: const DailyLearningApp(),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('plant your first cards'), findsOneWidget);
    expect(find.textContaining('Backups not set up'), findsOneWidget);
    expect(find.text('Learn something new'), findsOneWidget);
    expect(find.textContaining('Good time to learn'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
