import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/media_service.dart';
import '../data/picture_finder.dart';
import '../domain/commons.dart';
import '../domain/picture_sources.dart';

/// A picture the learner chose, with who made it and under which licence. No description is
/// supplied on purpose: a Commons file name usually names the work, which would give away a card
/// that asks "what is this?" to anyone using a screen reader. The learner writes the description.
class FoundPicture {
  const FoundPicture({required this.bytes, required this.credit});
  final Uint8List bytes;
  final String credit;
}

enum _Phase { searching, results, empty, error, fetching, preview }

/// Search Wikimedia Commons, look at the pictures, and keep one. Nothing is saved until the learner
/// taps "Use this picture" (a wrong picture is worse than none: nothing here can check it is the
/// right one, only a person can). Pops with a [FoundPicture], or null.
class FindPictureScreen extends ConsumerStatefulWidget {
  const FindPictureScreen({super.key, this.initialQuery = ''});
  final String initialQuery;
  @override
  ConsumerState<FindPictureScreen> createState() => _FindPictureScreenState();
}

class _FindPictureScreenState extends ConsumerState<FindPictureScreen> {
  late final TextEditingController _q = TextEditingController(text: widget.initialQuery);
  late final PictureFinder _finder = ref.read(pictureFinderProvider);
  _Phase _phase = _Phase.empty;
  bool _started = false;
  String _message = '';
  List<PictureCandidate> _results = const [];
  Map<String, String> _failures = const {}; // source name -> why it did not answer
  final Set<String> _sources = {kSourceCommons, kSourceOpenverse, kSourceMet, kSourceArtic};
  final _thumbs = <String, Future<Uint8List>>{};
  PictureCandidate? _chosen;
  Uint8List? _chosenBytes;
  int _searchSerial = 0; // a slow answer to an old search never replaces a newer one

