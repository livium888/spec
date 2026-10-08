import 'dart:convert';

import '../domain/models.dart';
import '../domain/scheduler.dart';
import 'db/database.dart';
import 'fsrs_scheduler.dart';
import 'settings_repo.dart';

/// Owns `fsrs_params` rows. A row is immutable; changing retention / steps
/// inserts a new row and repoints `active_params_id`. Old log rows keep their
/// original params_id, so replay stays exact.
class ParamsRepo {
  ParamsRepo(this.db, this.settings, {this.factory = dartFsrsFactory});
  final AppDatabase db;
  final SettingsRepo settings;
  final SchedulerFactory factory;

  final _cache = <int, FsrsConfig>{};

  Future<FsrsConfig> configFor(int paramsId) async {
    final hit = _cache[paramsId];
    if (hit != null) return hit;
    final row = await (db.select(db.fsrsParamsTable)..where((t) => t.id.equals(paramsId))).getSingle();
    final cfg = FsrsConfig.fromJson(
        jsonDecode(row.paramsJson) as Map<String, Object?>, row.desiredRetention);
    return _cache[paramsId] = cfg;
  }

  Future<Scheduler> schedulerFor(int paramsId) async => factory(await configFor(paramsId));

  /// Active params id, creating the first row from settings on first use.
  Future<int> activeId({DateTime? now}) async {
    final existing = await settings.getInt(SettingsRepo.activeParamsId, -1);
    if (existing > 0) return existing;
    return _insertFromSettings(now ?? DateTime.now().toUtc());
  }

  /// Put [weights] in use from now on: a NEW params row (old rows are immutable, so every old
  /// review still replays under the weights it was made with). Retention and steps carry over.
  Future<int> useWeights(List<double> weights, {DateTime? now}) async {
    final cur = await configFor(await activeId(now: now));
    final cfg = FsrsConfig(
      weights: weights,
      desiredRetention: cur.desiredRetention,
      learningStepsMin: cur.learningStepsMin,
      relearningStepsMin: cur.relearningStepsMin,
      maximumIntervalDays: cur.maximumIntervalDays,
      fuzzMinDays: cur.fuzzMinDays,
    );
    final id = await db.into(db.fsrsParamsTable).insert(FsrsParamsTableCompanion.insert(
          createdAt: (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch,
          version: factory(cfg).version,
          paramsJson: jsonEncode(cfg.toJson()),
          desiredRetention: cfg.desiredRetention,
        ));
    await settings.set(SettingsRepo.activeParamsId, '$id');
    return id;
  }

  /// Weights now in use.
  Future<List<double>> activeWeights() async => (await configFor(await activeId())).weights;

  /// Call after the user edits retention / steps. No-op if nothing changed.
  Future<int> syncFromSettings({DateTime? now}) async {
    final currentId = await settings.getInt(SettingsRepo.activeParamsId, -1);
    if (currentId <= 0) return _insertFromSettings(now ?? DateTime.now().toUtc());
    final cur = await configFor(currentId);
    final want = await _wanted(cur.weights);
    final same = cur.desiredRetention == want.desiredRetention &&
        cur.learningStepsMin.join(',') == want.learningStepsMin.join(',') &&
        cur.relearningStepsMin.join(',') == want.relearningStepsMin.join(',');
    return same ? currentId : _insertFromSettings(now ?? DateTime.now().toUtc());
  }

  Future<FsrsConfig> _wanted(List<double> weights) async => FsrsConfig(
        weights: weights,
        desiredRetention: await settings.getDouble(SettingsRepo.desiredRetention, 0.90),
        learningStepsMin: await settings.getIntList(SettingsRepo.learningSteps, const [1, 10]),
        relearningStepsMin: await settings.getIntList(SettingsRepo.relearningSteps, const [10]),
      );

  Future<int> _insertFromSettings(DateTime now) async {
    final cfg = await _wanted(fsrs6DefaultWeights);
    final id = await db.into(db.fsrsParamsTable).insert(FsrsParamsTableCompanion.insert(
          createdAt: now.millisecondsSinceEpoch,
          version: factory(cfg).version,
          paramsJson: jsonEncode(cfg.toJson()),
          desiredRetention: cfg.desiredRetention,
        ));
    await settings.set(SettingsRepo.activeParamsId, '$id');
    return id;
  }
}
