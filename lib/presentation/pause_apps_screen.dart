import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../data/pause_bridge.dart';
import '../data/pause_settings.dart';
import '../domain/site_rule.dart';

/// "Pause before apps" (D58): which apps and sites bring up the pause, the free time, and the Android switch.
/// Every change is saved at once and handed to the phone side.
class PauseAppsScreen extends ConsumerStatefulWidget {
  const PauseAppsScreen({super.key});
  @override
  ConsumerState<PauseAppsScreen> createState() => _PauseAppsScreenState();
}

class _PauseAppsScreenState extends ConsumerState<PauseAppsScreen> with WidgetsBindingObserver {
  PauseChoices? _c;
  List<InstalledApp>? _installed;
  PauseStatus _status = PauseStatus.off;
  String? _error;
  final _site = TextEditingController();
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
    if (mounted) setState(() => _status = s);
  }

  Future<void> _load() async {
    try {
      final bridge = ref.read(pauseBridgeProvider);
      var c = await ref.read(pauseSettingsProvider).load();
      final installed = await bridge.apps();
      final status = await bridge.status();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Pause before apps')),
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
                      'When you open one of these apps or sites, a short pause comes first: do 5 cards (then everything here is '
                      'free for ${c.freeMinutes} min), breathe then open, or not now.',
                      style: t.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    _StatusCard(status: _status),
                    const Divider(height: 32),
                    _apps(c, t),
                    const Divider(height: 32),
                    _browsers(c, t),
                    const Divider(height: 32),
                    _sites(c, t),
                    const Divider(height: 32),
                    Text('Free time', style: t.titleLarge),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: c.freeMinutes,
                      decoration: const InputDecoration(labelText: 'After the cards or the breathing pause'),
                      items: [for (final m in kPauseFreeMinutesChoices) DropdownMenuItem(value: m, child: Text('$m ${m == 1 ? 'minute' : 'minutes'}'))],
                      onChanged: (m) => m == null ? null : _save(c.copyWith(freeMinutes: m)),
                    ),
                    const SizedBox(height: 24),
                  ]),
      ),
    );
  }

  Widget _apps(PauseChoices c, TextTheme t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Apps', style: t.titleLarge),
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
      Text('Browsers', style: t.titleLarge),
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
        Text('Sites', style: t.titleLarge),
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

/// Whether Android has the pause switched on, how to switch it on, and what it can see.
class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.status});
  final PauseStatus status;

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
            Text('This week: you turned back ${status.back} ${status.back == 1 ? 'time' : 'times'}, '
                'did cards ${status.cards} ${status.cards == 1 ? 'time' : 'times'}, and breathed then opened ${status.open} ${status.open == 1 ? 'time' : 'times'}.')
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
