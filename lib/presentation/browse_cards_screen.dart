import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/card_markup.dart' show plainFromMarkup;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/card_edit_service.dart';
import 'edit_card_screen.dart';
import 'theme/tokens.dart';
import 'widgets/soft_card.dart';

/// Search every card you have and tap one to edit or delete it.
class BrowseCardsScreen extends ConsumerStatefulWidget {
  const BrowseCardsScreen({super.key});
  @override
  ConsumerState<BrowseCardsScreen> createState() => _BrowseCardsScreenState();
}

class _BrowseCardsScreenState extends ConsumerState<BrowseCardsScreen> {
  static const _page = 50;
  final _q = TextEditingController();
  Timer? _debounce;
  List<NoteRow> _rows = [];
  bool _loading = true, _more = false, _markedOnly = false, _pausedOnly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _run({bool append = false}) async {
    try {
      final rows = await ref
          .read(cardEditServiceProvider)
          .search(query: _q.text, markedOnly: _markedOnly, pausedOnly: _pausedOnly, limit: _page, offset: append ? _rows.length : 0);
      if (!mounted) return;
      setState(() {
        _rows = append ? [..._rows, ...rows] : rows;
        _more = rows.length == _page;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Your cards')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _q,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(labelText: 'Search questions and answers', prefixIcon: Icon(Icons.search)),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), _run);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 8, children: [
                FilterChip(
                  avatar: const Icon(Icons.bookmark_outline, size: 18),
                  label: const Text('Marked only'),
                  selected: _markedOnly,
                  onSelected: (v) {
                    setState(() => _markedOnly = v);
                    _run();
                  },
                ),
                FilterChip(
                  avatar: const Icon(Icons.pause_circle_outline, size: 18),
                  label: const Text('Paused only'),
                  selected: _pausedOnly,
                  onSelected: (v) {
                    setState(() => _pausedOnly = v);
                    _run();
                  },
                ),
              ]),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Could not load: $_error'))
                    : _rows.isEmpty
                        ? Center(child: Text(_pausedOnly && _q.text.isEmpty ? 'No paused cards.' : (_markedOnly && _q.text.isEmpty ? 'No marked cards. Mark one while reviewing.' : (_q.text.isEmpty ? 'No cards yet.' : 'No card matches that.'))))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _rows.length + (_more ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == _rows.length) {
                                return TextButton(onPressed: () => _run(append: true), child: const Text('Show more'));
                              }
                              final r = _rows[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: Sp.s),
                                child: SoftCard(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  onTap: () async {
                                    final o = await Navigator.of(context).push<EditOutcome>(MaterialPageRoute(
                                        builder: (_) => EditCardScreen(noteId: r.noteId)));
                                    if (o != null) _run();
                                  },
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      if (r.marked) ...[
                                        Icon(Icons.bookmark, size: 18, color: AppColors.of(context).accent, semanticLabel: 'Marked'),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(child: Text(plainFromMarkup(r.title), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall)),
                                    ]),
                                    const SizedBox(height: 2),
                                    Row(children: [
                                      Expanded(
                                        child: Text('${r.domainName} · ${r.type == 'cloze' ? 'fill in the gap' : 'question and answer'}${r.paused ? ' · Paused' : ''}',
                                            style: t.bodySmall),
                                      ),
                                      if (r.paused)
                                        TextButton(
                                          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                                          onPressed: () async {
                                            await ref.read(cardEditServiceProvider).bringBack(r.noteId);
                                            _run();
                                          },
                                          child: const Text('Bring back'),
                                        ),
                                    ]),
                                  ]),
                                ),
                              );
                            },
                          ),
          ),
        ]),
      ),
    );
  }
}
