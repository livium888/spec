import 'dart:io';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

class BackupFile {
  const BackupFile(this.name, this.uri, this.lastModified, this.length);
  final String name;
  final String uri;
  final int lastModified;
  final int length;
}

/// Where backups live. Implementations: SAF folder (app), plain dir (tests).
///
/// File-to-file on purpose: a lifetime database is far larger than a phone can hold
/// in memory, so nothing here ever loads a whole backup into a byte array.
abstract class BackupStorage {
  Future<BackupFile> writeFile(String name, File source);
  Future<List<BackupFile>> list();
  Future<void> delete(BackupFile f);
  Future<void> readToFile(BackupFile f, File dest);
}

/// Storage Access Framework: the user picks a folder once; the persisted URI
/// permission is all we hold (no broad storage permission).
class SafBackupStorage implements BackupStorage {
  SafBackupStorage(this.treeUri);
  final String treeUri;
  final _util = SafUtil();
  final _stream = SafStream();

  @override
  Future<BackupFile> writeFile(String name, File source) async {
    final r = await _stream.pasteLocalFile(source.path, treeUri, name, 'application/octet-stream',
        overwrite: true);
    return BackupFile(
        r.fileName ?? name, r.uri.toString(), DateTime.now().millisecondsSinceEpoch, source.lengthSync());
  }

  @override
  Future<List<BackupFile>> list() async => [
        for (final f in await _util.list(treeUri))
          if (!f.isDir) BackupFile(f.name, f.uri, f.lastModified, f.length)
      ];

  @override
  Future<void> delete(BackupFile f) => _util.delete(f.uri, false);

  @override
  Future<void> readToFile(BackupFile f, File dest) => _stream.copyToLocalFile(f.uri, dest.path);
}

class DirectoryBackupStorage implements BackupStorage {
  DirectoryBackupStorage(this.dir);
  final Directory dir;

  @override
  Future<BackupFile> writeFile(String name, File source) async {
    final f = await source.copy('${dir.path}/$name');
    return BackupFile(name, f.path, f.lastModifiedSync().millisecondsSinceEpoch, f.lengthSync());
  }

  @override
  Future<List<BackupFile>> list() async => [
        for (final e in dir.listSync().whereType<File>())
          BackupFile(e.uri.pathSegments.last, e.path, e.lastModifiedSync().millisecondsSinceEpoch,
              e.lengthSync())
      ];

  @override
  Future<void> delete(BackupFile f) => File(f.uri).delete();

  @override
  Future<void> readToFile(BackupFile f, File dest) async {
    await File(f.uri).copy(dest.path);
  }
}
