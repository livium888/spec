import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/learn_service.dart';
import 'package:daily_learning/data/outline_service.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/starter_library.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:daily_learning/domain/learn_planner.dart';
import 'package:daily_learning/domain/study_advisor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first use: bundled subjects are added once, and the first press has something to pick', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final settings = SettingsRepo(db);
    final learn = LearnService(db, settings, QueueService(db, settings));

    expect((await learn.view()).plan.emptyReason, EmptyReason.noDomains);
    expect(await learn.ensureStarterSubjects(), 15);
    expect(await learn.ensureStarterSubjects(), 0); // idempotent
    expect((await db.select(db.domains).get()).length, 15);
    expect((await db.select(db.domains).get()).map((d) => d.name), isNot(contains('My language (rename me)')));

    final v = await learn.view();
    expect(v.plan.options, isNotEmpty);
    expect(v.plan.candidates.where((c) => c.action == LearnAction.newItem).length, 15); // one per subject
    expect(v.advice.level, AdviceLevel.go);
  });

  test('language course template: asks for a name, and renaming it imports cleanly', () async {
    final all = await StarterLibrary.load();
    final tpl = all.singleWhere((o) => o.askName);
    expect(tpl.domain, 'My language (rename me)');
    expect(all.where((o) => !o.askName).length, 15);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final svc = OutlineService(db);
    final p = await svc.preview(tpl.rawAs('  Spanish '));
    expect(p.domain, 'Spanish');
    expect(p.hasFatal, isFalse);
    expect(p.newDomain, isTrue);
    final s = await svc.commit(p);
    expect(s.items, tpl.topics);
    expect((await db.select(db.domains).getSingle()).name, 'Spanish');
    // Adding the same template again under the same name adds nothing.
    expect((await svc.preview(tpl.rawAs('spanish'))).importable, isEmpty);
  });
}
