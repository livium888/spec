import 'package:drift/drift.dart';

part 'database.g.dart';

/// Bump together with a migration step in [AppDatabase.migration].
/// Also checked by RestoreBackup against `PRAGMA user_version` of a backup file.
const int kSchemaVersion = 4;

class Domains extends Table {
  @override
  String get tableName => 'domain';
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  // v3: how often "Learn something new" offers this subject (0 off, 1 low, 2 normal, 3 high)
  // and whether finished topics come back later for deeper cards.
  IntColumn get learnWeight => integer().withDefault(const Constant(2))();
  BoolColumn get revisit => boolean().withDefault(const Constant(true))();
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
  // v2: how many cards make this topic "covered", and a one-line scope note.
  IntColumn get targetCards => integer().withDefault(const Constant(10))();
  TextColumn get description => text().withDefault(const Constant(''))();
  // v3: how many times this topic has been taken to a deeper level (1 = first pass).
  IntColumn get rounds => integer().withDefault(const Constant(1))();
}

/// v2: item `itemId` should come after `prereqId`.
class SyllabusPrereqs extends Table {
  @override
  String get tableName => 'syllabus_prereq';
  IntColumn get itemId => integer().references(SyllabusItems, #id)();
  IntColumn get prereqId => integer().references(SyllabusItems, #id)();
  @override
  Set<Column> get primaryKey => {itemId, prereqId};
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

/// Rebuildable cache: answers per 15-minute bucket (bucket = reviewed_at / 900000), so
/// Home and Progress never scan the whole review_log. review_log stays the source of truth.
class ActivityBuckets extends Table {
  @override
  String get tableName => 'activity_bucket';
  IntColumn get bucket => integer()();
  IntColumn get n => integer()();
  @override
  Set<Column> get primaryKey => {bucket};
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
  SyllabusPrereqs,
  Notes,
  Cards,
  FsrsParamsTable,
  ReviewLogs,
  ActivityBuckets,
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
          if (from < 2) {
            await m.addColumn(syllabusItems, syllabusItems.targetCards);
            await m.addColumn(syllabusItems, syllabusItems.description);
            await m.createTable(syllabusPrereqs);
          }
          if (from < 3) {
            await m.addColumn(domains, domains.learnWeight);
            await m.addColumn(domains, domains.revisit);
            await m.addColumn(syllabusItems, syllabusItems.rounds);
          }
          if (from < 4) {
            await m.createTable(activityBuckets); // filled lazily from review_log on first use
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          // Foreground app and the WorkManager isolate may both open the file.
          await customStatement('PRAGMA busy_timeout = 5000');
        },
      );
}
