import 'package:daily_learning/data/reminder_service.dart';
import 'package:daily_learning/domain/reminder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;

class FakeBackend implements ReminderBackend {
  bool allow = true;
  final scheduled = <DateTime>[];
  final bodies = <String>[];
  int cancels = 0;
  @override
  Future<bool> requestPermission() async => allow;
  @override
  Future<void> scheduleDaily(DateTime firstLocal, String title, String body) async {
    scheduled.add(firstLocal);
    bodies.add(body);
  }

  @override
  Future<void> cancel() async => cancels++;
}

void main() {
  group('nextReminder (pure)', () {
    test('later today when the time is still ahead and work is not done', () {
      expect(nextReminder(DateTime(2026, 3, 10, 8, 30), 19, 0, doneToday: false), DateTime(2026, 3, 10, 19, 0));
    });
    test('tomorrow once the time has passed', () {
      expect(nextReminder(DateTime(2026, 3, 10, 19, 0), 19, 0, doneToday: false), DateTime(2026, 3, 11, 19, 0));
      expect(nextReminder(DateTime(2026, 3, 10, 21, 5), 19, 0, doneToday: false), DateTime(2026, 3, 11, 19, 0));
    });
    test('tomorrow when today\'s reviews are already done, even if the time is ahead', () {
      expect(nextReminder(DateTime(2026, 3, 10, 8, 30), 19, 0, doneToday: true), DateTime(2026, 3, 11, 19, 0));
    });
    test('month and year ends', () {
      expect(nextReminder(DateTime(2026, 12, 31, 20, 0), 19, 30, doneToday: false), DateTime(2027, 1, 1, 19, 30));
      expect(nextReminder(DateTime(2026, 2, 28, 20, 0), 7, 0, doneToday: false), DateTime(2026, 3, 1, 7, 0));
    });
    test('copy is friendly, varies by day, and never scolds', () {
      final bodies = {for (var d = 1; d <= 28; d++) reminderBody(DateTime(2026, 3, d))};
      expect(bodies.length, greaterThan(1));
      for (final b in bodies) {
        expect(b.toLowerCase(), isNot(anyOf(contains('miss'), contains('streak'), contains('lose'), contains('!'))));
      }
    });
    test('clock format', () => expect(formatClock(7, 5), '07:05'));
  });

  group('ReminderService', () {
    late Env e;
    late FakeBackend backend;
    late ReminderService svc;
    var now = DateTime(2026, 3, 10, 8, 30);
    setUp(() {
      e = Env();
      backend = FakeBackend();
      now = DateTime(2026, 3, 10, 8, 30);
      svc = ReminderService(e.settings, backend, clock: () => now);
    });

    test('off by default; nothing is scheduled by refresh', () async {
      expect((await svc.config()).enabled, isFalse);
      await svc.refresh(doneToday: false);
      expect(backend.scheduled, isEmpty);
    });

    test('enabling asks for permission, saves the time and schedules the next one', () async {
      expect(await svc.enable(19, 0), isTrue);
      final c = await svc.config();
      expect((c.enabled, c.hour, c.minute), (true, 19, 0));
      expect(backend.scheduled.single, DateTime(2026, 3, 10, 19, 0));
    });

    test('a refused permission leaves it off and schedules nothing', () async {
      backend.allow = false;
      expect(await svc.enable(19, 0), isFalse);
      expect((await svc.config()).enabled, isFalse);
      expect(backend.scheduled, isEmpty);
    });

    test('finishing today\'s reviews moves the next reminder to tomorrow; opening the app tomorrow brings it back', () async {
      await svc.enable(19, 0);
      await svc.refresh(doneToday: true);
      expect(backend.scheduled.last, DateTime(2026, 3, 11, 19, 0));
      now = DateTime(2026, 3, 11, 8, 0);
      await svc.refresh(doneToday: false);
      expect(backend.scheduled.last, DateTime(2026, 3, 11, 19, 0));
    });

    test('changing the time reschedules only while enabled', () async {
      await svc.setTime(6, 45);
      expect(backend.scheduled, isEmpty);
      await svc.enable(6, 45);
      backend.scheduled.clear();
      await svc.setTime(21, 15);
      expect(backend.scheduled.single, DateTime(2026, 3, 10, 21, 15));
    });

    test('disabling cancels and later refreshes do nothing', () async {
      await svc.enable(19, 0);
      await svc.disable();
      expect(backend.cancels, 1);
      backend.scheduled.clear();
      await svc.refresh(doneToday: false);
      expect(backend.scheduled, isEmpty);
    });

    test('a failing backend never throws', () async {
      final bad = ReminderService(e.settings, _Throwing(), clock: () => now);
      expect(await bad.enable(19, 0), isFalse);
      await e.settings.set(ReminderService.enabledKey, '1');
      await bad.refresh(doneToday: false); // swallowed
      await bad.disable();
    });
  });
}

class _Throwing implements ReminderBackend {
  @override
  Future<bool> requestPermission() async => throw StateError('no');
  @override
  Future<void> scheduleDaily(DateTime firstLocal, String title, String body) async => throw StateError('no');
  @override
  Future<void> cancel() async => throw StateError('no');
}
