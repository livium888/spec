import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/db/database.dart' show Domain;
import '../domain/transcript.dart';
import 'course_screen.dart';

/// Library > Courses > Add a lecture (D67). The learner pastes (or shares) a lecture's transcript or caption file; the app
/// cleans it, shows what it found, and keeps it under a subject. Nothing is fetched: a video address typed here is only a
/// note for the learner. The text is untrusted: it is shown and stored, never run, and only ever placed inside prompts
/// between transcript tags.
class AddLectureScreen extends ConsumerStatefulWidget {
  const AddLectureScreen({super.key, this.domainId, this.initialText});

  /// Preselect this subject (adding the next lecture of a course).
  final int? domainId;

  /// Text that arrived through the share sheet or the paste router: shown as a preview at once, saved only on the button.
  final String? initialText;
  @override
  ConsumerState<AddLectureScreen> createState() => _AddLectureScreenState();
}

class _AddLectureScreenState extends ConsumerState<AddLectureScreen> {
  List<Domain> _domains = [];
  Domain? _domain;
  final _newSubject = TextEditingController();
  final _title = TextEditingController();
  final _note = TextEditingController();
  String _clean = '';
  bool _truncated = false;
  bool _busy = false;
  String? _message;
  int _next = 1;

  @override
  void initState() {
    super.initState();
    _loadDomains();
    final t = widget.initialText;
    if (t != null) _take(t);
  }

  @override
  void dispose() {
    _newSubject.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadDomains() async {
    final db = ref.read(dbProvider);
    final ds = await (db.select(db.domains)..where((d) => d.active.equals(true))).get();
    if (!mounted) return;
    Domain? pick;
    for (final d in ds) {
      if (d.id == widget.domainId) pick = d;
    }
    setState(() {
      _domains = ds;
      _domain = pick ?? _domain ?? (ds.isEmpty ? null : ds.first);
    });
    await _numberFor();
  }

  Future<void> _numberFor() async {
    final d = _domain;
    final n = d == null || _newSubject.text.trim().isNotEmpty ? 1 : await ref.read(sourceServiceProvider).nextNumber(d.id);
    if (mounted) setState(() => _next = n);
  }

  void _take(String raw) {
    final clean = cleanTranscript(raw);
    setState(() {
      _clean = clean;
      _truncated = raw.trim().length > kMaxTranscriptChars;
      _message = clean.isEmpty ? 'There is no readable text in that.' : null;
    });
  }

  /// The clipboard is read ONLY on this explicit tap.
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      setState(() => _message = 'The clipboard is empty. Copy the transcript first.');
      return;
    }
    _take(text);
  }

  Future<void> _save() async {
    final fresh = _newSubject.text.trim();
    final svc = ref.read(sourceServiceProvider);
    setState(() => _busy = true);
    try {
      final int domainId;
      if (fresh.isNotEmpty) {
        domainId = await svc.ensureDomain(fresh);
      } else if (_domain != null) {
        domainId = _domain!.id;
      } else {
        setState(() => _message = 'Pick a subject, or type a name for a new one.');
        return;
      }
      if (_title.text.trim().isEmpty) {
        setState(() => _message = 'Give the lecture a title, for example "Lecture 3: Asset security".');
        return;
      }
      final id = await svc.add(domainId: domainId, title: _title.text, note: _note.text, text: _clean);
      if (id == null) {
        setState(() => _message = 'Nothing was saved: the text is empty.');
        return;
      }
      ref.read(refreshProvider.notifier).bump();
      if (!mounted) return;
      if (widget.domainId != null) {
        Navigator.of(context).pop(); // came from the course: back to it
      } else {
        await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => CourseScreen(domainId: domainId)));
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Nothing was saved: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final words = wordCount(_clean);
    final parts = words == 0 ? 0 : splitTranscript(_clean).length;
    final minutes = (words / 150).ceil(); // spoken pace
    return Scaffold(
      appBar: AppBar(title: const Text('Add a lecture')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Paste the transcript of one lecture (plain text, or a .srt / .vtt caption file opened as text). '
              'The app keeps it on this phone, builds prompts from it for your own AI app, and uses it to check the quotes on the cards.',
              style: t.bodyLarge),
          const SizedBox(height: 16),
          if (_domains.isNotEmpty && _newSubject.text.trim().isEmpty)
            DropdownButtonFormField<Domain>(
              initialValue: _domain,
              decoration: const InputDecoration(labelText: 'Subject (the course)'),
              items: [for (final d in _domains) DropdownMenuItem(value: d, child: Text(d.name))],
              onChanged: (d) {
                setState(() => _domain = d);
                _numberFor();
              },
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _newSubject,
            decoration: InputDecoration(
              labelText: _domains.isEmpty ? 'Name of the course' : 'Or a new course',
              helperText: _domains.isEmpty ? null : 'Leave empty to use the subject above.',
            ),
            onChanged: (_) {
              setState(() {});
              _numberFor();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            maxLength: 120,
            decoration: InputDecoration(labelText: 'Lecture title', helperText: 'It will be lecture $_next of this course.'),
          ),
          TextField(
            controller: _note,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Where it is from (optional)',
              helperText: 'A video address or a note for yourself. The app never opens it.',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.content_paste),
            label: Text(_clean.isEmpty ? 'Paste the transcript' : 'Paste a different transcript'),
            onPressed: _busy ? null : _paste,
          ),
          if (_clean.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(
                    liveRegion: true,
                    child: Text('$words words · about $minutes min spoken · '
                        '${parts == 1 ? 'one part' : '$parts parts'} for your AI app', style: t.titleSmall),
                  ),
                  const SizedBox(height: 8),
                  Text(_clean.length > 300 ? '${_clean.substring(0, 300).trimRight()}…' : _clean, style: t.bodyMedium),
                  if (_truncated) ...[
                    const SizedBox(height: 8),
                    Text('The text was longer than $kMaxTranscriptChars characters: the rest was left out. Add the end as another lecture.',
                        style: t.bodySmall),
                  ],
                ]),
              ),
            ),
          ],
          if (_message != null)
            Semantics(
              liveRegion: true,
              child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: _busy || _clean.isEmpty ? null : _save,
            child: const Text('Save the lecture'),
          ),
        ]),
      ),
    );
  }
}
