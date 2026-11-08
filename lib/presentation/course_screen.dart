import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/db/database.dart' show Domain, Source;
import '../data/settings_repo.dart';
import '../domain/course_prompts.dart';
import '../domain/transcript.dart';
import 'add_lecture_screen.dart';

/// Library > Courses (D67): the subjects that have lecture transcripts.
class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});
  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  List<({Domain domain, int lectures})>? _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(dbProvider);
    final svc = ref.read(sourceServiceProvider);
    final out = <({Domain domain, int lectures})>[];
    for (final d in await (db.select(db.domains)..where((d) => d.active.equals(true))).get()) {
      final n = await svc.count(d.id);
      if (n > 0) out.add((domain: d, lectures: n));
    }
    if (mounted) setState(() => _rows = out);
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    ref.read(refreshProvider.notifier).bump();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('Courses from lectures')),
      body: SafeArea(
        child: rows == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                Text('Turn a lecture series (a university course on video, for example) into a course here. You paste each lecture\'s transcript; '
                    'the app writes prompts for your own AI app and files what comes back: an outline, a short reading for each topic, and flashcards.',
                    style: t.bodyLarge),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  icon: const Icon(Icons.add),
                  label: const Text('Add a lecture'),
                  onPressed: () => _go(const AddLectureScreen()),
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  Text('No courses yet. Add the first lecture to start one.', style: t.bodyMedium)
                else
                  for (final r in rows)
                    Card(
                      child: ListTile(
                        minVerticalPadding: 12,
                        leading: const Icon(Icons.school_outlined),
                        title: Text(r.domain.name),
                        subtitle: Text('${r.lectures} lecture${r.lectures == 1 ? '' : 's'}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _go(CourseScreen(domainId: r.domain.id)),
                      ),
                    ),
              ]),
      ),
    );
  }
}

class _Lecture {
  const _Lecture(this.source, this.parts);
  final Source source;
  final List<String> parts;
  int get words => wordCount(source.body);
}

/// One course: its lectures, and for each the prompts to copy or share (D67). Two trips to the AI per lecture: a primer
/// (the reading before the cards), then the cards. The learner pastes or shares each answer back; the import preview
/// shows it before anything is saved.
class CourseScreen extends ConsumerStatefulWidget {
  const CourseScreen({super.key, required this.domainId});
  final int domainId;
  @override
  ConsumerState<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends ConsumerState<CourseScreen> {
  Domain? _domain;
  List<_Lecture>? _lectures;
  List<String> _topics = [];
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(dbProvider);
    final dom = await (db.select(db.domains)..where((d) => d.id.equals(widget.domainId))).getSingleOrNull();
    final src = await ref.read(sourceServiceProvider).forDomain(widget.domainId);
    final topics = await (db.select(db.syllabusItems)
          ..where((s) => s.domainId.equals(widget.domainId))
          ..orderBy([(s) => OrderingTerm.asc(s.position)]))
        .get();
    if (!mounted) return;
    setState(() {
      _domain = dom;
      _topics = [for (final s in topics) s.title];
      _lectures = [for (final s in src) _Lecture(s, splitTranscript(s.body))];
    });
  }

  Future<void> _send(String text, String title) async {
    try {
      await ref.read(promptSharerProvider).send(text, title: title);
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not open the share sheet ($e). Use Copy instead.');
    }
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _message = '$what copied. Paste it into your AI app.');
  }

  Future<String> _courseMap() async {
    final refs = await ref.read(sourceServiceProvider).lectureRefs(widget.domainId);
    return renderCourseMapPrompt(course: _domain!.name, lectures: refs);
  }

  Future<String> _primer(_Lecture l, int part) async {
    final profile = await ref.read(settingsRepoProvider).get(SettingsRepo.learnerProfile);
    return renderPrimerPrompt(
      course: _domain!.name,
      lectureNumber: l.source.number,
      lectureTitle: l.source.title,
      part: part + 1,
      parts: l.parts.length,
      transcript: l.parts[part],
      topics: _topics,
      learnerProfile: profile,
    );
  }

  Future<String> _cards(_Lecture l, int part) async {
    final words = wordCount(l.parts[part]);
    final r = await ref.read(promptServiceProvider).build(
          domainId: widget.domainId,
          n: (words ~/ 400).clamp(8, 20),
          sourceText: lectureSourceText(
              lectureNumber: l.source.number, lectureTitle: l.source.title, part: part + 1, parts: l.parts.length, transcript: l.parts[part]),
        );
    return r.text;
  }

  Future<void> _delete(_Lecture l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete lecture ${l.source.number}?'),
        content: const Text('The transcript is removed from this phone. Cards and primers already made from it stay. '
            'Their quotes can no longer be checked against it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(sourceServiceProvider).delete(l.source.id);
    await _load();
  }

  Widget _promptRow(String label, Future<String> Function() build, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
        IconButton.filledTonal(
          tooltip: 'Share $label',
          icon: const Icon(Icons.ios_share),
          onPressed: () async => _send(await build(), title),
        ),
        const SizedBox(width: 4),
        IconButton.outlined(
          tooltip: 'Copy $label',
          icon: const Icon(Icons.copy),
          onPressed: () async => _copy(await build(), label),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ls = _lectures;
    final dom = _domain;
    return Scaffold(
      appBar: AppBar(title: Text(dom?.name ?? 'Course')),
      body: SafeArea(
        child: ls == null || dom == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                Text('For each lecture: first the primer prompt, then the cards prompt. Give each to your AI app. '
                    'When it answers, tap Share on its answer and choose Daily Learning, or copy it and use Library > Paste an answer. '
                    'You see a preview before anything is saved.',
                    style: t.bodyMedium),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('1. The course outline', style: t.titleSmall),
                      Text('Once, from the lecture titles: your AI app proposes the ordered topics.', style: t.bodySmall),
                      _promptRow('Outline prompt', _courseMap, 'Outline of ${dom.name}'),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                for (final l in ls)
                  Card(
                    child: ExpansionTile(
                      shape: const Border(),
                      title: Text('Lecture ${l.source.number}: ${l.source.title}'),
                      subtitle: Text('${l.words} words · ${l.parts.length == 1 ? 'one part' : '${l.parts.length} parts'}'),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        for (var i = 0; i < l.parts.length; i++) ...[
                          if (l.parts.length > 1) Align(alignment: Alignment.centerLeft, child: Text('Part ${i + 1} of ${l.parts.length}', style: t.titleSmall)),
                          _promptRow('Primer prompt', () => _primer(l, i), 'Primer: lecture ${l.source.number}'),
                          _promptRow('Cards prompt', () => _cards(l, i), 'Cards: lecture ${l.source.number}'),
                        ],
                        if (l.source.note.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text('From: ${l.source.note}', style: t.bodySmall)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(icon: const Icon(Icons.delete_outline), label: const Text('Delete this lecture'), onPressed: () => _delete(l)),
                        ),
                      ],
                    ),
                  ),
                if (_message != null)
                  Semantics(liveRegion: true, child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!, style: t.bodyLarge))),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  icon: const Icon(Icons.add),
                  label: const Text('Add another lecture'),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AddLectureScreen(domainId: widget.domainId)));
                    _load();
                  },
                ),
              ]),
      ),
    );
  }
}
