import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../domain/fsrs_model.dart';
import '../domain/fsrs_trainer.dart';
import '../domain/optimizer_advice.dart';
import 'activity_cache.dart';
import 'db/database.dart';
import 'fsrs_scheduler.dart' show fsrs6DefaultWeights;
import 'params_repo.dart';
import 'settings_repo.dart';

const _day = 86400000;

/// Most reviews read for fitting. Beyond this, whole cards are sampled (seeded by id), so a
/// lifetime of tens of millions of reviews still fits in memory and in minutes.
const kMaxTrainingReviews = 150000;

Future<TrainResult> runInIsolate(TrainRequest r) => Isolate.run(() => trainFsrs(r));

class OptimizerStatus {
  const OptimizerStatus({
    required this.advice,
    required this.usableReviews,
    required this.personalised,
    required this.last,
    this.predicted,
    this.actual,
    this.sample = 0,
  });
  final OptimizerAdvice advice;
  final int usableReviews;

  /// Personal weights are in use (otherwise the built-in defaults).
  final bool personalised;
  final OptimizerSnapshot? last;
  final double? predicted, actual;
  final int sample;
}

/// "Make the memory model mine": reads the review history, fits the weights (in an isolate),
/// and, only if the learner agrees, puts them in use. review_log stays the source of truth;
/// old reviews keep the params they were made with, so replay == live is untouched.
class OptimizerService {
  OptimizerService(this.db, this.settings, this.params, {this.runner = runInIsolate});
  final AppDatabase db;
  final SettingsRepo settings;
  final ParamsRepo params;
  final Future<TrainResult> Function(TrainRequest) runner;

  static const stateKey = 'optimizer_state';
  static const bannerSnoozeKey = 'optimizer_banner_until_ms';

