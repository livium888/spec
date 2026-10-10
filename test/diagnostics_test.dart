import 'dart:io';

import 'package:daily_learning/app/build_info.dart';
import 'package:daily_learning/data/error_log.dart';
import 'package:daily_learning/domain/diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('errlog'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('ErrorLog', () {
    test('records message, place and a short stack; reads them back', () {
      final log = ErrorLog(File('${dir.path}/error.log'));
      expect(log.read(), '');
      expect(log.entryCount, 0);
      log.record(StateError('boom'), StackTrace.current, where: 'test');
      final t = log.read();
      expect(t, contains('[test]'));
      expect(t, contains('boom'));
      expect(log.entryCount, 1);
    });

    test('every entry names the build that wrote it, so an old entry can be told from a new one', () {
      final log = ErrorLog(File('${dir.path}/error.log'), build: '46');
      log.record('first', null, where: 'a');
      ErrorLog(File('${dir.path}/error.log'), build: '47').record('second', null);
      final t = log.read();
      expect(RegExp(r'--- \S+Z build 46 \[a\]\nfirst').hasMatch(t), isTrue, reason: t);
      expect(RegExp(r'--- \S+Z build 47\nsecond').hasMatch(t), isTrue, reason: t);
      expect(log.entryCount, 2);
    });

    test('long messages and stacks are cut; the file stays bounded and keeps the newest entries', () {
      final log = ErrorLog(File('${dir.path}/error.log'), maxBytes: 6000);
      for (var i = 0; i < 80; i++) {
        log.record('error number $i ${'x' * 3000}', StackTrace.current, where: 'loop');
      }
      final size = File('${dir.path}/error.log').lengthSync();
      expect(size, lessThan(6000 + 4000)); // never grows far past the cap
      expect(log.read(maxChars: 100000), contains('error number 79'));
      expect(log.read(maxChars: 100000), isNot(contains('error number 0 ')));
      expect(log.read(maxChars: 100000), isNot(contains('x' * 2000))); // each message was cut at 1,500
    });

    test('clear empties it, and a broken path never throws', () {
      final log = ErrorLog(File('${dir.path}/error.log'))..record('a', null);
      log.clear();
      expect(log.read(), '');
      ErrorLog(File('/proc/definitely/not/writable/error.log')).record('b', null); // must not throw
    });

    test('read(maxChars) returns only the newest part', () {
      final log = ErrorLog(File('${dir.path}/error.log'));
      log.record('first', null);
      log.record('last', null);
      final t = log.read(maxChars: 40);
      expect(t, contains('last'));
      expect(t, isNot(contains('first')));
    });
  });

  group('report', () {
    test('lists every check with its state, notes and the error tail', () {
      final r = renderReport(
        build: 'Build 12 (abc1234)',
        os: 'Android 14',
        facts: {'Cards': '5'},
        checks: {'review': CheckState.works, 'backup': CheckState.broken},
        notes: 'Gemini added text around the JSON',
        errorLogTail: '',
      );
      expect(r, contains('Build 12 (abc1234)'));
      expect(r, contains('Cards: 5'));
      expect(r, contains('[works] Review a few cards'));
      expect(r, contains('[BROKEN] Backup to a folder'));
      expect(r, contains('[not tried] Daily reminder'));
      expect(r, contains('Gemini added text'));
      expect(r, contains('(no errors recorded)'));
      expect(kPhoneCheck.map((i) => i.id).toSet().length, kPhoneCheck.length); // ids are unique
    });
  });

  test('build label is honest about local builds', () {
    expect(BuildInfo.label, 'Local development build'); // no dart-define in tests
  });
}
