import 'dart:io';
import 'dart:typed_data';

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
abstract class BackupStorage {
  Future<BackupFile> write(String name, Uint8List bytes);
  Future<List<BackupFile>> list();
  Future<void> delete(BackupFile f);
  Future<Uint8List> read(BackupFile f);
}

/// Storage Access Framework: the user picks a folder once; the persisted URI
/// permission is all we hold (no broad storage permission).
class SafBackupStorage implements BackupStorage {
  SafBackupStorage(this.treeUri);
  final String treeUri;
  final _util = SafUtil();
  final _stream = SafStream();

  @override
  Future<BackupFile> write(String name, Uint8List bytes) async {
    final r = await _stream.writeFileBytes(treeUri, name, 'application/octet-stream', bytes,
        overwrite: true);
    return BackupFile(r.fileName ?? name, r.uri.toString(), DateTime.now().millisecondsSinceEpoch, bytes.length);
  }

  @override
  Future<List<BackupFile>> list() async => [
        for (final f in await _util.list(treeUri))
          if (!f.isDir) BackupFile(f.name, f.uri, f.lastModified, f.length)
      ];

  @override
  Future<void> delete(BackupFile f) => _util.delete(f.uri, false);

  @override
  Future<Uint8List> read(BackupFile f) => _stream.readFileBytes(f.uri);
}

class DirectoryBackupStorage implements BackupStorage {
  DirectoryBackupStorage(this.dir);
  final Directory dir;

  @override
  Future<BackupFile> write(String name, Uint8List bytes) async {
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    return BackupFile(name, f.path, f.lastModifiedSync().millisecondsSinceEpoch, bytes.length);
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
  Future<Uint8List> read(BackupFile f) => File(f.uri).readAsBytes();
}
