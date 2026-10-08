import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import '../data/backup/backup_service.dart';
import '../data/backup/backup_storage.dart';
import '../data/error_log.dart';
import '../data/settings_repo.dart';
import 'bootstrap.dart';

const kWeeklyBackupTask = 'weekly-backup';

/// Runs in a background isolate, even if the app was never opened this week.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    DartPluginRegistrant.ensureInitialized();
    final dbFile = await Bootstrap.dbFilePath();
    final db = Bootstrap.openDb(dbFile);
    try {
      final settings = SettingsRepo(db);
      final uri = await settings.get(SettingsRepo.backupTreeUri);
      if (uri == null) return true; // nothing configured; not a failure
      final svc = BackupService(db, settings);
      if (!await svc.isStale(days: 6)) return true; // already backed up recently
      final err = await svc.export(SafBackupStorage(uri), await getTemporaryDirectory());
      return err == null; // false => WorkManager retries with backoff
    } catch (e, st) {
      ErrorLog(File(p.join(dbFile.parent.path, 'error.log'))).record(e, st, where: 'weekly backup');
      return false;
    } finally {
      await db.close();
    }
  });
}

Future<void> initBackgroundBackup() async {
  if (!Platform.isAndroid) return;
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    kWeeklyBackupTask,
    kWeeklyBackupTask,
    frequency: const Duration(days: 7),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.notRequired, requiresBatteryNotLow: true),
  );
}
