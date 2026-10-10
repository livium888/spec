import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import '../app/providers.dart';
import '../data/anki_import_service.dart';
import '../data/anki_package.dart';
import 'theme/tokens.dart';
import 'topics_screen.dart';
import 'widgets/soft_card.dart';

/// Picks a file and copies it into the app's private folder: (the copy, its display name). Replaceable in tests.
typedef AnkiFilePicker = Future<(File, String)?> Function();

final ankiFilePickerProvider = Provider<AnkiFilePicker>((ref) => () async {
      final f = await SafUtil().pickFile();
      if (f == null) return null;
      final tmp = ref.read(bootstrapProvider).tmpDir;
      await tmp.create(recursive: true);
      final dest = File('${tmp.path}/anki_pick_${DateTime.now().microsecondsSinceEpoch}');
      await SafStream().copyToLocalFile(f.uri, dest.path);
      return (dest, f.name);
    });

enum _Step { start, reading, plan, importing, done }

/// Bring in cards from Anki (D50): a `.apkg` package (made with "Support older Anki versions") or a plain-text /
/// CSV export. Cards arrive as NEW cards; Anki's own scheduling and history are not imported.
class AnkiImportScreen extends ConsumerStatefulWidget {
  const AnkiImportScreen({super.key});
  @override
  ConsumerState<AnkiImportScreen> createState() => _AnkiImportScreenState();
}

class _AnkiImportScreenState extends ConsumerState<AnkiImportScreen> {
  _Step _step = _Step.start;
  String? _error;
  AnkiRead? _read;
  AnkiPlan? _plan;
  File? _file;
  int _done = 0, _total = 0;
  AnkiImportResult? _result;
  final _names = <AnkiSubjectPlan, TextEditingController>{};

