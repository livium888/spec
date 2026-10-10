import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/retire_service.dart';
import '../domain/retire.dart';
import 'theme/tokens.dart';
import 'widgets/soft_card.dart';

/// Suggests cards that are safe to stop reviewing, and lets the learner retire them (and bring
/// them back). Nothing is deleted and nothing is retired without a tap.
class RetireScreen extends ConsumerStatefulWidget {
  const RetireScreen({super.key});
  @override
  ConsumerState<RetireScreen> createState() => _RetireScreenState();
}

class _RetireScreenState extends ConsumerState<RetireScreen> {
  int _years = 2;
  RetireSummary? _summary;
  List<RetiredCard> _retired = [];
  int _retiredCount = 0;
  String? _message, _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = ref.read(retireServiceProvider);
      final secs = await ref.read(planServiceProvider).secondsPerReview();
      final s = await svc.summary(RetireCriteria(years: _years), secondsPerReview: secs);
      final list = await svc.retired(limit: 50);
      final n = await svc.retiredCount();
      if (mounted) setState(() { _summary = s; _retired = list; _retiredCount = n; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _retire() async {
    final s = _summary!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retire ${s.cards} card${s.cards == 1 ? '' : 's'}?'),
        content: const Text('They stop appearing in your reviews. Nothing is deleted: you can bring any of them back, '
            'and they will be due again straight away if their time has passed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retire them')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final n = await ref.read(retireServiceProvider).retireMastered(RetireCriteria(years: _years));
    ref.read(refreshProvider.notifier).bump();
    setState(() { _busy = false; _message = 'Retired $n card${n == 1 ? '' : 's'}.'; });
    await _load();
  }

  Future<void> _restore(int id) async {
    await ref.read(retireServiceProvider).restore(id);
    ref.read(refreshProvider.notifier).bump();
    setState(() => _message = 'Brought back.');
    await _load();
  }

  Future<void> _restoreAll() async {
    final n = await ref.read(retireServiceProvider).restoreAll();
    ref.read(refreshProvider.notifier).bump();
    setState(() => _message = 'Brought back $n card${n == 1 ? '' : 's'}.');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = _summary;
    return Scaffold(
      appBar: AppBar(title: const Text('Retire mastered cards')),
      body: SafeArea(
        child: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Could not load: $_error')))
            : s == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Text(
                        'A card you have answered well for years comes back only every few years, but across thousands of cards that still adds up. '
                        'Retiring such cards takes them out of your reviews. Retired cards stay in your library and can come back at any time.',
                        style: t.bodyMedium),
                    const SizedBox(height: Sp.m),
                    Text('Count a card as mastered when its next review is at least', style: t.labelLarge),
                    const SizedBox(height: Sp.s),
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [for (final y in kRetireYearChoices) ButtonSegment(value: y, label: Text('$y year${y == 1 ? '' : 's'}'))],
                      selected: {_years},
                      onSelectionChanged: (v) {
                        setState(() => _years = v.first);
                        _load();
                      },
                    ),
                    const SizedBox(height: Sp.s),
                    Text('…away, after at least $kRetireMinReviews reviews and at most $kRetireMaxLapses time forgotten.', style: t.bodySmall),
                    const SizedBox(height: Sp.m),
                    SoftCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.cards == 0 ? 'No cards qualify yet' : '${s.cards} card${s.cards == 1 ? '' : 's'} qualify', style: t.titleMedium),
                        if (s.cards > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                              'Retiring them saves about ${s.reviewsSavedPerYear.round()} reviews a year '
                              '(about ${s.minutesSavedPerYear < 60 ? '${s.minutesSavedPerYear.round()} minutes' : '${(s.minutesSavedPerYear / 60).toStringAsFixed(1)} hours'} a year).',
                              style: t.bodyMedium),
                          const SizedBox(height: 4),
                          Text('Honest note: mature cards are cheap, so the saving is modest. It grows as your library does.', style: t.bodySmall),
                          const SizedBox(height: 12),
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                            onPressed: _busy ? null : _retire,
                            child: Text('Retire ${s.cards} card${s.cards == 1 ? '' : 's'}'),
                          ),
                        ],
                      ]),
                    ),
                    if (_message != null)
                      Padding(padding: const EdgeInsets.only(top: Sp.s), child: Semantics(liveRegion: true, child: Text(_message!, style: t.bodyLarge))),
                    const SizedBox(height: Sp.l),
                    Text('Retired ($_retiredCount)', style: t.titleLarge),
                    const SizedBox(height: Sp.s),
                    if (_retired.isEmpty)
                      Text('Nothing retired.', style: t.bodyMedium)
                    else ...[
                      for (final r in _retired)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Sp.s),
                          child: SoftCard(
                            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                                  Text('${r.domainName} · next review in about ${(r.stability / 365).toStringAsFixed(1)} years', style: t.bodySmall),
                                ]),
                              ),
                              TextButton(onPressed: () => _restore(r.cardId), child: const Text('Bring back')),
                            ]),
                          ),
                        ),
                      if (_retiredCount > _retired.length) Text('Showing the newest ${_retired.length}.', style: t.bodySmall),
                      TextButton(onPressed: _restoreAll, child: const Text('Bring back all retired cards')),
                    ],
                  ]),
      ),
    );
  }
}
