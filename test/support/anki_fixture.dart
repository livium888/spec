import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

/// D50: importing from Anki. The file is UNTRUSTED; only content comes across, as new cards.
final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0, 1, 2, 3, 4]);

/// A legacy-format collection with a basic note type, a cloze type and a custom one, and a few notes.
Uint8List collection({List<List<Object?>>? notes, Map<String, Object?>? models, bool dummy = false}) {
  final dir = Directory.systemTemp.createTempSync('ankifx');
  final f = File('${dir.path}/c.db');
  final db = sql.sqlite3.open(f.path);
  db.execute('CREATE TABLE col (id integer, crt integer, mod integer, scm integer, ver integer, dty integer, usn integer, ls integer, conf text, models text, decks text, dconf text, tags text)');
  db.execute('CREATE TABLE notes (id integer primary key, guid text, mid integer, mod integer, usn integer, tags text, flds text, sfld text, csum integer, flags integer, data text)');
  db.execute('CREATE TABLE cards (id integer primary key, nid integer, did integer, ord integer, mod integer, usn integer, type integer, queue integer, due integer, ivl integer, factor integer, reps integer, lapses integer, left integer, odue integer, odid integer, flags integer, data text)');
  final defaultModels = {
    '1': {'name': 'Basic', 'type': 0, 'flds': [{'name': 'Front', 'ord': 0}, {'name': 'Back', 'ord': 1}]},
    '2': {'name': 'Cloze', 'type': 1, 'flds': [{'name': 'Text', 'ord': 0}, {'name': 'Back Extra', 'ord': 1}]},
    '3': {'name': 'Vocab', 'type': 0, 'flds': [{'name': 'Word', 'ord': 0}, {'name': 'Meaning', 'ord': 1}, {'name': 'Example', 'ord': 2}]},
    '4': {'name': 'Image Occlusion', 'type': 1, 'flds': [{'name': 'Occlusion', 'ord': 0}, {'name': 'Image', 'ord': 1}]},
  };
  final decks = {'1': {'name': 'Default'}, '10': {'name': 'Biology::Cells'}, '11': {'name': 'Spanish'}};
  db.execute("INSERT INTO col VALUES (1,0,0,0,11,0,0,0,'{}',?,?,'{}','{}')", [jsonEncode(models ?? defaultModels), jsonEncode(decks)]);
  final rows = notes ??
      [
        [1, 1, 'cell membrane', 'What surrounds a cell?\u001fThe <b>membrane</b>&nbsp;layer', 10],
        [2, 2, '', 'The nucleus holds {{c1::DNA}} and the {{c2::nucleolus}}.\u001fExtra <i>detail</i>', 10],
        [3, 3, 'verbs', 'hablar\u001fto speak\u001fYo hablo español.', 11],
        [4, 1, '', 'Look: <img src="cell.png">\u001fA cell [sound:x.mp3]', 10],
        [5, 4, '', 'xx\u001f<img src="cell.png">', 10],
        [6, 1, '', '\u001f', 10],
      ];
  var cid = 100;
  for (final r in rows) {
    db.execute("INSERT INTO notes VALUES (?,?,?,0,0,?,?,'',0,0,'')", [r[0], 'g${r[0]}', r[1], r[2], r[3]]);
    db.execute("INSERT INTO cards VALUES (?,?,?,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'')", [cid++, r[0], r[4]]);
  }
  if (dummy) {
    db.execute('DELETE FROM notes');
    db.execute("INSERT INTO notes VALUES (1,'g',1,0,0,'','Please update to the latest Anki version\u001fx','',0,0,'')");
  }
  db.close();
  final b = f.readAsBytesSync();
  dir.deleteSync(recursive: true);
  return b;
}

File apkg(Directory dir, Map<String, List<int>> files, {String name = 'deck.apkg'}) {
  final a = Archive();
  files.forEach((n, b) => a.addFile(ArchiveFile(n, b.length, b)));
  final f = File('${dir.path}/$name')..writeAsBytesSync(ZipEncoder().encode(a));
  return f;
}

