import 'dart:io';

/// A small local log of crashes and unexpected errors, so a problem on the phone can be
/// shared and diagnosed. Offline: it only ever writes to one file next to the database.
/// Synchronous on purpose (it runs inside error handlers, possibly while crashing).
/// Entries can contain text from the error message, so the learner shares it by choice.
class ErrorLog {
  ErrorLog(this.file, {this.maxBytes = 120000});
  final File file;
  final int maxBytes;

  static const _maxMessage = 1500;
  static const _maxStackLines = 14;

  void record(Object error, StackTrace? stack, {String where = ''}) {
    try {
      var msg = '$error';
      if (msg.length > _maxMessage) msg = '${msg.substring(0, _maxMessage)}…';
      final lines = (stack?.toString() ?? '').split('\n').where((l) => l.trim().isNotEmpty).take(_maxStackLines);
      final entry = StringBuffer()
        ..writeln('--- ${DateTime.now().toUtc().toIso8601String()}${where.isEmpty ? '' : ' [$where]'}')
        ..writeln(msg)
        ..writeAll(lines, '\n')
        ..writeln();
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.toString(), mode: FileMode.append, flush: true);
      _trim();
    } catch (_) {
      // The error log must never be the thing that crashes the app.
    }
  }

  /// Newest [maxChars] characters (whole log by default).
  String read({int maxChars = 8000}) {
    try {
      if (!file.existsSync()) return '';
      final t = file.readAsStringSync();
      return t.length <= maxChars ? t : '…${t.substring(t.length - maxChars)}';
    } catch (_) {
      return '';
    }
  }

  int get entryCount {
    try {
      return file.existsSync() ? '--- '.allMatches(file.readAsStringSync()).length : 0;
    } catch (_) {
      return 0;
    }
  }

  void clear() {
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  /// Keep the newest half when the file grows past [maxBytes], cut at an entry boundary.
  void _trim() {
    if (file.lengthSync() <= maxBytes) return;
    final t = file.readAsStringSync();
    final from = t.indexOf('--- ', t.length ~/ 2);
    file.writeAsStringSync(from < 0 ? t.substring(t.length ~/ 2) : t.substring(from), flush: true);
  }
}
