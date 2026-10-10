import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/optimizer_service.dart';
import '../domain/fsrs_trainer.dart';
import '../domain/optimizer_advice.dart' show kMinUsableReviews;
import 'theme/tokens.dart';
import 'widgets/soft_card.dart';

/// Fit the scheduler's memory model to the learner's own review history, and say when to do it.
class MemoryModelScreen extends ConsumerStatefulWidget {
  const MemoryModelScreen({super.key});
  @override
  ConsumerState<MemoryModelScreen> createState() => _MemoryModelScreenState();
}

class _MemoryModelScreenState extends ConsumerState<MemoryModelScreen> {
  OptimizerStatus? _status;
  TrainResult? _result;
  String? _error, _message;
  bool _training = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(optimizerServiceProvider).status();
      if (mounted) setState(() { _status = s; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _fit() async {
    setState(() { _training = true; _result = null; _message = null; });
    final sw = Stopwatch()..start();
    try {
      final r = await ref.read(optimizerServiceProvider).optimise();
      await ref.read(settingsRepoProvider).set('optimizer_last_fit_ms', '${sw.elapsedMilliseconds}');
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not fit: $e');
    } finally {
      if (mounted) setState(() => _training = false);
    }
  }

  Future<void> _apply() async {
    final svc = ref.read(optimizerServiceProvider);
    await svc.apply(_result!);
    ref.read(refreshProvider.notifier).bump();
    setState(() { _result = null; _message = 'Done. Your new reviews use the personal weights from now on.'; });
    await _load();
  }

  Future<void> _keep() async {
    await ref.read(optimizerServiceProvider).keep(_result!);
    ref.read(refreshProvider.notifier).bump();
    setState(() { _result = null; _message = 'Kept your current settings.'; });
    await _load();
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go back to the built-in settings?'),
        content: const Text('New reviews will use the built-in weights again. Your history and existing cards are not changed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Go back')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(optimizerServiceProvider).resetToDefaults();
    ref.read(refreshProvider.notifier).bump();
    setState(() => _message = 'Back on the built-in settings.');
    await _load();
  }

  String _pct(double v) => '${(v * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    final s = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('Tune my scheduling')),
      body: SafeArea(
        child: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Could not load: $_error')))
            : s == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Text(
                        'The scheduler predicts how likely you are to remember each card. Its 21 settings start as averages from many learners. '
                        'Fitting them to your own history makes the review times fit your memory.',
                        style: t.bodyMedium),
                    const SizedBox(height: Sp.m),
                    SoftCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.personalised ? 'Using: your personal settings' : 'Using: the built-in settings', style: t.titleMedium),
                        const SizedBox(height: 4),
                        Text('${s.usableReviews} usable reviews so far (answers that came a day or more after the previous one).',
                            style: t.bodySmall),
                        if (s.sample > 0 &&
            s.predicted != null &&
            s.actual != null &&
            !s.advice.reasons.any((r) => r.startsWith('Across'))) ...[
                          const SizedBox(height: 4),
                          Text(
                              'Across ${s.sample} reviews the model expected you to remember ${_pct(s.predicted!)}; you remembered ${_pct(s.actual!)}.',
                              style: t.bodySmall),
                        ],
                      ]),
                    ),
                    const SizedBox(height: Sp.m),
                    SoftCard(
                      color: s.advice.ready ? c.accentTint : null,
                      borderColor: s.advice.ready ? Colors.transparent : null,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(s.advice.ready ? Icons.check_circle_outline : Icons.schedule, color: c.accent),
                          const SizedBox(width: 8),
                          Text(s.advice.ready ? 'When to fit: now' : 'When to fit', style: t.labelLarge),
                        ]),
                        const SizedBox(height: 6),
                        Text(s.advice.title, style: t.titleMedium),
                        const SizedBox(height: 6),
                        for (final r in s.advice.reasons)
                          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(r, style: t.bodyMedium)),
                      ]),
                    ),
                    const SizedBox(height: Sp.m),
                    if (_training)
                      SoftCard(
                        child: Row(children: [
                          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Fitting to your reviews. This can take a minute or two; keep the app open.', style: t.bodyMedium)),
                        ]),
                      )
                    else if (_result != null)
                      _resultCard(context, _result!)
                    else ...[
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        onPressed: s.usableReviews >= kMinUsableReviews ? _fit : null,
                        child: Text(s.advice.ready ? 'Fit to my memory' : 'Fit anyway'),
                      ),
                      if (s.usableReviews < kMinUsableReviews)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('Available from $kMinUsableReviews usable reviews.', style: t.bodySmall),
                        ),
                    ],
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Semantics(liveRegion: true, child: Text(_message!, style: t.bodyLarge)),
                      ),
                    if (s.personalised && !_training && _result == null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(onPressed: _reset, child: const Text('Go back to the built-in settings')),
                      ),
                    const SizedBox(height: Sp.l),
                    Text(
                        'Good to know: new weights apply to reviews from now on. Cards you already have keep their schedule and adjust as you review them. '
                        'Your history is never changed, and you can always go back. The fit only runs on this phone.',
                        style: t.bodySmall),
                  ]),
      ),
    );
  }

  Widget _resultCard(BuildContext context, TrainResult r) {
    final t = Theme.of(context).textTheme;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r.improved ? 'A better fit was found' : 'Nothing to change', style: t.titleMedium),
        const SizedBox(height: 6),
        Text(r.reason, style: t.bodyMedium),
        const SizedBox(height: 6),
        Text(
            'Checked on ${r.holdoutReviews} reviews of cards the fit never saw. '
            'Average miss in predicted recall: ${(r.holdoutRmseBefore * 100).toStringAsFixed(1)} points now'
            '${r.improved ? ', ${(r.holdoutRmseAfter * 100).toStringAsFixed(1)} with the new weights' : ''}.',
            style: t.bodySmall),
        const SizedBox(height: 12),
        if (r.improved) ...[
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _apply,
            child: const Text('Use the new weights'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _keep,
            child: const Text('Keep my current settings'),
          ),
        ] else
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _keep,
            child: const Text('OK'),
          ),
      ]),
    );
  }
}
