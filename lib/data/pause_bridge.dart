import 'package:flutter/services.dart';

/// "Pause before apps" (D58): the phone side (PauseService, PauseActivity, PauseStore in Kotlin).
class InstalledApp {
  const InstalledApp(this.pkg, this.label, {this.browser = false});
  final String pkg, label;

  /// A browser whose address bar the pause can read (so site rules work in it).
  final bool browser;
}

class PauseStatus {
  const PauseStatus({required this.on});

  /// The service is switched on in Android's accessibility settings.
  final bool on;
  static const off = PauseStatus(on: false);
}

/// A pause waiting for its five cards.
class PauseVisit {
  const PauseVisit({
    required this.label,
    required this.atMs,
    required this.freeMinutes,
    this.kind = 'cards',
    this.noteId,
    this.ord = 0,
    this.started = false,
    this.secondsLeft = 0,
  });
  final String label;
  final int atMs, freeMinutes;

  /// What the pause asked for: `cards` (D58) or `talk` (D66).
  final String kind;

  /// A talk visit once the learner has shared or copied the prompt: the card they are talking about, and the seconds
  /// before they may open the app. Both live on the phone side, so they survive the app being closed mid-chat.
  final int? noteId;
  final int ord;
  final bool started;
  final int secondsLeft;
}

/// The answer to "I talked it through": the phone side decides, the app only shows.
class TalkGrant {
  const TalkGrant({required this.ok, this.secondsLeft = 0, this.reason = ''});
  final bool ok;
  final int secondsLeft;

  /// When not ok: `early` (the minimum time has not passed), `none` (no live talk visit: it ran out).
  final String reason;
}

abstract class PauseBridge {
  Future<void> setConfig({
    required List<String> apps,
    required List<String> wholeBrowsers,
    required String rules,
    required int freeMinutes,
    required bool risingWait,
    required int openLimit,
    required bool showNext,
    required String moves,
    required int cardsEvery,
    required int talkMinutes,
    required bool talkOffered,
    required int rolloverHour,
  });
  Future<List<InstalledApp>> apps();

  /// The phone side's log of pauses (D59): one `ms<TAB>kind<TAB>key` line each. Empty when there is none.
  Future<String> log();

  /// Show the real pause screen now, about this app (not counted).
  Future<void> test();
  Future<PauseStatus> status();
  Future<void> openAccessibilitySettings();
  Future<void> openAppInfo();
  Future<PauseVisit?> visit();

  /// Free time for everything watched, then back to the paused app. Only after the answers were counted (D58).
  Future<bool> grantAll();
  Future<void> dropVisit();

  /// The learner shared or copied the Socratic prompt for this card: the phone side keeps the card and starts the
  /// minimum-time clock (only the first call counts). Returns the seconds left.
  Future<int> talkStart(int noteId, int ord);

  /// Free time for the one app, after the Socratic conversation, if the minimum time has passed.
  Future<TalkGrant> grantTalk();
}

class ChannelPauseBridge implements PauseBridge {
  const ChannelPauseBridge();
  static const _ch = MethodChannel('daily_learning/pause');

  Future<T?> _call<T>(String m, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(m, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> setConfig({
    required List<String> apps,
    required List<String> wholeBrowsers,
    required String rules,
    required int freeMinutes,
    required bool risingWait,
    required int openLimit,
    required bool showNext,
    required String moves,
    required int cardsEvery,
    required int talkMinutes,
    required bool talkOffered,
    required int rolloverHour,
  }) =>
      _call<void>('setConfig', {
        'apps': apps,
        'wholeBrowsers': wholeBrowsers,
        'rules': rules,
        'freeMinutes': freeMinutes,
        'rising': risingWait,
        'openLimit': openLimit,
        'showNext': showNext,
        'moves': moves,
        'cardsEvery': cardsEvery,
        'talkMinutes': talkMinutes,
        'talkOffered': talkOffered,
        'rolloverHour': rolloverHour,
      });

  @override
  Future<String> log() async => await _call<String>('log') ?? '';

  @override
  Future<void> test() => _call<bool>('test');

  @override
  Future<List<InstalledApp>> apps() async {
    final r = await _call<List<Object?>>('apps') ?? const [];
    return [
      for (final e in r)
        if (e is Map) InstalledApp('${e['pkg']}', '${e['label']}', browser: e['browser'] == true),
    ];
  }

  @override
  Future<PauseStatus> status() async {
    final r = await _call<Map<Object?, Object?>>('status');
    if (r == null) return PauseStatus.off;
    return PauseStatus(on: r['on'] == true);
  }

  @override
  Future<void> openAccessibilitySettings() => _call<bool>('openAccessibility');

  @override
  Future<void> openAppInfo() => _call<bool>('openAppInfo');

  @override
  Future<PauseVisit?> visit() async {
    final r = await _call<Map<Object?, Object?>>('visit');
    if (r == null) return null;
    return PauseVisit(
      label: '${r['label']}',
      atMs: (r['atMs'] as num?)?.toInt() ?? 0,
      freeMinutes: (r['freeMinutes'] as num?)?.toInt() ?? 2,
      kind: r['kind'] == 'talk' ? 'talk' : 'cards',
      noteId: (r['noteId'] as num?)?.toInt(),
      ord: (r['ord'] as num?)?.toInt() ?? 0,
      started: r['started'] == true,
      secondsLeft: (r['secondsLeft'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<bool> grantAll() async => await _call<bool>('grantAll') ?? false;

  @override
  Future<void> dropVisit() => _call<void>('dropVisit');

  @override
  Future<int> talkStart(int noteId, int ord) async {
    final r = await _call<Map<Object?, Object?>>('talkStart', {'noteId': noteId, 'ord': ord});
    return (r?['secondsLeft'] as num?)?.toInt() ?? kTalkMinSeconds;
  }

  @override
  Future<TalkGrant> grantTalk() async {
    final r = await _call<Map<Object?, Object?>>('grantTalk');
    if (r == null) return const TalkGrant(ok: false, reason: 'none');
    return TalkGrant(ok: r['ok'] == true, secondsLeft: (r['secondsLeft'] as num?)?.toInt() ?? 0, reason: '${r['reason'] ?? ''}');
  }
}

/// The least time between sharing the prompt and opening the app (the phone side holds the clock; this is for the words).
const kTalkMinSeconds = 180;
