import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/db/database.dart';

/// Everything that must exist before the first frame.
class Bootstrap {
  Bootstrap(this.dbFile, this.tmpDir, this.db);
  final File dbFile;
  final Directory tmpDir;
  final AppDatabase db;

  static Future<File> dbFilePath() async =>
      File(p.join((await getApplicationDocumentsDirectory()).path, 'learning.db'));

  static AppDatabase openDb(File f) => AppDatabase(NativeDatabase(f));

  static Future<Bootstrap> open() async {
    final f = await dbFilePath();
    final tmp = await getTemporaryDirectory();
    return Bootstrap(f, tmp, openDb(f));
  }
}
