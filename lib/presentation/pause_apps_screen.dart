import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/pause_bridge.dart';
import '../data/pause_settings.dart';
import '../domain/pause_moves.dart';
import '../domain/pause_stats.dart';
import '../domain/site_rule.dart';

/// "Focus before apps" (D58, named and grouped in D62): which apps and sites bring up the pause, the ways out of it, how
/// hard it is to open, and the Android switch. Every change is saved at once and handed to the phone side.
class PauseAppsScreen extends ConsumerStatefulWidget {
  const PauseAppsScreen({super.key});
  @override
  ConsumerState<PauseAppsScreen> createState() => _PauseAppsScreenState();
}

class _PauseAppsScreenState extends ConsumerState<PauseAppsScreen> with WidgetsBindingObserver {
  PauseChoices? _c;
  List<InstalledApp>? _installed;
  PauseStatus _status = PauseStatus.off;
  String? _weekLine;
  String? _error;
  final _site = TextEditingController();
  // The Undo bar belongs to this screen (a bar that waits for a tap would follow the learner over Settings and Today).
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  String? _siteError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _site.dispose();
    super.dispose();
  }

  // Back from Android's settings: the switch may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final s = await ref.read(pauseBridgeProvider).status();
    final week = pauseWeekLine(await ref.read(pauseSettingsProvider).week());
    if (mounted) {
      setState(() {
        _status = s;
        _weekLine = week;
      });
    }
  }

  Future<void> _load() async {
    try {
      final bridge = ref.read(pauseBridgeProvider);
      var c = await ref.read(pauseSettingsProvider).load();
      final installed = await bridge.apps();
      final status = await bridge.status();
      final week = pauseWeekLine(await ref.read(pauseSettingsProvider).week());
      if (!c.saved) {
        // First visit: suggest LinkedIn (the app and the site), which the learner can remove.
        final hasLinkedIn = installed.any((a) => a.pkg == kLinkedInPackage);
        c = PauseChoices(apps: [if (hasLinkedIn) kLinkedInPackage], sites: [parseSiteRule('*.linkedin.com')!], freeMinutes: c.freeMinutes, saved: true);
        await ref.read(pauseSettingsProvider).save(c);
      }
      if (!mounted) return;
      setState(() {
        _c = c;
        _installed = installed;
        _status = status;
        _weekLine = week;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not read your apps: $e');
    }
  }

  Future<void> _save(PauseChoices c) async {
    setState(() => _c = c);
    await ref.read(pauseSettingsProvider).save(c);
  }

  String _labelOf(String pkg) => _installed?.firstWhere((a) => a.pkg == pkg, orElse: () => InstalledApp(pkg, pkg)).label ?? pkg;

  void _addSite() {
    final c = _c!;
    final err = siteRuleError(_site.text);
    final rule = err == null ? parseSiteRule(_site.text) : null;
    if (rule == null) {
      setState(() => _siteError = err);
      return;
    }
    if (c.sites.contains(rule)) {
      setState(() => _siteError = 'Already in the list');
      return;
    }
    if (c.sites.length >= kMaxSiteRules) {
      setState(() => _siteError = 'The list is full ($kMaxSiteRules sites)');
      return;
    }
    _site.clear();
    _siteError = null;
    _save(c.copyWith(sites: [...c.sites, rule]));
  }

  Future<void> _pickApps() async {
    final c = _c!;
    final chosen = await Navigator.of(context).push<List<String>>(MaterialPageRoute(
      builder: (_) => _AppPicker(installed: [for (final a in _installed ?? <InstalledApp>[]) if (!a.browser) a], selected: c.apps.toSet()),
    ));
    if (chosen != null) await _save(c.copyWith(apps: chosen));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = _c;
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
      appBar: AppBar(title: const Text('Focus before apps')),
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Try again')),
                  ]),
                ),
              )
            : c == null
                ? const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'))
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Text(
                      'When you open one of these apps or sites, a short pause comes first. Do 5 cards, breathe, or move: '
                      'each gets you in.',
                      style: t.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    _StatusCard(status: _status, weekLine: _weekLine),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: () => ref.read(pauseBridgeProvider).test(),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Test the pause'),
                    ),
                    const SizedBox(height: 4),
                    Text('Shows the pause now, as it will look. A test is not counted.', style: t.bodySmall),
                    const Divider(height: 40),
                    _heading('What to pause', t),
                    const SizedBox(height: 12),
                    _apps(c, t),
                    const SizedBox(height: 24),
                    _browsers(c, t),
                    const SizedBox(height: 24),
                    _sites(c, t),
                    const Divider(height: 40),
                    _heading('Ways out', t),
                    const SizedBox(height: 4),
                    Text('Three ways to get into a paused app. Each frees that app or site, or everything for the cards, for a few minutes.', style: t.bodyMedium),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: c.freeMinutes,
                      decoration: const InputDecoration(labelText: 'Free time after the cards, the breathing or the exercise'),
                      isExpanded: true,
                      items: [for (final m in kPauseFreeMinutesChoices) DropdownMenuItem(value: m, child: Text('$m ${m == 1 ? 'minute' : 'minutes'}'))],
                      onChanged: (m) => m == null ? null : _save(c.copyWith(freeMinutes: m)),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: c.cardsEvery,
                      decoration: const InputDecoration(
                        labelText: 'Cards come first, after this many openings',
                        helperText: 'After this many openings by breathing or an exercise since your last cards, the pause offers only the cards (or not now). '
                            'Nothing changes when no cards are due.',
                        helperMaxLines: 4,
                      ),
                      isExpanded: true,
                      items: [for (final n in kPauseCardsEveryChoices) DropdownMenuItem(value: n, child: Text(n == 0 ? 'Off' : '$n ${n == 1 ? 'opening' : 'openings'}'))],
                      onChanged: (n) => n == null ? null : _save(c.copyWith(cardsEvery: n)),
                    ),
                    const SizedBox(height: 24),
                    _moves(c, t),
                    const Divider(height: 40),
                    _heading('Harder to open', t),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('The wait grows each time'),
                      subtitle: const Text('Breathing starts at 10 seconds and adds 5 for each pause of the same app or site today, up to a minute. It starts again at the turn of the day.'),
                      value: c.risingWait,
                      onChanged: (v) => _save(c.copyWith(risingWait: v)),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: c.openLimit,
                      decoration: const InputDecoration(
                        labelText: 'Daily open limit, per app or site',
                        helperText: 'After this many openings by breathing or an exercise, only the cards (or not now) remain until tomorrow.',
                        helperMaxLines: 3,
                      ),
                      items: [for (final n in kPauseOpenLimitChoices) DropdownMenuItem(value: n, child: Text(n == 0 ? 'No limit' : '$n ${n == 1 ? 'opening' : 'openings'} a day'))],
                      onChanged: (n) => n == null ? null : _save(c.copyWith(openLimit: n)),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show my next card\'s question'),
                      subtitle: const Text('On the pause, so you can see what the cards are about. Anyone looking at your screen can see it too.'),
                      value: c.showNext,
                      onChanged: (v) => _save(c.copyWith(showNext: v)),
                    ),
                    const SizedBox(height: 24),
                  ]),
      ),
    ));
  }

  /// A group heading: bigger than the sections inside it, and a heading for screen readers.
  Widget _heading(String text, TextTheme t) => Semantics(header: true, child: Text(text, style: t.headlineSmall));

  /// "Move first" (D61): the exercises offered on the pause as a third way to earn free time for one app or site.
  /// Tap one to change it; the arrows set the order the pause lists them in (the arrows, not dragging, so it works
  /// without a gesture); remove has an Undo (D62).
  Widget _moves(PauseChoices c, TextTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Move first', style: t.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Do an exercise for its time, then open the one app or site. '
          'Nothing checks that you did it. The countdown only stops you tapping through, and if you skip it, you have only fooled yourself.',
          style: t.bodyMedium,
        ),
        if (c.moves.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 8), child: Text('No exercises, so the pause shows no "Move first" button.'))
        else
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Tap an exercise to change its name or time.', style: t.bodySmall)),
        for (var i = 0; i < c.moves.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(c.moves[i].name),
            subtitle: Text('${c.moves[i].seconds} seconds'),
            onTap: () => _editMove(c, i),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Move ${c.moves[i].name} up',
                icon: const Icon(Icons.arrow_upward),
                onPressed: i == 0 ? null : () => _shiftMove(c, i, -1),
              ),
              IconButton(
                tooltip: 'Move ${c.moves[i].name} down',
                icon: const Icon(Icons.arrow_downward),
                onPressed: i == c.moves.length - 1 ? null : () => _shiftMove(c, i, 1),
              ),
              IconButton(
                tooltip: 'Remove ${c.moves[i].name}',
                icon: const Icon(Icons.close),
                onPressed: () => _removeMove(c, i),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: c.moves.length >= kMaxPauseMoves ? null : () => _addMove(c),
            icon: const Icon(Icons.add),
            label: const Text('Add an exercise'),
          ),
          if (storePauseMoves(c.moves) != storePauseMoves(kStarterMoves))
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => _save(c.copyWith(moves: kStarterMoves)),
              child: const Text('Use the suggestions'),
            ),
        ]),
        if (c.moves.length >= kMaxPauseMoves) Padding(padding: const EdgeInsets.only(top: 6), child: Text('The list is full ($kMaxPauseMoves).', style: t.bodySmall)),
      ]);

  Future<void> _addMove(PauseChoices c) async {
    final made = await showDialog<PauseMove>(context: context, builder: (_) => _MoveDialog(taken: [for (final m in c.moves) m.name.toLowerCase()]));
    if (made != null && mounted) await _save(c.copyWith(moves: [...c.moves, made]));
  }

  /// Change one exercise in place: its place in the list stays. Its own name does not count as a repeat.
  Future<void> _editMove(PauseChoices c, int i) async {
    final made = await showDialog<PauseMove>(
      context: context,
      builder: (_) => _MoveDialog(initial: c.moves[i], taken: [for (var j = 0; j < c.moves.length; j++) if (j != i) c.moves[j].name.toLowerCase()]),
    );
    if (made != null && mounted) await _save(c.copyWith(moves: [for (var j = 0; j < c.moves.length; j++) j == i ? made : c.moves[j]]));
  }

  Future<void> _shiftMove(PauseChoices c, int i, int by) {
    final list = [...c.moves];
    final m = list.removeAt(i);
    list.insert(i + by, m);
    return _save(c.copyWith(moves: list));
  }

  /// Remove, with an Undo that puts it back where it was. The bar waits until it is closed (no timer, WCAG 2.2.1) and
  /// goes with this screen: it is shown by this screen's own messenger, not the app's.
  void _removeMove(PauseChoices c, int i) {
    final gone = c.moves[i];
    final settings = ref.read(pauseSettingsProvider);
    _save(c.copyWith(moves: [for (var j = 0; j < c.moves.length; j++) if (j != i) c.moves[j]]));
    _messenger.currentState!
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('Removed ${gone.name}'),
        showCloseIcon: true,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final now = await settings.load();
            if (now.moves.any((m) => m.name.toLowerCase() == gone.name.toLowerCase()) || now.moves.length >= kMaxPauseMoves) return;
            final back = now.copyWith(moves: [...now.moves]..insert(i.clamp(0, now.moves.length), gone));
            await settings.save(back);
            if (mounted) setState(() => _c = back);
          },
        ),
      ));
  }

  Widget _apps(PauseChoices c, TextTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Apps', style: t.titleMedium),
        if (c.apps.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 8), child: Text('No apps yet.'))
        else
          for (final p in c.apps)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_labelOf(p)),
              trailing: IconButton(
                tooltip: 'Remove ${_labelOf(p)}',
                icon: const Icon(Icons.close),
                onPressed: () => _save(c.copyWith(apps: [for (final x in c.apps) if (x != p) x])),
              ),
            ),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _pickApps, icon: const Icon(Icons.add), label: const Text('Choose apps')),
      ]);

  Widget _browsers(PauseChoices c, TextTheme t) {
    final browsers = [for (final a in _installed ?? <InstalledApp>[]) if (a.browser) a];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Browsers', style: t.titleMedium),
      const SizedBox(height: 4),
      Text(
        browsers.isEmpty
            ? 'No supported browser found. Sites can be paused in Chrome, Firefox, Samsung Internet, Edge, Brave, Opera, Vivaldi and DuckDuckGo.'
            : 'The sites below are paused in these browsers. Switch one on to pause it whenever you open it, whatever the site.',
        style: t.bodyMedium,
      ),
      for (final b in browsers)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(b.label),
          subtitle: const Text('Pause whenever I open it'),
          value: c.wholeBrowsers.contains(b.pkg),
          onChanged: (on) => _save(c.copyWith(wholeBrowsers: on ? [...c.wholeBrowsers, b.pkg] : [for (final x in c.wholeBrowsers) if (x != b.pkg) x])),
        ),
      const SizedBox(height: 4),
      Text('Other browsers, and pages opened inside other apps, are not checked.', style: t.bodySmall),
    ]);
  }

  Widget _sites(PauseChoices c, TextTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sites', style: t.titleMedium),
        const SizedBox(height: 4),
        Text('linkedin.com is that site (with or without www). *.linkedin.com adds every subdomain. reddit.com/r/all is that page and the pages under it.',
            style: t.bodyMedium),
        if (c.sites.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('No sites yet.')),
        for (final r in c.sites)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(r.canonical),
            trailing: IconButton(
              tooltip: 'Remove ${r.canonical}',
              icon: const Icon(Icons.close),
              onPressed: () => _save(c.copyWith(sites: [for (final x in c.sites) if (x != r) x])),
            ),
          ),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: _site,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(labelText: 'Add a site', hintText: 'e.g. *.reddit.com', errorText: _siteError),
              onChanged: (_) {
                if (_siteError != null) setState(() => _siteError = null);
              },
              onSubmitted: (_) => _addSite(),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(64, 52)), onPressed: _addSite, child: const Text('Add')),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Some browsers show only the site in the address bar, not the page: then a page rule cannot be seen. A site rule always can.',
            style: t.bodySmall),
      ]);
}

