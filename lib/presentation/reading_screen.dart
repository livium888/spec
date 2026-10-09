import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/picture_finder.dart' show PictureFinderException;
import '../data/reading_service.dart';
import '../data/settings_repo.dart';
import '../domain/reading.dart';

/// Library > Go deeper. Books and articles the AI suggested for the learner's topics. Every entry is
/// an AI SUGGESTION: "Check it exists" asks Open Library or Crossref whether a work with that title
/// and author is listed. That is all it proves: not that the work is good, or the right level.
class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key});
  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  List<ReadingRow>? _rows;
  String? _error;
  final _busy = <int>{};
  String? _message;
  bool _checkingAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(readingServiceProvider).list();
      if (mounted) setState(() { _rows = r; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _log(Object e, [StackTrace? st]) {
    try {
      ref.read(errorLogProvider).record(e, st, where: 'reading');
    } catch (_) {}
  }

  /// The first online step of this feature, so it asks once and says what leaves the phone.
  Future<bool> _consent() async {
    final settings = ref.read(settingsRepoProvider);
    if (await settings.get(SettingsRepo.onlineReading) == SettingsRepo.onlineReadingAgreed) return true;
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check these online?'),
        content: const Text(
          'To check that a suggested book or article really exists, the app sends its title and author (and your phone\'s '
          'internet address, as any website visit does) to Open Library (a free library catalogue) and Crossref (a free '
          'index of articles). Nothing else leaves your phone: no cards, no history. You can turn this off in Settings.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow')),
        ],
      ),
    );
    if (ok != true) return false;
    await settings.set(SettingsRepo.onlineReading, SettingsRepo.onlineReadingAgreed);
    return true;
  }

  Future<bool> _checkRow(ReadingRow r) async {
    setState(() => _busy.add(r.id));
    try {
      final c = await ref.read(readingVerifierProvider).check(r.suggestion);
      await ref.read(readingServiceProvider).recordCheck(r.id, c);
      await _load();
      return true;
    } on PictureFinderException catch (e) {
      _log('Reading check failed: ${e.message}');
      if (mounted) setState(() => _message = 'Could not check "${r.suggestion.title}": ${e.message}');
      return false;
    } catch (e, st) {
      _log(e, st);
      if (mounted) setState(() => _message = 'Could not check "${r.suggestion.title}".');
      return false;
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<void> _checkOne(ReadingRow r) async {
    if (!await _consent()) return;
    setState(() => _message = null);
    await _checkRow(r);
  }

  Future<void> _checkAll() async {
    if (!await _consent()) return;
    final todo = [for (final r in _rows ?? const <ReadingRow>[]) if (r.checkStatus == 'unchecked' && r.suggestion.kind.checkable) r];
    if (todo.isEmpty) return;
    setState(() { _checkingAll = true; _message = null; });
    var done = 0;
    for (final r in todo) {
      if (!mounted) return;
      // A failure (offline, rate limit) stops the run: the rest would fail the same way.
      if (!await _checkRow(r)) break;
      done++;
    }
    if (mounted) {
      setState(() {
        _checkingAll = false;
        _message ??= 'Checked $done.';
      });
    }
  }

  Future<void> _open(ReadingRow r) async {
    final url = Uri.tryParse(r.catalogueUrl ?? '');
    if (url == null) return;
    final problem = await ref.read(pageOpenerProvider).open(url);
    if (problem != null && mounted) setState(() => _message = problem);
  }

  Future<void> _remove(ReadingRow r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this suggestion?'),
        content: Text('"${r.suggestion.title}" is taken off your reading list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(readingServiceProvider).delete(r.id);
    await _load();
  }

  static String _catalogue(String? url) {
    final host = Uri.tryParse(url ?? '')?.host ?? '';
    if (host.contains('openlibrary')) return 'Open Library';
    if (host.contains('doi.org')) return 'Crossref';
    return 'a catalogue';
  }

  Widget _status(BuildContext context, ReadingRow r) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    // A kind no catalogue can confirm (a course) says so at once; there is nothing to wait for.
    final status = r.suggestion.kind.checkable ? r.checkStatus : 'cannot';
    final (icon, text, color) = switch (status) {
      'found' => (Icons.check_circle_outline, 'Listed in ${_catalogue(r.catalogueUrl)}', c.primary),
      'notfound' => (Icons.help_outline, 'Not found in the catalogue: the title or author may be wrong', c.error),
      'cannot' => (Icons.info_outline, 'Cannot be checked automatically', c.onSurfaceVariant),
      _ => (Icons.radio_button_unchecked, 'Not checked yet', c.onSurfaceVariant),
    };
    // An icon AND words: the state is never carried by colour alone.
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: t.bodySmall?.copyWith(color: color))),
    ]);
  }

  Widget _item(BuildContext context, ReadingRow r) {
    final t = Theme.of(context).textTheme;
    final s = r.suggestion;
    final busy = _busy.contains(r.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${s.kind.label}${r.topic == null ? '' : ' · ${r.topic}'}', style: t.labelMedium),
          const SizedBox(height: 4),
          Text(s.title, style: t.titleMedium?.copyWith(decoration: r.done ? TextDecoration.lineThrough : null)),
          if (s.author.isNotEmpty) Text('by ${s.author}', style: t.bodyMedium),
          if (s.why.isNotEmpty) ...[const SizedBox(height: 6), Text(s.why, style: t.bodyMedium)],
          const SizedBox(height: 10),
          _status(context, r),
          if (r.checkStatus == 'found' && r.foundTitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Catalogue entry: ${r.foundTitle}${r.foundYear == null ? '' : ' (${r.foundYear})'}', style: t.bodySmall),
            ),
          const SizedBox(height: 6),
          Wrap(spacing: 4, children: [
            if (busy)
              const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            else if (s.kind.checkable && (r.checkStatus == 'unchecked' || r.checkStatus == 'notfound'))
              TextButton.icon(
                  icon: const Icon(Icons.fact_check_outlined), label: Text(r.checkStatus == 'notfound' ? 'Check again' : 'Check it exists'), onPressed: () => _checkOne(r)),
            if (r.checkStatus == 'found' && r.catalogueUrl != null)
              TextButton.icon(icon: const Icon(Icons.menu_book_outlined), label: const Text('Look it up'), onPressed: () => _open(r)),
            TextButton.icon(
              icon: Icon(r.done ? Icons.undo : Icons.done),
              label: Text(r.done ? 'Not read yet' : 'Mark as read'),
              onPressed: () async {
                await ref.read(readingServiceProvider).setDone(r.id, !r.done);
                await _load();
              },
            ),
            TextButton.icon(icon: const Icon(Icons.delete_outline), label: const Text('Remove'), onPressed: () => _remove(r)),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('Go deeper')),
      body: SafeArea(
        child: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Could not load: $_error')))
            : rows == null
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? ListView(padding: const EdgeInsets.all(16), children: [
                        Text('No reading suggestions yet.', style: t.titleMedium),
                        const SizedBox(height: 8),
                        const Text('They arrive with new cards: when you import cards for a topic, your AI may add two or three books or articles '
                            'for going deeper. They show up here, never in the middle of your reviews.'),
                      ])
                    : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                        Text('These are suggestions from an AI, which can get a title or an author wrong. "Check it exists" asks a library '
                            'catalogue whether a work with that title and author is listed. It cannot tell you whether the book is any good: '
                            'look at the author and the publisher before you spend time on it.',
                            style: t.bodyMedium),
                        const SizedBox(height: 12),
                        if (rows.any((r) => r.checkStatus == 'unchecked' && r.suggestion.kind.checkable))
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                            icon: _checkingAll ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.fact_check_outlined),
                            label: Text(_checkingAll ? 'Checking…' : 'Check all that have not been checked'),
                            onPressed: _checkingAll ? null : _checkAll,
                          ),
                        if (_message != null)
                          Semantics(liveRegion: true, child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!, style: t.bodyLarge))),
                        for (var i = 0; i < rows.length; i++) ...[
                          if (i == 0 || rows[i].subject != rows[i - 1].subject)
                            Padding(
                              padding: const EdgeInsets.only(top: 20, bottom: 6),
                              child: Semantics(header: true, child: Text(rows[i].subject, style: t.titleLarge)),
                            ),
                          _item(context, rows[i]),
                        ],
                      ]),
      ),
    );
  }
}
