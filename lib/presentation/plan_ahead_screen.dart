import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/plan_service.dart';
import 'retire_screen.dart';
import 'subjects_screen.dart';
import 'theme/tokens.dart';
import 'widgets/soft_card.dart';

String minutesText(double m) => m < 60 ? '${m.round()} min' : '${(m / 60).toStringAsFixed(1)} h';

/// "Looking ahead": what your library will cost in reviews over the coming years, what-if
/// sliders for new cards a day, and the levers that bring it down.
class PlanAheadScreen extends ConsumerStatefulWidget {
  const PlanAheadScreen({super.key});
  @override
  ConsumerState<PlanAheadScreen> createState() => _PlanAheadScreenState();
}

class _PlanAheadScreenState extends ConsumerState<PlanAheadScreen> {
  PlanResult? _result;
  double? _pace, _chosen;
  bool _busy = true;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _run(null);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _run(double? n) async {
    setState(() { _busy = true; _error = null; });
    try {
      final svc = ref.read(planServiceProvider);
      _pace ??= await svc.currentPace();
      final r = await svc.plan(newPerDay: n ?? _pace);
      if (mounted) setState(() { _result = r; _chosen ??= r.newPerDay; _busy = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Looking ahead')),
      body: SafeArea(
        child: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Could not work it out: $_error')))
            : r == null
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Working out your next years…'),
                  ]))
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Text('How much review time your library will need, if you keep adding cards at the pace below. It is an estimate: '
                        'it simulates your cards with the same memory model the app schedules with.',
                        style: t.bodyMedium),
                    const SizedBox(height: Sp.m),
                    SoftCard(
                      color: r.advice.overBudgetInDays == null ? c.goodTint : c.warnTint,
                      borderColor: Colors.transparent,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.advice.title, style: t.titleMedium),
                        const SizedBox(height: 6),
                        for (final line in r.advice.reasons) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(line, style: t.bodyMedium)),
                      ]),
                    ),
                    const SizedBox(height: Sp.l),
                    Text('New cards a day: ${(_chosen ?? r.newPerDay).toStringAsFixed((_chosen ?? r.newPerDay) < 10 ? 1 : 0)}', style: t.titleSmall),
                    Slider(
                      value: (_chosen ?? r.newPerDay).clamp(0, 80),
                      min: 0,
                      max: 80,
                      divisions: 80,
                      label: (_chosen ?? r.newPerDay).round().toString(),
                      onChanged: (v) {
                        setState(() => _chosen = v);
                        _debounce?.cancel();
                        _debounce = Timer(const Duration(milliseconds: 500), () => _run(v));
                      },
                    ),
                    Text('Your recent pace is about ${(_pace ?? 0).toStringAsFixed(1)} a day. Slide to see what-ifs.', style: t.bodySmall),
                    const SizedBox(height: Sp.m),
                    Stack(children: [
                      Opacity(
                        opacity: _busy ? 0.4 : 1,
                        child: SoftCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(children: [
                            for (final row in r.rows)
                              Semantics(
                                label: '${row.label}: about ${row.reviewsPerDay.round()} reviews a day, ${minutesText(row.minutesPerDay)}',
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(children: [
                                    Expanded(child: Text(row.label, style: t.bodyLarge)),
                                    Text('${row.reviewsPerDay.round()} reviews', style: t.bodyMedium),
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 64,
                                      child: Text(minutesText(row.minutesPerDay),
                                          textAlign: TextAlign.end,
                                          style: t.titleSmall?.copyWith(color: row.minutesPerDay > r.budgetMinutes ? c.danger : c.ink)),
                                    ),
                                  ]),
                                ),
                              ),
                          ]),
                        ),
                      ),
                      if (_busy) const Positioned.fill(child: Center(child: CircularProgressIndicator())),
                    ]),
                    const SizedBox(height: 4),
                    Text('Your daily time budget is ${r.budgetMinutes.round()} minutes (Settings). Each review is counted at about ${r.secondsPerReview.round()} seconds, from your own answers.',
                        style: t.bodySmall),
                    const SizedBox(height: Sp.l),
                    Text('Ways to bring it down', style: t.titleLarge),
                    const SizedBox(height: Sp.s),
                    _lever(context, Icons.speed, 'Add fewer new cards a day', 'The slider above shows the effect straight away.', null),
                    _lever(context, Icons.archive_outlined, 'Retire mastered cards', 'Stop reviewing cards you have known for years. Reversible.',
                        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RetireScreen()))),
                    _lever(context, Icons.tune, 'Lower the target recall for some subjects',
                        'Fewer reviews for subjects where an occasional miss is fine.',
                        () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SubjectsScreen()))),
                  ]),
      ),
    );
  }

  Widget _lever(BuildContext context, IconData icon, String title, String sub, VoidCallback? onTap) {
    final t = Theme.of(context).textTheme;
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Icon(icon, color: c.accent),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: t.titleSmall), Text(sub, style: t.bodySmall)])),
          if (onTap != null) Icon(Icons.chevron_right, color: c.inkSoft),
        ]),
      ),
    );
  }
}
