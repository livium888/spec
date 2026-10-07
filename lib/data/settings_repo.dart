import 'package:drift/drift.dart';

import '../domain/day_clock.dart';
import 'db/database.dart';

/// Key/value settings stored in the DB so they travel inside backups.
class SettingsRepo {
  SettingsRepo(this.db);
  final AppDatabase db;

  static const newPerDay = 'new_per_day';
  static const backlogDivisor = 'backlog_divisor';
  static const rolloverHour = 'rollover_hour';
  static const desiredRetention = 'desired_retention';
  static const learningSteps = 'learning_steps_min'; // "1,10"
  static const relearningSteps = 'relearning_steps_min'; // "10"
  static const activeParamsId = 'active_params_id';
  static const backupTreeUri = 'backup_tree_uri';
  static const lastSessionDomains = 'last_session_domains';

  Future<String?> get(String key) async {
    final r = await (db.select(db.settings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return r?.value;
  }

  Future<void> set(String key, String value) => db
      .into(db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> remove(String key) =>
      (db.delete(db.settings)..where((t) => t.key.equals(key))).go();

  Future<int> getInt(String key, int def) async =>
      int.tryParse(await get(key) ?? '') ?? def;

  Future<double> getDouble(String key, double def) async =>
      double.tryParse(await get(key) ?? '') ?? def;

  Future<List<int>> getIntList(String key, List<int> def) async {
    final v = await get(key);
    if (v == null || v.trim().isEmpty) return def;
    final parsed = v.split(',').map((e) => int.tryParse(e.trim())).toList();
    return parsed.contains(null) ? def : parsed.cast<int>();
  }

  Future<DayClock> dayClock() async => DayClock(rolloverHour: await getInt(rolloverHour, 4));
}
