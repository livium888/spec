import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../data/pause_bridge.dart';
import '../data/pause_settings.dart';
import '../data/backup/backup_service.dart';
import '../data/db/database.dart';
import '../data/engine_service.dart';
import '../data/error_log.dart';
import '../data/foundation_service.dart';
import '../data/card_edit_service.dart';
import '../data/import_service.dart';
import '../data/keywords_service.dart';
import '../data/knowledge_service.dart';
import '../data/learn_service.dart';
import '../data/media_service.dart';
import '../data/optimizer_service.dart';
import '../data/outline_service.dart';
import '../data/params_repo.dart';
import '../data/picture_finder.dart';
import '../data/queue_service.dart';
import '../data/reading_service.dart';
import '../data/reminder_service.dart';
import '../data/plan_service.dart';
import '../data/retire_service.dart';
import '../data/review_service.dart';
import '../data/settings_repo.dart';
import '../data/stats_service.dart';
import 'bootstrap.dart';
import 'device_services.dart';
import 'launch_service.dart';
import 'share_service.dart';

/// Where bundled starter subjects are read from (overridden in tests).
final assetBundleProvider = Provider<AssetBundle>((_) => rootBundle);

final bootstrapProvider = Provider<Bootstrap>((_) => throw UnimplementedError('override in main'));

/// Holds the live database. Replaced after a restore so every dependent rebuilds.
class DbNotifier extends Notifier<AppDatabase> {
  @override
  AppDatabase build() => ref.watch(bootstrapProvider).db;
  void replace(AppDatabase db) => state = db;
}

final dbProvider = NotifierProvider<DbNotifier, AppDatabase>(DbNotifier.new);

final errorLogProvider = Provider((ref) =>
    ErrorLog(File(p.join(ref.watch(bootstrapProvider).dbFile.parent.path, 'error.log'))));
final promptSharerProvider = Provider<PromptSharer>((_) => const SharePlusPromptSharer());
final shareInboxProvider = Provider<ShareInbox>((_) => const ChannelShareInbox());
final reminderBackendProvider =
    Provider<ReminderBackend>((_) => LocalNotificationsBackend(onOpenReview: () => LaunchRelay.pending.value = LaunchRoute.review));
final launchInboxProvider = Provider<LaunchInbox>((_) => const ChannelLaunchInbox());
final dueBridgeProvider = Provider<DueBridge>((_) => const ChannelDueBridge());
final pauseBridgeProvider = Provider<PauseBridge>((_) => const ChannelPauseBridge());
final pauseSettingsProvider =
    Provider((ref) => PauseSettings(ref.watch(dbProvider), ref.watch(settingsRepoProvider), ref.watch(pauseBridgeProvider)));
final notificationLaunchProvider = Provider<NotificationLaunch>((_) => const PluginNotificationLaunch());
final pictureFinderProvider = Provider<PictureFinder>((_) => PictureLookup());
final pageOpenerProvider = Provider<PageOpener>((_) => const InAppPageOpener());
final imagePickerProvider = Provider<ImagePickerService>((_) => const GalleryImagePicker());
final speakerProvider = Provider<Speaker>((ref) {
  final s = PhoneSpeaker();
  ref.onDispose(s.stop);
  return s;
});
final settingsRepoProvider = Provider((ref) => SettingsRepo(ref.watch(dbProvider)));
final paramsRepoProvider =
    Provider((ref) => ParamsRepo(ref.watch(dbProvider), ref.watch(settingsRepoProvider)));
final reviewServiceProvider = Provider((ref) => ReviewService(
    ref.watch(dbProvider), ref.watch(settingsRepoProvider), ref.watch(paramsRepoProvider)));
final statsServiceProvider =
    Provider((ref) => StatsService(ref.watch(dbProvider), ref.watch(settingsRepoProvider), params: ref.watch(paramsRepoProvider)));
final queueServiceProvider =
    Provider((ref) => QueueService(ref.watch(dbProvider), ref.watch(settingsRepoProvider)));
final importServiceProvider = Provider((ref) => ImportService(ref.watch(dbProvider)));
final cardEditServiceProvider = Provider((ref) => CardEditService(ref.watch(dbProvider), ref.watch(settingsRepoProvider)));
final reminderServiceProvider =
    Provider((ref) => ReminderService(ref.watch(settingsRepoProvider), ref.watch(reminderBackendProvider)));
final keywordsServiceProvider = Provider((ref) => KeywordsService(ref.watch(dbProvider)));
final readingServiceProvider = Provider((ref) => ReadingService(ref.watch(dbProvider)));
final readingVerifierProvider = Provider<ReadingVerifier>((_) => CatalogueVerifier());
final mediaServiceProvider = Provider((ref) => MediaService(ref.watch(dbProvider)));

/// A card picture's bytes by id (null if missing). Cached while a screen shows it.
final mediaBytesProvider = FutureProvider.autoDispose.family<Uint8List?, String>(
    (ref, sha) => ref.watch(mediaServiceProvider).bytes(sha));
final retireServiceProvider = Provider((ref) => RetireService(ref.watch(dbProvider)));
final planServiceProvider = Provider((ref) =>
    PlanService(ref.watch(dbProvider), ref.watch(settingsRepoProvider), ref.watch(paramsRepoProvider)));
final optimizerServiceProvider = Provider((ref) => OptimizerService(
    ref.watch(dbProvider), ref.watch(settingsRepoProvider), ref.watch(paramsRepoProvider)));
final outlineServiceProvider = Provider((ref) => OutlineService(ref.watch(dbProvider)));
final learnServiceProvider = Provider((ref) => LearnService(
    ref.watch(dbProvider), ref.watch(settingsRepoProvider), ref.watch(queueServiceProvider)));
final promptServiceProvider = Provider(
    (ref) => PromptService(ref.watch(dbProvider), settings: ref.watch(settingsRepoProvider)));
final knowledgeServiceProvider = Provider((ref) => KnowledgeService(ref.watch(dbProvider), ref.watch(paramsRepoProvider)));
final foundationServiceProvider =
    Provider((ref) => FoundationService(ref.watch(dbProvider), ref.watch(settingsRepoProvider)));
final interestServiceProvider = Provider((ref) => InterestService(ref.watch(dbProvider)));
final featuresServiceProvider = Provider(
    (ref) => EngineFeaturesService(ref.watch(dbProvider), ref.watch(settingsRepoProvider)));
final backupServiceProvider =
    Provider((ref) => BackupService(ref.watch(dbProvider), ref.watch(settingsRepoProvider)));

/// Bumped after any write so read-only screens refresh.
class Refresh extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final refreshProvider = NotifierProvider<Refresh, int>(Refresh.new);
