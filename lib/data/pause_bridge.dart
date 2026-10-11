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
  const PauseVisit({required this.label, required this.atMs, required this.freeMinutes});
  final String label;
  final int atMs, freeMinutes;
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
    return PauseVisit(label: '${r['label']}', atMs: (r['atMs'] as num?)?.toInt() ?? 0, freeMinutes: (r['freeMinutes'] as num?)?.toInt() ?? 2);
  }

  @override
  Future<bool> grantAll() async => await _call<bool>('grantAll') ?? false;

  @override
  Future<void> dropVisit() => _call<void>('dropVisit');
}
