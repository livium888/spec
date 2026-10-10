import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../domain/anki_import.dart';
import '../domain/anki_text.dart';

/// Reading an Anki export (D50). The file is UNTRUSTED: it is size-capped, never executed, opened read-only,
/// and nothing in it is written to disk except the one database inside, into the app's private temp folder.
const kMaxAnkiFileBytes = 400 * 1024 * 1024;
const kMaxAnkiTextBytes = 20 * 1024 * 1024;
const kMaxAnkiCollectionBytes = 300 * 1024 * 1024;
const kMaxAnkiEntries = 200000;
const kMaxAnkiMediaBytes = 5 * 1024 * 1024;

/// Why a file could not be read, in words the learner can act on.
class AnkiFileException implements Exception {
  AnkiFileException(this.message);
  final String message;
  @override
  String toString() => message;
}

const _newFormatAdvice = 'This file uses Anki\'s newest format, which this app cannot read. In Anki choose File > Export, '
    'pick "Anki Deck Package (*.apkg)", tick "Support older Anki versions", export again and choose that file. '
    'Or export "Notes in Plain Text (*.txt)" (cards only, no pictures).';

/// The notes of a file and a way to fetch the pictures they name.
class AnkiRead {
  AnkiRead({required this.notes, required this.name, this.media, this.onClose});
  final List<AnkiNote> notes;
  final String name;
  final Future<Uint8List?> Function(String)? media;
  final void Function()? onClose;

  bool get hasPictures => media != null;

  /// The bytes of a picture named in a card, or null when the file has none by that name (or is too big).
  Future<Uint8List?> picture(String file) async => media == null ? null : media!(file);

  void close() => onClose?.call();
}

/// Reads [file]: an `.apkg` package or a plain-text/CSV export. [tmp] is the app's private temp folder.
Future<AnkiRead> readAnkiFile(File file, Directory tmp, {String? name}) async {
  final label = name ?? file.uri.pathSegments.last;
  final length = await file.length();
  if (length == 0) throw AnkiFileException('That file is empty.');
  final head = await file.openRead(0, 4).fold<List<int>>([], (a, b) => a..addAll(b));
  final isZip = head.length >= 4 && head[0] == 0x50 && head[1] == 0x4B && head[2] == 3 && head[3] == 4;
  if (isZip) {
    if (length > kMaxAnkiFileBytes) {
      throw AnkiFileException('That file is over ${kMaxAnkiFileBytes ~/ (1024 * 1024)} MB. Export one deck at a time.');
    }
    return _readPackage(file, tmp, label);
  }
  if (length > kMaxAnkiTextBytes) throw AnkiFileException('That text file is over ${kMaxAnkiTextBytes ~/ (1024 * 1024)} MB. Split it.');
  final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
  final parsed = parseAnkiTextFile(text, maxRows: kMaxAnkiNotes + 1);
  if (parsed == null || parsed.rows.isEmpty) throw AnkiFileException('No cards found in that file.');
  if (parsed.rows.length > kMaxAnkiNotes) throw AnkiFileException('More than $kMaxAnkiNotes notes. Export one deck at a time.');
  final notes = notesOfTextFile(parsed, deckName: _deckFromName(label));
  if (notes.isEmpty) throw AnkiFileException('No cards found in that file.');
  return AnkiRead(notes: notes, name: label);
}

String _deckFromName(String file) {
  final base = file.contains('.') ? file.substring(0, file.lastIndexOf('.')) : file;
  final clean = base.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  return clean.isEmpty ? 'Imported from Anki' : clean;
}