  Future<OptimizerSnapshot?> lastRun() async {
    final raw = await settings.get(stateKey);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return OptimizerSnapshot(
          atMs: j['at'] as int,
          usableThen: j['usable'] as int,
          applied: j['applied'] as bool,
          gain: (j['gain'] as num?)?.toDouble());
    } catch (_) {
      return null; // damaged note: behave as if never fitted
    }
  }

  /// Cheap advice for the Today screen: no history is read, usable reviews are estimated
  /// from the cached answer count (about 3 in 4 answers follow a gap of a day or more).
  Future<OptimizerAdvice> quickAdvice({DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc();
    final cache = ActivityCache(db, settings);
    final total = await cache.total();
    return const OptimizerAdvisor().advise(OptimizerAdviceInput(
      usableReviews: (total * 0.75).round(),
      reviewsPerDay: await _pace(cache, t),
      nowMs: t.millisecondsSinceEpoch,
      last: await lastRun(),
      estimated: true,
    ));
  }

  /// Full status for the Memory model screen (reads the history once, capped).
  Future<OptimizerStatus> status({DateTime? now}) async {
    final t = (now ?? DateTime.now()).toUtc();
    final cache = ActivityCache(db, settings);
    final data = await _load(cache);
    final w = await params.activeWeights();
    final fit = data.cards.isEmpty ? null : evaluate(data.cards, w);
    final usable = (data.usable * data.scale).round();
    final last = await lastRun();
    final advice = const OptimizerAdvisor().advise(OptimizerAdviceInput(
      usableReviews: usable,
      reviewsPerDay: await _pace(cache, t),
      nowMs: t.millisecondsSinceEpoch,
      last: last,
      predictedRecall: fit == null || fit.n == 0 ? null : fit.meanPredicted,
      actualRecall: fit == null || fit.n == 0 ? null : fit.meanActual,
      sample: fit?.n ?? 0,
    ));
    return OptimizerStatus(
      advice: advice,
      usableReviews: usable,
      personalised: !_same(w, fsrs6DefaultWeights),
      last: last,
      predicted: fit?.meanPredicted,
      actual: fit?.meanActual,
      sample: fit?.n ?? 0,
    );
  }

  /// Fit now. Does not change anything: the learner sees the result and decides ([apply] or [keep]).
  Future<TrainResult> optimise() async {
    final data = await _load(ActivityCache(db, settings));
    return runner(TrainRequest(
      cards: data.cards,
      start: await params.activeWeights(),
      defaults: fsrs6DefaultWeights,
    ));
  }

  /// Use the fitted weights from the next review on.
  Future<void> apply(TrainResult r, {DateTime? now}) async {
    await params.useWeights(r.weights, now: now);
    await _remember(r, applied: true, now: now);
  }

  /// Keep the current weights; remembers the check so the next advice counts from today.
  Future<void> keep(TrainResult r, {DateTime? now}) => _remember(r, applied: false, now: now);

  /// Back to the built-in defaults (new reviews only; history is untouched).
  Future<void> resetToDefaults({DateTime? now}) async {
    await params.useWeights(fsrs6DefaultWeights, now: now);
    await settings.remove(stateKey);
  }

  Future<void> snoozeBanner(Duration d, {DateTime? now}) => settings.set(
      bannerSnoozeKey, '${(now ?? DateTime.now()).toUtc().add(d).millisecondsSinceEpoch}');

  Future<bool> bannerSnoozed({DateTime? now}) async =>
      (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch < await settings.getInt(bannerSnoozeKey, 0);

  // ---- internals -----------------------------------------------------------

  Future<void> _remember(TrainResult r, {required bool applied, DateTime? now}) async {
    final data = await _load(ActivityCache(db, settings));
    await settings.set(
        stateKey,
        jsonEncode({
          'at': (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
          'usable': (data.usable * data.scale).round(),
          'applied': applied,
          'gain': r.relativeGain,
        }));
  }

  Future<double> _pace(ActivityCache cache, DateTime t) async {
    final since = t.millisecondsSinceEpoch - 28 * _day;
    final recent = await cache.buckets(sinceMs: since);
    return recent.fold<int>(0, (a, b) => a + b.n) / 28.0;
  }

  /// Non-revoked answers as per-card sequences, sampling whole cards if there are too many.
  Future<_Data> _load(ActivityCache cache) async {
    final total = await cache.total();
    final k = total <= kMaxTrainingReviews ? 1 : (total / kMaxTrainingReviews).ceil();
    final rows = await db.customSelect(
        'SELECT card_id, reviewed_at, rating FROM review_log '
        'WHERE revoked_at IS NULL AND (? = 1 OR card_id % ? = 0) '
        'ORDER BY card_id, reviewed_at, id',
        variables: [Variable.withInt(k), Variable.withInt(k)]).get();
    final cards = <CardSeq>[];
    var usable = 0;
    var ratings = <int>[], dts = <int>[];
    int? cur, last;
    void flush() {
      if (ratings.length >= 2) {
        cards.add(CardSeq(Uint8List.fromList(ratings), Int32List.fromList(dts)));
        for (var i = 1; i < dts.length; i++) {
          if (dts[i] >= 1) usable++;
        }
      }
      ratings = [];
      dts = [];
    }

    for (final r in rows) {
      final id = r.read<int>('card_id');
      final at = r.read<int>('reviewed_at');
      if (id != cur) {
        flush();
        cur = id;
        last = null;
      }
      ratings.add(r.read<int>('rating').clamp(1, 4));
      dts.add(last == null ? 0 : (at - last) ~/ _day);
      last = at;
    }
    flush();
    return _Data(cards, usable, k.toDouble());
  }

  static bool _same(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 1e-9) return false;
    }
    return true;
  }
}

class _Data {
  const _Data(this.cards, this.usable, this.scale);
  final List<CardSeq> cards;
  final int usable;

  /// Multiply counts by this to estimate the whole history (1 when nothing was sampled out).
  final double scale;
}
