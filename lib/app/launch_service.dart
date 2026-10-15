import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

import '../data/reminder_service.dart' show kReminderPayload;

/// Where an entry point outside the app (the reminder notification, the launcher shortcuts, the home-screen
/// widget, the Quick Settings tile) wants the app to open (D51).
enum LaunchRoute { review, quick, pause, pauseTalk }

/// The few values the native side may ask for. Anything else is ignored: the app only ever opens the review.
LaunchRoute? launchRouteOf(String? s) => switch (s) {
      'review' => LaunchRoute.review,
      'quick5' => LaunchRoute.quick,
      'pause5' => LaunchRoute.pause, // five cards from the pause before an app (D58); grants nothing by itself
      'pausetalk' => LaunchRoute.pauseTalk, // a Socratic conversation from the pause (D66); grants nothing by itself
      _ => null,
    };

/// A "Quick 5" session: this many cards, then stop (the learner can carry on).
const kQuickSessionCards = 5;

/// The route Android handed to the activity, kept there until Dart asks (like shared text).
abstract class LaunchInbox {
  Future<LaunchRoute?> take();
}

class ChannelLaunchInbox implements LaunchInbox {
  const ChannelLaunchInbox();
  static const channel = MethodChannel('daily_learning/launch');

  @override
  Future<LaunchRoute?> take() async {
    try {
      return launchRouteOf(await channel.invokeMethod<String>('takeRoute'));
    } on MissingPluginException {
      return null; // not Android (tests, desktop)
    } on PlatformException {
      return null;
    }
  }
}

/// A route set from inside Dart: the reminder notification tapped while the app is running.
class LaunchRelay {
  static final ValueNotifier<LaunchRoute?> pending = ValueNotifier<LaunchRoute?>(null);
  static LaunchRoute? take() {
    final r = pending.value;
    pending.value = null;
    return r;
  }
}

/// How many cards are waiting today, handed to the widget and the Quick Settings tile. They show the number
/// only for the day it was written for: after the day rolls over they say "tap to see today's cards" until the
/// app has run again (a number from yesterday would be a wrong number).
abstract class DueBridge {
  /// [next]: the next card's question, shortened, for the pause before apps (D59).
  Future<void> publish({required int due, required int minutes, required int dayEndMs, String? next});
}

class ChannelDueBridge implements DueBridge {
  const ChannelDueBridge();

  @override
  Future<void> publish({required int due, required int minutes, required int dayEndMs, String? next}) async {
    try {
      await ChannelLaunchInbox.channel.invokeMethod<void>('publishDue', {'due': due, 'minutes': minutes, 'dayEndMs': dayEndMs, 'next': next});
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }
}

/// Was the app started by tapping the daily reminder? Asked once, at a cold start.
abstract class NotificationLaunch {
  Future<bool> openedFromReminder();
}

class PluginNotificationLaunch implements NotificationLaunch {
  const PluginNotificationLaunch();

  @override
  Future<bool> openedFromReminder() async {
    try {
      final d = await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
      return d != null && d.didNotificationLaunchApp && d.notificationResponse?.payload == kReminderPayload;
    } catch (_) {
      return false; // no plugin here (tests), or nothing to report
    }
  }
}