Future<AnkiRead> _readPackage(File file, Directory tmp, String label) async {
  final input = InputFileStream(file.path);
  final Archive archive;
  try {
    archive = ZipDecoder().decodeStream(input);
  } catch (_) {
    await input.close();
    throw AnkiFileException('That is not a readable Anki package (the zip is damaged).');
  }
  void closeAll() => input.closeSync();
  try {
    if (archive.files.length > kMaxAnkiEntries) throw AnkiFileException('That package holds too many files.');
    ArchiveFile? entry(String n) {
      for (final f in archive.files) {
        if (f.name == n && f.isFile) return f;
      }
      return null;
    }

    final modern = entry('collection.anki21');
    final legacy = entry('collection.anki2');
    final collection = modern ?? legacy;
    if (collection == null) {
      throw AnkiFileException(entry('collection.anki21b') != null ? _newFormatAdvice : 'No Anki collection found in that package.');
    }
    if (collection.size > kMaxAnkiCollectionBytes) throw AnkiFileException('The collection inside is too large.');
    final bytes = collection.readBytes();
    if (bytes == null || bytes.length > kMaxAnkiCollectionBytes) throw AnkiFileException('The collection inside could not be read.');

    final db = File('${tmp.path}/anki_import_${DateTime.now().microsecondsSinceEpoch}.db');
    await tmp.create(recursive: true);
    await db.writeAsBytes(bytes, flush: true);
    void removeDb() {
      try {
        if (db.existsSync()) db.deleteSync();
      } catch (_) {}
    }

    final List<AnkiNote> notes;
    try {
      notes = _notesOfCollection(db.path, label);
    } on AnkiFileException {
      removeDb();
      rethrow;
    } catch (e) {
      removeDb();
      throw AnkiFileException('Could not read the cards in that package ($e).');
    }
    removeDb(); // the notes are in memory now

    // Pictures: the "media" entry maps "0","1",... to the real file names (a JSON object in the older format).
    Map<String, String>? names;
    final mediaMap = entry('media');
    if (mediaMap != null && mediaMap.size < 20 * 1024 * 1024) {
      try {
        final j = jsonDecode(utf8.decode(mediaMap.readBytes() ?? Uint8List(0)));
        if (j is Map) names = {for (final e in j.entries) if (e.value is String) e.value as String: '${e.key}'};
      } catch (_) {
        names = null; // not the older JSON map: the pictures are left behind (the cards still import)
      }
    }
    Future<Uint8List?> picture(String file) async {
      final key = names?[file];
      if (key == null) return null;
      final e = entry(key);
      if (e == null || e.size > kMaxAnkiMediaBytes) return null;
      final b = e.readBytes();
      return b == null || b.length > kMaxAnkiMediaBytes ? null : Uint8List.fromList(b);
    }

    return AnkiRead(notes: notes, name: label, media: names == null ? null : picture, onClose: closeAll);
  } catch (e) {
    closeAll();
    rethrow;
  }
}

List<AnkiNote> _notesOfCollection(String path, String label) {
  final db = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
  try {
    db.execute('PRAGMA query_only = ON');
    final col = db.select('SELECT models, decks FROM col LIMIT 1');
    if (col.isEmpty) throw AnkiFileException('No Anki collection found in that package.');
    final models = jsonDecode(col.first['models'] as String);
    final decks = jsonDecode(col.first['decks'] as String);
    if (models is! Map || decks is! Map) throw AnkiFileException(_newFormatAdvice);

    final count = db.select('SELECT COUNT(*) AS n FROM notes').first['n'] as int;
    if (count > kMaxAnkiNotes) throw AnkiFileException('That package holds $count notes (the limit is $kMaxAnkiNotes). Export one deck at a time.');

    // The deck of a note: the deck of its first card (the original deck if the card sits in a filtered deck).
    final deckOf = <int, String>{};
    for (final r in db.select('SELECT nid, did, odid FROM cards ORDER BY ord, id')) {
      final nid = r['nid'] as int;
      if (deckOf.containsKey(nid)) continue;
      final did = (r['odid'] as int) != 0 ? r['odid'] : r['did'];
      final d = decks['$did'];
      deckOf[nid] = d is Map && d['name'] is String ? d['name'] as String : '';
    }

    final out = <AnkiNote>[];
    for (final r in db.select('SELECT id, mid, flds, tags FROM notes ORDER BY id')) {
      final m = models['${r['mid']}'];
      if (m is! Map) continue;
      final flds = (r['flds'] as String).split('\u001f');
      final fieldDefs = m['flds'];
      final names = <String>[];
      if (fieldDefs is List) {
        final sorted = [for (final f in fieldDefs) if (f is Map) f]..sort((a, b) => ((a['ord'] as num?) ?? 0).compareTo((b['ord'] as num?) ?? 0));
        for (final f in sorted) {
          names.add('${f['name'] ?? ''}');
        }
      }
      out.add(AnkiNote(
        model: '${m['name'] ?? ''}',
        fields: flds,
        fieldNames: names,
        cloze: (m['type'] as num?) == 1,
        tags: (r['tags'] as String).split(' ').where((t) => t.isNotEmpty).toList(),
        deck: deckOf[r['id'] as int] ?? '',
      ));
    }
    // A package made without "support older versions" holds one placeholder note asking for a newer Anki.
    if (out.length <= 1 && out.any((n) => n.fields.any((f) => f.contains('update to the latest Anki')))) {
      throw AnkiFileException(_newFormatAdvice);
    }
    if (out.isEmpty) throw AnkiFileException('No cards found in that package.');
    return out;
  } on sql.SqliteException catch (e) {
    // The newest collection layout has no models/decks columns: say so, do not guess.
    if (e.message.contains('no such column') || e.message.contains('no such table')) throw AnkiFileException(_newFormatAdvice);
    throw AnkiFileException('Could not read the cards in that package (${e.message}).');
  } finally {
    db.close();
  }
}