/// A name and a number of seconds for one exercise: to add one, or (with [initial]) to change one.
class _MoveDialog extends StatefulWidget {
  const _MoveDialog({required this.taken, this.initial});
  final List<String> taken;
  final PauseMove? initial;
  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _seconds = TextEditingController(text: '${widget.initial?.seconds ?? 30}');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _seconds.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.replaceAll(RegExp(r'[ \t\r\n]+'), ' ').trim();
    final secs = int.tryParse(_seconds.text.trim());
    final err = pauseMoveError(name, secs) ?? (widget.taken.contains(name.toLowerCase()) ? 'That one is in the list already' : null);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop(PauseMove(name, secs!));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'Edit exercise' : 'Add an exercise'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: kMaxPauseMoveName,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. 20 jumping jacks'),
          onChanged: (_) => setState(() => _error = null),
        ),
        TextField(
          controller: _seconds,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Countdown in seconds ($kPauseMoveMinSeconds to $kPauseMoveMaxSeconds)', errorText: _error, errorMaxLines: 2),
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _save(),
        ),
      ]),
      actions: [
        TextButton(style: TextButton.styleFrom(minimumSize: const Size(64, 48)), onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(64, 48)), onPressed: _save, child: Text(editing ? 'Save' : 'Add')),
      ],
    );
  }
}

