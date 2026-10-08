import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/learn_service.dart';
import '../domain/growth.dart';
import '../domain/learn_planner.dart';
import '../domain/study_advisor.dart';
import 'advice_card.dart';
import 'new_subject_screen.dart';
import 'prompt_result_screen.dart';
import 'starter_library_screen.dart';
import 'topics_screen.dart';

/// "Learn something new". By default ONE press picks the topic, checks whether now is
/// a good time (and how much), and goes straight to the prompt. With [showOptions] it
/// lists the alternatives instead.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key, this.showOptions = false});
  final bool showOptions;
  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  LearnView? _view;
  String? _error;
  String _status = 'Picking something for you…';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() { _error = null; _view = null; });
    try {
      final learn = ref.read(learnServiceProvider);
      var v = await learn.view();
      if (!widget.showOptions && v.plan.emptyReason == EmptyReason.noDomains) {
        if (mounted) setState(() => _status = 'Setting up your starter subjects…');
        await learn.ensureStarterSubjects(bundle: ref.read(assetBundleProvider));
        v = await learn.view();
      }
      if (!mounted) return;
      setState(() => _view = v);
      if (widget.showOptions) return;

      // An earlier prompt that was never imported comes first (same day, same answer).
      if (v.pending != null) {
        final p = v.pending!;
        final what = p.isMap
            ? 'New subjects, chosen for you'
            : p.isOutline
            ? 'Outline for ${p.domainName}'
            : '${p.domainName}${p.itemTitle == null ? '' : ': ${p.itemTitle}'}';
        await _replaceWith(PromptResultScreen(
            prompt: GeneratedPrompt(p.id, p.text, what, kind: p.kind), advice: v.advice, wasPending: true));
        return;
      }
      if (v.plan.options.isEmpty) {
        // Nothing left to teach right now: grow the library instead of asking the learner
        // to choose a subject. Under "wait" / "stop" advice, show the advice and let them decide.
        final g = v.growth;
        if (g == null || _holdBack(v.advice)) return;
        await _generateGrowth(g, v);
        return;
      }

      final top = v.plan.options.first;
      final adv = v.advice;
      final fixing = top.action == LearnAction.remediate && !adv.limitReached;
      if (!fixing && _holdBack(adv)) {
        return; // their own daily limit is used up: the advice card says so and lets them add more anyway
      }
      await _generate(top, v, count: fixing ? top.count : _cap(top.count, adv));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Only the learner's own daily limit holds a prompt back. Everything else the advisor says is advice.
  bool _holdBack(Advice a) => a.limitReached;

  Future<void> _generateGrowth(GrowthOption g, LearnView v) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final learn = ref.read(learnServiceProvider);
      if (v.pending != null) await learn.abandonPending(v.pending!.id);
      final prompt = await learn.chooseGrowth(g, v);
      await _replaceWith(PromptResultScreen(prompt: prompt, view: v, advice: v.advice));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not build the prompt: $e')));
      }
    }
  }

  /// Ask for what the learner's own settings allow: the prompt size, but no more than their daily limit has left.
  int _cap(int wanted, Advice a) {
    if (a.limitReached) return wanted;
    final left = a.dailyLimitLeft < 1 ? 1 : a.dailyLimitLeft;
    return wanted < left ? wanted : left;
  }

  Future<void> _replaceWith(Widget page) async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _generate(LearnOption o, LearnView v, {required int count}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final learn = ref.read(learnServiceProvider);
      if (v.pending != null) await learn.abandonPending(v.pending!.id);
      final g = await learn.choose(o.withCount(count), v);
      final alt = v.plan.options.length > 1 && v.plan.options[1].key != o.key ? v.plan.options[1] : null;
      await _replaceWith(PromptResultScreen(prompt: g, view: v, alternative: alt, advice: v.advice));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not build the prompt: $e')));
      }
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) {
      ref.read(refreshProvider.notifier).bump();
      _run();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Learn something new')),
        body: SafeArea(child: _body(context)),
      );

  Widget _working() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(_status),
        ]),
      );

  Widget _body(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Something went wrong: $_error'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _run, child: const Text('Retry')),
          ]),
        ),
      );
    }
    final v = _view;
    if (v == null) return _working();
    final plan = v.plan;
    final adv = v.advice;
    final t = Theme.of(context).textTheme;
    final gated = !widget.showOptions &&
        plan.options.isNotEmpty &&
        _holdBack(adv) &&
        plan.options.first.action != LearnAction.remediate;
    // On the automatic path a prompt is being generated: show progress, not a list.
    if (!widget.showOptions && v.pending != null) return _working();
    if (!widget.showOptions && plan.options.isNotEmpty && !gated) return _working();
    if (!widget.showOptions && plan.options.isEmpty && v.growth != null && !_holdBack(adv)) return _working();

    return ListView(padding: const EdgeInsets.all(16), children: [
      AdviceCard(adv),
      if (gated) ...[
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('OK, I will stop here'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _busy ? null : () => _generate(plan.options.first, v, count: plan.options.first.count),
          child: Text('Add ${plan.options.first.count} more anyway: ${plan.options.first.headline}'),
        ),
      ],
      if (!gated) ...[
        const SizedBox(height: 8),
        if (plan.options.isEmpty && v.growth == null)
          _empty(context, plan)
        else if (plan.options.isEmpty)
          _growthCard(context, v.growth!, v)
        else ...[
          Text(plan.options.length == 1 ? 'Suggested for today' : 'Pick one', style: t.titleMedium),
          const SizedBox(height: 8),
          for (final o in plan.options) _optionCard(context, o, v),
          if (v.growth != null && widget.showOptions) ...[
            const SizedBox(height: 8),
            _growthCard(context, v.growth!, v),
          ],
        ],
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('Starter library'),
            onPressed: () => _open(const StarterLibraryScreen()),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('New subject or more topics'),
            onPressed: () => _open(const NewSubjectScreen()),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.list_alt),
            label: const Text('Choose a topic myself'),
            onPressed: () => _open(const TopicsScreen(pickMode: true)),
          ),
        ]),
      ],
    ]);
  }

  Widget _optionCard(BuildContext context, LearnOption o, LearnView v) {
    final t = Theme.of(context).textTheme;
    final kind = switch (o.action) {
      LearnAction.newItem => 'New topic',
      LearnAction.deepen => 'Go deeper',
      LearnAction.remediate => 'Fix hard cards',
      LearnAction.revisit => 'Revisit',
    };
    final count = o.action == LearnAction.remediate ? o.count : _cap(o.count, v.advice);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, children: [
            Chip(label: Text(kind)),
            Chip(label: Text('$count card${count == 1 ? '' : 's'}')),
            if (o.explore) const Chip(avatar: Icon(Icons.shuffle, size: 18), label: Text('A change of pace')),
          ]),
          const SizedBox(height: 8),
          Text(o.headline, style: t.titleMedium),
          const SizedBox(height: 4),
          for (final r in o.reasons) Text(r, style: t.bodyMedium),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _busy ? null : () => _generate(o, v, count: count),
            child: const Text('Use this'),
          ),
        ]),
      ),
    );
  }

  Widget _growthCard(BuildContext context, GrowthOption g, LearnView v) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, children: [
            Chip(label: Text(g.kind == GrowthKind.map ? 'New subjects' : 'Grow your library')),
          ]),
          const SizedBox(height: 8),
          Text(g.headline, style: t.titleMedium),
          const SizedBox(height: 4),
          for (final r in g.reasons) Text(r, style: t.bodyMedium),
          const SizedBox(height: 4),
          Text(g.kind == GrowthKind.map
                  ? 'You will get a prompt that asks your LLM for several new subjects. Paste its answer back and tick the ones you want.'
                  : 'You will get a prompt for an outline; paste your LLM\'s answer back and new topics appear.',
              style: t.bodySmall),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _busy ? null : () => _generateGrowth(g, v),
            child: const Text('Get this prompt'),
          ),
        ]),
      ),
    );
  }

  static String _inWords(double days) {
    if (days < 14) return '${days.ceil()} days';
    if (days < 60) return '${(days / 7).round()} weeks';
    if (days < 730) return '${(days / 30).round()} months';
    return '${(days / 365).round()} years';
  }

  Widget _empty(BuildContext context, LearnPlan plan) {
    final (title, body) = switch (plan.emptyReason) {
      EmptyReason.noDomains => (
          'Start with a subject',
          'Pick subjects from the starter library, or name your own and the app will give you a prompt that asks '
              'your LLM for an ordered outline. Paste the answer back and the app takes it from there.'
        ),
      EmptyReason.noSyllabus => ('No topics yet', 'Your subjects have no outline. Create one with the button below.'),
      EmptyReason.allDone => (
          'Everything is covered for now',
          plan.nextRevisitInDays == null
              ? 'Add more topics to a subject, or start a new one.'
              : 'Finished topics come back for a deeper pass. The next one is due in about '
                  '${_inWords(plan.nextRevisitInDays!)}. You can also add more subjects.'
        ),
      EmptyReason.allPaused => (
          'All your subjects are paused',
          'Turn a subject back on under Settings > Subjects and topics.'
        ),
      EmptyReason.none => ('', ''),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => _open(const StarterLibraryScreen()),
            child: const Text('Browse the starter library'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => _open(const NewSubjectScreen()),
            child: const Text('New subject or more topics'),
          ),
        ]),
      ),
    );
  }
}
