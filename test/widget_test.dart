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
    final db = AppDatabase(NativeDatabase.memory());
    final bs = Bootstrap(File('unused'), Directory.systemTemp, db);
    await tester.pumpWidget(ProviderScope(
      overrides: [bootstrapProvider.overrideWithValue(bs)],
      child: const DailyLearningApp(),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump();

    expect(find.text('Daily Learning'), findsOneWidget);
    expect(find.textContaining('Nothing here yet'), findsOneWidget);
    expect(find.textContaining('Backups not set up'), findsOneWidget);
    expect(find.text('Learn something new'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