/// Whether Android has the pause switched on, how to switch it on, and what it can see.
class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.status, this.weekLine});
  final PauseStatus status;
  final String? weekLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final bridge = ref.read(pauseBridgeProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(status.on ? Icons.check_circle : Icons.pause_circle_outline),
            const SizedBox(width: 8),
            Expanded(child: Text(status.on ? 'The pause is on' : 'The pause is off', style: t.titleMedium)),
          ]),
          const SizedBox(height: 8),
          if (status.on)
            Text(weekLine ?? 'It has not come up this week yet.')
          else ...[
            const Text('Android asks you to switch it on yourself: open the accessibility settings, find '
                '"Daily Learning: pause before apps" and switch it on.'),
            const SizedBox(height: 8),
            FilledButton(onPressed: bridge.openAccessibilitySettings, child: const Text('Open accessibility settings')),
            const SizedBox(height: 12),
            const Text('If Android says the setting is restricted (it does for apps not installed from a store): open App info, '
                'tap the menu (three dots, top right), choose "Allow restricted settings", then try again.'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: bridge.openAppInfo, child: const Text('Open App info')),
          ],
          const SizedBox(height: 12),
          Text(
            'What it sees: only which app is in front. In a supported browser it also reads the address bar, to compare it '
            'with your sites; the address is not saved and nothing leaves your phone. It reads nothing else on the screen.',
            style: t.bodySmall,
          ),
        ]),
      ),
    );
  }
}

/// Choose the apps that bring up the pause, with a search field.
class _AppPicker extends StatefulWidget {
  const _AppPicker({required this.installed, required this.selected});
  final List<InstalledApp> installed;
  final Set<String> selected;
  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  late final Set<String> _sel = {...widget.selected};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final shown = [for (final a in widget.installed) if (_q.isEmpty || a.label.toLowerCase().contains(_q)) a];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose apps'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, _sel.toList()), child: const Text('Done'))],
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(labelText: 'Search apps', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: widget.installed.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No apps found on this phone.')))
                : shown.isEmpty
                    ? const Center(child: Text('No app by that name.'))
                    : ListView(children: [
                        for (final a in shown)
                          CheckboxListTile(
                            title: Text(a.label),
                            value: _sel.contains(a.pkg),
                            onChanged: (on) => setState(() => on == true ? _sel.add(a.pkg) : _sel.remove(a.pkg)),
                          ),
                      ]),
          ),
        ]),
      ),
    );
  }
}
