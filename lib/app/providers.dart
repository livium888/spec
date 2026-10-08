import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backup/backup_service.dart';
import '../data/db/database.dart';
import '../data/engine_service.dart';
import '../data/card_edit_service.dart';
import '../data/import_service.dart';
import '../data/learn_service.dart';
import '../data/outline_service.dart';
import '../data/params_repo.dart';
import '../data/queue_service.dart';
import '../data/review_service.dart';
import '../data/settings_repo.dart';
import '../data/stats_service.dart';
import 'bootstrap.dart';

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

final settingsRepoProvider = Provider((ref) => SettingsRepo(ref.watch(dbProvider)));
final paramsRepoProvider =
    Provider((ref) => ParamsRepo(ref.watch(dbProvider), ref.watch(settingsRepoProvider)));
final reviewServiceProvider = Provider((ref) => ReviewService(
    ref.watch(dbProvider), ref.watch(settingsRepoProvider), ref.watch(paramsRepoProvider)));
final statsServiceProvider =
    Provider((ref) => StatsService(ref.watch(dbProvider), ref.watch(settingsRepoProvider)));
final queueServiceProvider =
    Provider((ref) => QueueService(ref.watch(dbProvider), ref.watch(settingsRepoProvider)));
final importServiceProvider = Provider((ref) => ImportService(ref.watch(dbProvider)));
final cardEditServiceProvider = Provider((ref) => CardEditService(ref.watch(dbProvider), ref.watch(settingsRepoProvider)));
final outlineServiceProvider = Provider((ref) => OutlineService(ref.watch(dbProvider)));
final learnServiceProvider = Provider((ref) => LearnService(
    ref.watch(dbProvider), ref.watch(settingsRepoProvider), ref.watch(queueServiceProvider)));
final promptServiceProvider = Provider(
    (ref) => PromptService(ref.watch(dbProvider), settings: ref.watch(settingsRepoProvider)));
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
