
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'db/database.dart';

/// Largest picture kept per card. Pictures are shrunk when picked (see ImagePickerService);
/// this is the safety limit for anything that still arrives too big.
const kMaxImageBytes = 1500000;

class MediaException implements Exception {
  MediaException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Pictures attached to cards. They live in the database (table `media`), so every backup and
/// restore carries them with no extra files. A note names its picture by SHA-256 (field "image").
class MediaService {
  MediaService(this.db);
  final AppDatabase db;

  static bool looksLikeImage(Uint8List b) {
    if (b.length < 12) return false;
    final png = b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
    final jpg = b[0] == 0xFF && b[1] == 0xD8;
    final webp = b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45;
    final gif = b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46;
    return png || jpg || webp || gif;
  }

  /// Store a picture (once per distinct content) and return its id (SHA-256).
  Future<String> save(Uint8List bytes, {DateTime? now}) async {
    if (bytes.length > kMaxImageBytes) {
      throw MediaException('That picture is too large (over ${(kMaxImageBytes / 1e6).toStringAsFixed(1)} MB).');
    }
    if (!looksLikeImage(bytes)) throw MediaException('That file is not a picture the app can show.');
    final sha = sha256.convert(bytes).toString();
    await db.into(db.mediaItems).insert(
          MediaItemsCompanion.insert(
            sha: sha,
            mime: _mime(bytes),
            bytes: bytes,
            createdAt: (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return sha;
  }

  Future<Uint8List?> bytes(String sha) async {
    final r = await (db.select(db.mediaItems)..where((m) => m.sha.equals(sha))).getSingleOrNull();
    return r?.bytes;
  }

  /// Delete a picture no note refers to any more.
  Future<void> deleteIfOrphan(String? sha) async {
    if (sha == null || sha.isEmpty) return;
    final used = await db.customSelect(
        "SELECT 1 FROM note WHERE fields_json LIKE ? LIMIT 1",
        variables: [Variable.withString('%"image":"$sha"%')]).get();
    if (used.isEmpty) {
      await (db.delete(db.mediaItems)..where((m) => m.sha.equals(sha))).go();
    }
  }

  Future<({int count, int bytes})> usage() async {
    final r = await db.customSelect('SELECT COUNT(*) AS n, COALESCE(SUM(LENGTH(bytes)), 0) AS b FROM media').getSingle();
    return (count: r.read<int>('n'), bytes: r.read<int>('b'));
  }

  static String _mime(Uint8List b) {
    if (b[0] == 0x89) return 'image/png';
    if (b[0] == 0xFF) return 'image/jpeg';
    if (b[0] == 0x47) return 'image/gif';
    return 'image/webp';
  }
}
