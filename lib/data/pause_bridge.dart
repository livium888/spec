import 'package:flutter/services.dart';

/// "Pause before apps" (D58): the phone side (PauseService, PauseActivity, PauseStore in Kotlin).
class InstalledApp {
  const InstalledApp(this.pkg, this.label, {this.browser = false});
  final String pkg, label;

  /// A browser whose address bar the pause can read (so site rules work in it).
  final bool browser;
}

class PauseStatus {
  const PauseStatus({required this.on, this.back = 0, this.open = 0, this.cards = 0});

  /// The service is switched on in Android's accessibility settings.
  final bool on;

  /// Choices on the pause over the last 7 days.
  final int back, open, cards;
  static const off = PauseStatus(on: false);
}

/// A pause waiting for its five cards.
class PauseVisit {
  const PauseVisit({required this.label, required this.atMs, required this.freeMinutes});
  final String label;
  final int atMs, freeMinutes;
}

abstract class PauseBridge {
  Future<void> setConfig({required List<String> apps, required List<String> wholeBrowsers, required String rules, required int freeMinutes});
  Future<List<InstalledApp>> apps();
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
  Future<void> setConfig({required List<String> apps, required List<String> wholeBrowsers, required String rules, required int freeMinutes}) =>
      _call<void>('setConfig', {'apps': apps, 'wholeBrowsers': wholeBrowsers, 'rules': rules, 'freeMinutes': freeMinutes});

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
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return PauseStatus(on: r['on'] == true, back: n(r['back']), open: n(r['open']), cards: n(r['cards']));
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