  @override
  void dispose() {
    _cleanup();
    for (final c in _names.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _cleanup() {
    _read?.close();
    _read = null;
    try {
      if (_file?.existsSync() ?? false) _file!.deleteSync();
    } catch (_) {}
    _file = null;
  }

  Future<void> _choose() async {
    setState(() {
      _error = null;
      _step = _Step.reading;
    });
    try {
      final picked = await ref.read(ankiFilePickerProvider)();
      if (picked == null) {
        if (mounted) setState(() => _step = _Step.start);
        return;
      }
      _cleanup();
      _file = picked.$1;
      final tmp = ref.read(bootstrapProvider).tmpDir;
      final read = await readAnkiFile(picked.$1, tmp, name: picked.$2);
      final plan = AnkiImportService(ref.read(dbProvider)).plan(read);
      if (!mounted) {
        read.close();
        return;
      }
      for (final c in _names.values) {
        c.dispose();
      }
      _names
        ..clear()
        ..addEntries([for (final s in plan.subjects) MapEntry(s, TextEditingController(text: s.subject))]);
      setState(() {
        _read = read;
        _plan = plan;
        _step = plan.importable == 0 ? _Step.start : _Step.plan;
        if (plan.importable == 0) _error = 'No importable cards in that file (${_skipSummary(plan)}).';
      });
    } on AnkiFileException catch (e) {
      _cleanup();
      if (mounted) setState(() { _error = e.message; _step = _Step.start; });
    } catch (e) {
      _cleanup();
      if (mounted) setState(() { _error = 'Could not read that file: $e'; _step = _Step.start; });
    }
  }

  String _skipSummary(AnkiPlan p) => p.skipped.isEmpty
      ? 'nothing found'
      : [for (final e in p.skipped.entries) '${e.value} ${AnkiPlan.skipWords(e.key)}'].join(', ');

  Future<void> _import() async {
    final plan = _plan!;
    for (final e in _names.entries) {
      e.key.subject = e.value.text.trim();
    }
    if (plan.subjects.any((s) => s.selected && s.subject.isEmpty)) {
      setState(() => _error = 'Give every ticked subject a name.');
      return;
    }
    setState(() {
      _error = null;
      _step = _Step.importing;
      _done = 0;
      _total = plan.subjects.where((s) => s.selected).fold(0, (a, s) => a + s.count);
    });
    try {
      final r = await AnkiImportService(ref.read(dbProvider)).import(plan, _read!, onProgress: (d, t) {
        if (mounted) setState(() { _done = d; _total = t; });
      });
      _cleanup();
      ref.read(refreshProvider.notifier).bump();
      if (mounted) setState(() { _result = r; _step = _Step.done; });
    } catch (e) {
      if (mounted) setState(() { _error = 'The import stopped: $e. Cards already added are kept; importing again skips them.'; _step = _Step.plan; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import from Anki')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: switch (_step) {
          _Step.start => _start(context),
          _Step.reading => [const SizedBox(height: 80), const Center(child: CircularProgressIndicator()), const SizedBox(height: 16), const Center(child: Text('Reading the file…'))],
          _Step.plan => _planView(context),
          _Step.importing => _importing(context),
          _Step.done => _doneView(context),
        }),
      ),
    );
  }

  List<Widget> _start(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return [
      Text('Bring your Anki cards in', style: t.headlineSmall),
      const SizedBox(height: Sp.s),
      Text('Choose a file exported from Anki. The app reads it on your phone only; nothing is sent anywhere.', style: t.bodyMedium),
      const SizedBox(height: Sp.l),
      SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Which file', style: t.titleSmall),
          const SizedBox(height: Sp.s),
          Text('1. A deck package (.apkg): in Anki choose File > Export, format "Anki Deck Package", and tick "Support older Anki versions". Pictures come across.', style: t.bodyMedium),
          const SizedBox(height: Sp.s),
          Text('2. Plain text (.txt) or a spreadsheet file (.csv): question in the first column, answer in the second. Cards only.', style: t.bodyMedium),
        ]),
      ),
      const SizedBox(height: Sp.m),
      SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What to expect', style: t.titleSmall),
          const SizedBox(height: Sp.s),
          Text('• Every card arrives as new: Anki\'s review history and due dates are not brought over, so the app starts learning each card afresh.', style: t.bodyMedium),
          const SizedBox(height: 4),
          Text('• Each top-level deck becomes a subject (you can rename it); sub-decks and tags become tags.', style: t.bodyMedium),
          const SizedBox(height: 4),
          Text('• Basic and cloze cards come across, with bold, italic, lists and maths. Audio and image-occlusion cards are left out. Importing the same file twice adds nothing.', style: t.bodyMedium),
        ]),
      ),
      if (_error != null) ...[
        const SizedBox(height: Sp.m),
        Semantics(liveRegion: true, child: Text(_error!, style: t.bodyMedium?.copyWith(color: AppColors.of(context).danger))),
      ],
      const SizedBox(height: Sp.l),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        icon: const Icon(Icons.file_open_outlined),
        onPressed: _choose,
        label: const Text('Choose a file'),
      ),
    ];
  }

  List<Widget> _planView(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final plan = _plan!;
    final chosen = plan.subjects.where((s) => s.selected).fold<int>(0, (a, s) => a + s.count);
    final c = AppColors.of(context);
    return [
      Text('${plan.notes} notes found', style: t.headlineSmall),
      const SizedBox(height: 4),
      Text('${plan.importable} can be imported${plan.skippedTotal > 0 ? '; ${plan.skippedTotal} left out (${_skipSummary(plan)})' : ''}.', style: t.bodyMedium),
      if (plan.sounds > 0) Text('${plan.sounds} audio clip${plan.sounds == 1 ? '' : 's'} will be dropped.', style: t.bodySmall),
      if (plan.pictureNames > 0)
        Text(_read!.hasPictures ? '${plan.pictureNames} card${plan.pictureNames == 1 ? '' : 's'} with a picture (the first picture is kept).' : 'Pictures are not in this file, so cards come across without them.', style: t.bodySmall),
      if (_error != null) ...[
        const SizedBox(height: Sp.s),
        Semantics(liveRegion: true, child: Text(_error!, style: t.bodyMedium?.copyWith(color: c.danger))),
      ],
      const SectionTitle('Subjects'),
      for (final s in plan.subjects)
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.s),
          child: SoftCard(
            padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
            child: Row(children: [
              Checkbox(
                value: s.selected,
                semanticLabel: 'Import ${s.subject}',
                onChanged: (v) => setState(() => s.selected = v ?? false),
              ),
              Expanded(
                child: TextField(
                  controller: _names[s],
                  enabled: s.selected,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(labelText: 'Subject name', helperText: '${s.count} card${s.count == 1 ? '' : 's'}', isDense: true),
                ),
              ),
            ]),
          ),
        ),
      const SizedBox(height: Sp.l),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: chosen == 0 ? null : _import,
        child: Text('Import $chosen cards'),
      ),
      const SizedBox(height: Sp.s),
      TextButton(onPressed: () { _cleanup(); setState(() { _plan = null; _step = _Step.start; _error = null; }); }, child: const Text('Choose another file')),
      const SizedBox(height: Sp.s),
      Text('New cards are introduced a few a day (your daily limit), so a big deck does not arrive all at once.', style: t.bodySmall?.copyWith(color: c.inkSoft)),
    ];
  }

  List<Widget> _importing(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return [
      const SizedBox(height: 60),
      Semantics(
        liveRegion: true,
        label: 'Importing: $_done of $_total cards',
        child: Column(children: [
          LinearProgressIndicator(value: _total == 0 ? null : _done / _total, minHeight: 8),
          const SizedBox(height: Sp.m),
          Text('Adding cards: $_done of $_total', style: t.titleSmall),
        ]),
      ),
      const SizedBox(height: Sp.s),
      Center(child: Text('Please keep the app open.', style: t.bodySmall)),
    ];
  }

  List<Widget> _doneView(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = _result!;
    final first = r.subjects.entries.isEmpty ? null : r.subjects.entries.first;
    return [
      const SizedBox(height: Sp.l),
      Icon(Icons.check_circle_outline, size: 56, color: AppColors.of(context).good),
      const SizedBox(height: Sp.m),
      Semantics(liveRegion: true, child: Text(r.notes == 0 ? 'Nothing new to add' : '${r.notes} notes added', style: t.headlineSmall, textAlign: TextAlign.center)),
      const SizedBox(height: Sp.s),
      Text(
        '${r.cards} card${r.cards == 1 ? '' : 's'} in ${r.subjects.length} subject${r.subjects.length == 1 ? '' : 's'}'
        '${r.duplicates > 0 ? '. ${r.duplicates} already in the app or repeated in the file, skipped' : ''}'
        '${r.pictures > 0 ? '. ${r.pictures} picture${r.pictures == 1 ? '' : 's'} kept' : ''}'
        '${r.picturesDropped > 0 ? '. ${r.picturesDropped} picture${r.picturesDropped == 1 ? '' : 's'} left out (too large or not a picture the app can show)' : ''}.',
        textAlign: TextAlign.center,
        style: t.bodyMedium,
      ),
      const SizedBox(height: Sp.s),
      Text('They are new cards: they will appear in your daily reviews as you go.', textAlign: TextAlign.center, style: t.bodySmall),
      const SizedBox(height: Sp.l),
      if (first != null)
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => TopicsScreen(domainId: first.value))),
          child: Text('Open ${first.key}'),
        ),
      TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Done')),
    ];
  }
}
