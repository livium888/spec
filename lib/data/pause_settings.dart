import 'package:drift/drift.dart';

import 'pause_bridge.dart';
import '../domain/pause_moves.dart';
import '../domain/pause_stats.dart';
import '../domain/site_rule.dart';
import 'db/database.dart';
import 'settings_repo.dart';

/// The learner's "Pause before apps" choices (D58). Kept in the app's settings, so they are in the backup, and
/// copied to the phone side on every change and at start (the service runs without the app).
class PauseChoices {
  const PauseChoices({
    this.apps = const [],
    this.wholeBrowsers = const [],
    this.sites = const [],
    this.freeMinutes = kDefaultPauseFreeMinutes,
    this.risingWait = true,
    this.openLimit = 0,
    this.showNext = true,
    this.moves = kStarterMoves,
    this.cardsEvery = kDefaultPauseCardsEvery,
    this.saved = false,
  });

  /// D61: the exercises offered as "Move first" (none: the button is not shown).
  final List<PauseMove> moves;

  /// D62: after this many openings by breathing or an exercise since the last real cards session, only the cards are
  /// offered (0 = off).
  final int cardsEvery;

  /// D59: the breathing wait grows with each pause of the same app today; a daily open limit (0 = off); the next
  /// card's question on the pause.
  final bool risingWait;
  final int openLimit;
  final bool showNext;
  final List<String> apps;
  final List<String> wholeBrowsers;
  final List<SiteRule> sites;
  final int freeMinutes;

  /// False until the learner has saved once (the screen then suggests LinkedIn).
  final bool saved;

  PauseChoices copyWith({
    List<String>? apps,
    List<String>? wholeBrowsers,
    List<SiteRule>? sites,
    int? freeMinutes,
    bool? risingWait,
    int? openLimit,
    bool? showNext,
    List<PauseMove>? moves,
    int? cardsEvery,
  }) =>
      PauseChoices(
        apps: apps ?? this.apps,
        wholeBrowsers: wholeBrowsers ?? this.wholeBrowsers,
        sites: sites ?? this.sites,
        freeMinutes: freeMinutes ?? this.freeMinutes,
        risingWait: risingWait ?? this.risingWait,
        openLimit: openLimit ?? this.openLimit,
        showNext: showNext ?? this.showNext,
        moves: moves ?? this.moves,
        cardsEvery: cardsEvery ?? this.cardsEvery,
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
  static const risingKey = 'pause_rising_wait';
  static const limitKey = 'pause_open_limit';
  static const showNextKey = 'pause_show_next';
  static const movesKey = 'pause_moves';
  static const cardsEveryKey = 'pause_cards_every';

  /// A package name as Android writes it; anything else (a restored backup is external input) is dropped.
  static final _pkg = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$');

  static List<String> _packages(String? v) =>
      <String>{for (final p in (v ?? '').split(',')) if (_pkg.hasMatch(p.trim()) && p.trim().length <= 255) p.trim()}.take(_maxPackages).toList();

  Future<PauseChoices> load() async {
    final apps = await settings.get(appsKey);
    final free = await settings.getInt(freeKey, kDefaultPauseFreeMinutes);
    final limit = await settings.getInt(limitKey, 0);
    final every = await settings.getInt(cardsEveryKey, kDefaultPauseCardsEvery);
    return PauseChoices(
      apps: _packages(apps),
      wholeBrowsers: _packages(await settings.get(browsersKey)),
      sites: siteRulesOf(await settings.get(sitesKey)),
      freeMinutes: kPauseFreeMinutesChoices.contains(free) ? free : kDefaultPauseFreeMinutes,
      risingWait: await settings.get(risingKey) != '0',
      openLimit: kPauseOpenLimitChoices.contains(limit) ? limit : 0,
      showNext: await settings.get(showNextKey) != '0',
      moves: pauseMovesOf(await settings.get(movesKey)),
      cardsEvery: kPauseCardsEveryChoices.contains(every) ? every : kDefaultPauseCardsEvery,
      saved: apps != null,
    );
  }

  Future<void> save(PauseChoices c) async {
    await settings.set(appsKey, c.apps.join(','));
    await settings.set(browsersKey, c.wholeBrowsers.join(','));
    await settings.set(sitesKey, storeSiteRules(c.sites));
    await settings.set(freeKey, '${c.freeMinutes}');
    await settings.set(risingKey, c.risingWait ? '1' : '0');
    await settings.set(limitKey, '${c.openLimit}');
    await settings.set(showNextKey, c.showNext ? '1' : '0');
    await settings.set(movesKey, storePauseMoves(c.moves));
    await settings.set(cardsEveryKey, '${c.cardsEvery}');
    await push(c);
  }

  /// Copy the saved choices to the phone side (at app start, and after a restore).
  Future<void> push([PauseChoices? c]) async {
    final v = c ?? await load();
    if (!v.saved) return;
    await bridge.setConfig(
      apps: v.apps,
      wholeBrowsers: v.wholeBrowsers,
      rules: storeSiteRules(v.sites),
      freeMinutes: v.freeMinutes,
      risingWait: v.risingWait,
      openLimit: v.openLimit,
      showNext: v.showNext,
      moves: storePauseMoves(v.moves),
      cardsEvery: v.cardsEvery,
      rolloverHour: (await settings.dayClock()).rolloverHour,
    );
  }

  /// The last 7 app days of pauses (D59), read from the phone side's log.
  Future<List<PauseDay>> week({DateTime? now}) async {
    final log = await bridge.log();
    final events = [for (final l in log.split('\n')) ?PauseEvent.parse(l)];
    return pauseDays(events, await settings.dayClock(), now ?? DateTime.now());
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
