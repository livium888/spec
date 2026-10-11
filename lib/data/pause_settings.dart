import 'package:drift/drift.dart';

import 'pause_bridge.dart';
import '../domain/site_rule.dart';
import 'db/database.dart';
import 'settings_repo.dart';

/// The learner's "Pause before apps" choices (D58). Kept in the app's settings, so they are in the backup, and
/// copied to the phone side on every change and at start (the service runs without the app).
class PauseChoices {
  const PauseChoices({this.apps = const [], this.wholeBrowsers = const [], this.sites = const [], this.freeMinutes = kDefaultPauseFreeMinutes, this.saved = false});
  final List<String> apps;
  final List<String> wholeBrowsers;
  final List<SiteRule> sites;
  final int freeMinutes;

  /// False until the learner has saved once (the screen then suggests LinkedIn).
  final bool saved;

  PauseChoices copyWith({List<String>? apps, List<String>? wholeBrowsers, List<SiteRule>? sites, int? freeMinutes}) => PauseChoices(
        apps: apps ?? this.apps,
        wholeBrowsers: wholeBrowsers ?? this.wholeBrowsers,
        sites: sites ?? this.sites,
        freeMinutes: freeMinutes ?? this.freeMinutes,
        saved: true,
      );
}

const kLinkedInPackage = 'com.linkedin.android'; // verify against the installed app on the phone
const _maxPackages = 100;

class PauseSettings {
  PauseSettings(this.db, this.settings, this.bridge);
  final AppDatabase db;
  final SettingsRepo settings;
  final PauseBridge bridge;

  static const appsKey = 'pause_apps';
  static const browsersKey = 'pause_whole_browsers';
  static const sitesKey = 'pause_sites';
  static const freeKey = 'pause_free_min';

  /// A package name as Android writes it; anything else (a restored backup is external input) is dropped.
  static final _pkg = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$');

  static List<String> _packages(String? v) =>
      <String>{for (final p in (v ?? '').split(',')) if (_pkg.hasMatch(p.trim()) && p.trim().length <= 255) p.trim()}.take(_maxPackages).toList();

  Future<PauseChoices> load() async {
    final apps = await settings.get(appsKey);
    final free = await settings.getInt(freeKey, kDefaultPauseFreeMinutes);
    return PauseChoices(
      apps: _packages(apps),
      wholeBrowsers: _packages(await settings.get(browsersKey)),
      sites: siteRulesOf(await settings.get(sitesKey)),
      freeMinutes: kPauseFreeMinutesChoices.contains(free) ? free : kDefaultPauseFreeMinutes,
      saved: apps != null,
    );
  }

  Future<void> save(PauseChoices c) async {
    await settings.set(appsKey, c.apps.join(','));
    await settings.set(browsersKey, c.wholeBrowsers.join(','));
    await settings.set(sitesKey, storeSiteRules(c.sites));
    await settings.set(freeKey, '${c.freeMinutes}');
    await push(c);
  }

  /// Copy the saved choices to the phone side (at app start, and after a restore).
  Future<void> push([PauseChoices? c]) async {
    final v = c ?? await load();
    if (!v.saved) return;
    await bridge.setConfig(apps: v.apps, wholeBrowsers: v.wholeBrowsers, rules: storeSiteRules(v.sites), freeMinutes: v.freeMinutes);
  }

  /// Answers given since [sinceMs] (undone ones do not count): what "Do 5 cards" is judged on.
  Future<int> answersSince(int sinceMs) async {
    final r = await db.customSelect(
      'SELECT COUNT(*) AS n FROM review_log WHERE reviewed_at >= ? AND revoked_at IS NULL',
      variables: [Variable.withInt(sinceMs)],
    ).getSingle();
    return r.read<int>('n');
  }
}
