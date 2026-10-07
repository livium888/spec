import 'package:drift/drift.dart';

part 'database.g.dart';

/// Bump together with a migration step in [AppDatabase.migration].
/// Also checked by RestoreBackup against `PRAGMA user_version` of a backup file.
const int kSchemaVersion = 1;

class Domains extends Table {
  @override
  String get tableName => 'domain';
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
}

class SyllabusItems extends Table {
  @override
  String get tableName => 'syllabus_item';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get domainId => integer().references(Domains, #id)();
  TextColumn get title => text()();
  IntColumn get level => integer().withDefault(const Constant(1))(); // 1-3
  IntColumn get position => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('todo'))(); // todo|active|done
}

class Notes extends Table {
  @override
  String get tableName => 'note';
  IntColumn get id => integer().autoIncrement()();
  TextColumn get guid => text().unique()();
  IntColumn get domainId => integer().references(Domains, #id)();
  IntColumn get syllabusItemId => integer().nullable().references(SyllabusItems, #id)();
  TextColumn get type => text()(); // basic|cloze
  TextColumn get fieldsJson => text()();
  TextColumn get tags => text().withDefault(const Constant(''))(); // space separated
  TextColumn get sourceType => text().nullable()();
  TextColumn get sourceRef => text().nullable()();
  TextColumn get llmConfidence => text().nullable()();
  IntColumn get createdAt => integer()();
}

@TableIndex(name: 'card_due_idx', columns: {#due})
@TableIndex(name: 'card_note_idx', columns: {#noteId})
class Cards extends Table {
  @override
  String get tableName => 'card';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId => integer().references(Notes, #id)();
  IntColumn get ord => integer().withDefault(const Constant(0))();
  TextColumn get state => text().withDefault(const Constant('new'))();
  IntColumn get step => integer().withDefault(const Constant(0))(); // added: FSRS learning step
  IntColumn get due => integer()();
  RealColumn get stability => real().nullable()();
  RealColumn get difficulty => real().nullable()();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  IntColumn get lastReview => integer().nullable()();
  BoolColumn get suspended => boolean().withDefault(const Constant(false))();
  IntColumn get buriedUntil => integer().nullable()();
}

class FsrsParamsTable extends Table {
  @override
  String get tableName => 'fsrs_params';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get createdAt => integer()();
  TextColumn get version => text()();
  TextColumn get paramsJson => text()();
  RealColumn get desiredRetention => real()();
}

@TableIndex(name: 'review_log_card_idx', columns: {#cardId})
@TableIndex(name: 'review_log_time_idx', columns: {#reviewedAt})
class ReviewLogs extends Table {
  @override
  String get tableName => 'review_log';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId => integer().references(Cards, #id)();
  IntColumn get reviewedAt => integer()();
  IntColumn get rating => integer()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  TextColumn get stateBefore => text()();
  IntColumn get dueBefore => integer()();
  RealColumn get stabilityBefore => real().nullable()();
  RealColumn get difficultyBefore => real().nullable()();
  RealColumn get elapsedDays => real()();
  RealColumn get scheduledDays => real()();
  TextColumn get fsrsVersion => text()();
  IntColumn get paramsId => integer().references(FsrsParamsTable, #id)();
  IntColumn get revokedAt => integer().nullable()();
}

class PromptLogs extends Table {
  @override
  String get tableName => 'prompt_log';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get createdAt => integer()();
  IntColumn get domainId => integer().references(Domains, #id)();
  IntColumn get syllabusItemId => integer().nullable().references(SyllabusItems, #id)();
  TextColumn get templateVersion => text()();
  TextColumn get promptText => text()();
  IntColumn get cardsRequested => integer()();
  IntColumn get cardsImported => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('issued'))(); // issued|imported|abandoned
}

class InterestLogs extends Table {
  @override
  String get tableName => 'interest_log';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ts => integer()();
  IntColumn get domainId => integer().references(Domains, #id)();
  IntColumn get value => integer()(); // -1|0|1
}

class EngineDecisions extends Table {
  @override
  String get tableName => 'engine_decision';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ts => integer()();
  TextColumn get engineVersion => text()();
  IntColumn get seed => integer()();
  TextColumn get featuresJson => text()();
  TextColumn get scoresJson => text()();
  TextColumn get chosenJson => text()();
}

class BackupLogs extends Table {
  @override
  String get tableName => 'backup_log';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ts => integer()();
  TextColumn get uri => text().nullable()();
  IntColumn get bytes => integer().withDefault(const Constant(0))();
  BoolColumn get ok => boolean()();
  TextColumn get error => text().nullable()();
}

/// Added beyond the spec so settings travel inside backups (see DECISIONS D4).
class Settings extends Table {
  @override
  String get tableName => 'setting';
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  Domains,
  SyllabusItems,
  Notes,
  Cards,
  FsrsParamsTable,
  ReviewLogs,
  PromptLogs,
  InterestLogs,
  EngineDecisions,
  BackupLogs,
  Settings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => kSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Migrations from day one: add `if (from < 2) {...}` steps here.
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