  @override
  void initState() {
    super.initState();
    if (cleanImageQuery(widget.initialQuery) != null) {
      _started = true;
      _phase = _Phase.searching;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = cleanImageQuery(_q.text);
    if (query == null) {
      setState(() {
        _started = true;
        _phase = _Phase.error;
        _message = 'Type a few words that describe the picture, not a web address.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    final serial = ++_searchSerial;
    setState(() {
      _started = true;
      _phase = _Phase.searching;
    });
    try {
      final r = await _finder.search(query, sources: Set.of(_sources));
      if (!mounted || serial != _searchSerial) return;
      for (final f in r.failures.entries) {
        _log('Find a picture: ${f.key} failed: ${f.value}', null, where: 'find_picture');
      }
      setState(() {
        _results = r.candidates;
        _failures = r.failures;
        _thumbs.clear();
        _phase = r.candidates.isEmpty ? (r.failures.isNotEmpty ? _Phase.error : _Phase.empty) : _Phase.results;
        if (_phase == _Phase.error) {
          _message = r.failures.entries.map((e) => '${e.key}: ${e.value}').join('\n');
        }
      });
    } on PictureFinderException catch (e) {
      _log('Find a picture: search failed: ${e.message}', null, where: 'find_picture');
      if (mounted && serial == _searchSerial) setState(() { _phase = _Phase.error; _message = e.message; });
    } catch (e) {
      if (mounted && serial == _searchSerial) {
        setState(() { _phase = _Phase.error; _message = 'The search failed. Check your connection and try again.'; });
      }
    }
  }

  /// Kept in the local error log so "Copy report" (Settings > Diagnostics) carries the reason.
  /// The log must never be the thing that breaks the screen.
  void _log(Object error, StackTrace? st, {String where = ''}) {
    try {
      ref.read(errorLogProvider).record(error, st, where: where);
    } catch (_) {}
  }

  Future<Uint8List> _loadThumb(PictureCandidate c) async {
    try {
      return await _finder.download(c.thumbUrl, maxBytes: 800000);
    } catch (e, st) {
      // Kept in the local error log so "Copy report" (Settings > Diagnostics) carries the reason.
      _log('Find a picture: thumbnail failed: $e (${Uri.tryParse(c.thumbUrl)?.host})', st, where: 'find_picture');
      rethrow;
    }
  }

  Future<void> _choose(PictureCandidate c) async {
    setState(() => _phase = _Phase.fetching);
    try {
      final forCard = await _finder.forCard(c);
      if (forCard == null) throw PictureFinderException('That picture is not available in a size the app can keep.');
      final bytes = await _finder.download(forCard.thumbUrl, maxBytes: kMaxImageBytes);
      if (!MediaService.looksLikeImage(bytes)) throw PictureFinderException('That file is not a picture the app can show.');
      if (!mounted) return;
      setState(() {
        _chosen = forCard;
        _chosenBytes = bytes;
        _phase = _Phase.preview;
      });
    } on PictureFinderException catch (e) {
      _log('Find a picture: download failed: ${e.message}', null, where: 'find_picture');
      if (mounted) setState(() { _phase = _Phase.error; _message = e.message; });
    } catch (e, st) {
      _log(e, st, where: 'find_picture');
      if (mounted) setState(() { _phase = _Phase.error; _message = 'Could not get that picture. Try another one.'; });
    }
  }

  void _use() {
    final c = _chosen!;
    Navigator.of(context).pop(FoundPicture(bytes: _chosenBytes!, credit: c.credit));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopScope(
      canPop: _phase != _Phase.preview,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _phase = _Phase.results);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Find a picture')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_phase != _Phase.preview) ...[
                TextField(
                  controller: _q,
                  maxLength: kMaxImageQueryChars,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: 'What should the picture show?',
                    helperText: 'A few plain words, like "Hokusai Great Wave".',
                    counterText: '',
                    suffixIcon: IconButton(tooltip: 'Search', icon: const Icon(Icons.search), onPressed: _search),
                  ),
                ),
                Semantics(
                  container: true,
                  label: 'Picture sources',
                  child: Wrap(spacing: 8, runSpacing: 0, children: [
                    for (final e in kSourceLabels.entries)
                      FilterChip(
                        label: Text(e.value == 'Art Institute of Chicago' ? 'Art Institute' : e.value),
                        selected: _sources.contains(e.key),
                        onSelected: (on) => setState(() {
                          // at least one source stays on
                          if (on) {
                            _sources.add(e.key);
                          } else if (_sources.length > 1) {
                            _sources.remove(e.key);
                          }
                        }),
                      ),
                  ]),
                ),
                const SizedBox(height: 4),
              ],
              if (_phase == _Phase.results && _failures.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                        'Not available right now: ${_failures.entries.map((e) => '${e.key} (${e.value})').join('; ')}',
                        style: t.bodySmall),
                  ),
                ),
              Expanded(child: _body(context, t)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    'Pictures come from Wikimedia Commons, Openverse, the Met and the Art Institute of Chicago. Only your search words go online. The picture you keep is saved on your phone, with its credit.',
                    style: t.bodySmall),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, TextTheme t) {
    switch (_phase) {
      case _Phase.searching:
        return const _Busy('Searching Wikimedia Commons…');
      case _Phase.fetching:
        return const _Busy('Getting the picture…');
      case _Phase.empty:
        return Center(
          child: Text(
              _started
                  ? 'No pictures found. Try fewer or more general words, or the name of the work or place.'
                  : 'Type what the picture should show, then search.',
              textAlign: TextAlign.center,
              style: t.bodyLarge),
        );
      case _Phase.error:
        return Semantics(
          liveRegion: true,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_message, textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _search, child: const Text('Try again')),
            ]),
          ),
        );
      case _Phase.preview:
        return _preview(context, t);
      case _Phase.results:
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.88),
          itemCount: _results.length,
          itemBuilder: (_, i) => _tile(context, _results[i]),
        );
    }
  }

  Widget _tile(BuildContext context, PictureCandidate c) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fut = _thumbs.putIfAbsent(c.thumbUrl, () => _loadThumb(c));
    return Semantics(
      button: true,
      label: 'Picture: ${c.label}, from ${c.sourceLabel}',
      hint: 'Shows a larger preview',
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _choose(c),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: FutureBuilder<Uint8List>(
                future: fut,
                builder: (_, snap) {
                  if (snap.hasData) return Image.memory(snap.data!, fit: BoxFit.cover, gaplessPlayback: true);
                  if (snap.hasError) {
                    // Say why, so a failure can be reported and fixed (it is also in the phone-check report).
                    final why = snap.error is PictureFinderException ? (snap.error as PictureFinderException).message : '${snap.error}';
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.broken_image_outlined),
                        const SizedBox(height: 4),
                        Text('No preview: $why', style: t.labelSmall, maxLines: 4, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                      ]),
                    );
                  }
                  return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(c.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                Text(c.sourceLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(color: scheme.primary)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _preview(BuildContext context, TextTheme t) {
    final c = _chosen!;
    return ListView(children: [
      Semantics(
        image: true,
        label: c.label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: Image.memory(_chosenBytes!, fit: BoxFit.contain, excludeFromSemantics: true),
        ),
      ),
      const SizedBox(height: 12),
      Text(c.label, style: t.titleMedium),
      const SizedBox(height: 4),
      Text(c.credit, style: t.bodyMedium),
      if (c.description.isNotEmpty) ...[const SizedBox(height: 4), Text(c.description, style: t.bodySmall)],
      const SizedBox(height: 16),
      Text('Is this the right picture for your card?', style: t.labelLarge),
      const SizedBox(height: 8),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: _use,
        child: const Text('Use this picture'),
      ),
      TextButton(onPressed: () => setState(() => _phase = _Phase.results), child: const Text('Back to results')),
    ]);
  }
}

class _Busy extends StatelessWidget {
  const _Busy(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: text,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(text),
          ]),
        ),
      );
}
