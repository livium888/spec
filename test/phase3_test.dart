import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:daily_learning/data/backup/backup_service.dart';
import 'package:daily_learning/data/backup/backup_storage.dart';
import 'package:daily_learning/data/card_edit_service.dart';
import 'package:daily_learning/data/db/database.dart';
import 'package:daily_learning/data/learn_service.dart';
import 'package:daily_learning/data/media_service.dart';
import 'package:daily_learning/data/queue_service.dart';
import 'package:daily_learning/data/settings_repo.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'data_test.dart' show Env;

/// A real 1x1 PNG.
final png = Uint8List.fromList(base64.decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='));
final png2 = Uint8List.fromList([...png.sublist(0, png.length - 12), ...List.filled(12, 0)]); // different bytes, same header

void main() {
  group('MediaService', () {
    late Env e;
    late MediaService media;
    setUp(() {
      e = Env();
      media = MediaService(e.db);
    });

    test('stores a picture once per content and gives the same bytes back', () async {
      final a = await media.save(png);
      final b = await media.save(png);
      expect(a, b);
      expect(a, hasLength(64)); // SHA-256 in hex
      expect((await media.usage()).count, 1);
      expect(await media.bytes(a), png);
      expect(await media.bytes('nope'), isNull);
      expect(await media.save(png2), isNot(a));
      expect((await media.usage()).count, 2);
    });

    test('refuses things that are not pictures, and pictures that are too large', () async {
      await expectLater(media.save(Uint8List.fromList(utf8.encode('definitely not an image at all'))), throwsA(isA<MediaException>()));
      await expectLater(media.save(Uint8List(kMaxImageBytes + 1)..setAll(0, png)), throwsA(isA<MediaException>()));
      expect((await media.usage()).count, 0);
    });

    test('an orphan is deleted, a picture some note still uses is kept', () async {
      await e.addBasic(2);
      final sha = await media.save(png);
      final notes = await e.db.select(e.db.notes).get();
      await (e.db.update(e.db.notes)..where((n) => n.id.equals(notes.first.id))).write(NotesCompanion(fieldsJson: Value('{"front":"q","back":"a","image":"$sha"}')));
      await media.deleteIfOrphan(sha);
      expect(await media.bytes(sha), isNotNull); // still referenced
      await (e.db.update(e.db.notes)..where((n) => n.id.equals(notes.first.id))).write(NotesCompanion(fieldsJson: const Value('{"front":"q","back":"a"}')));
      await media.deleteIfOrphan(sha);
      expect(await media.bytes(sha), isNull);
    });
  });

  group('pictures on cards (edit service)', () {
    late Env e;
    late CardEditService svc;
    late MediaService media;
    setUp(() {
      e = Env();
      svc = CardEditService(e.db, e.settings);
      media = MediaService(e.db);
    });

    Map<String, String> edit(NoteRow n, {String? image, String side = 'front', String alt = ''}) => {
          'front': n.fields['front'] as String,
          'back': n.fields['back'] as String,
          'image': ?image,
          'image_side': image == null || image.isEmpty ? '' : side,
          'image_alt': alt,
        };

    test('attach, show on a chosen side with a description, and read it back as the card sees it', () async {
      await e.addBasic(1);
      final n = (await svc.search()).single;
      final sha = await media.save(png);
      expect(await svc.update(n.noteId, edit(n, image: sha, side: 'back', alt: 'A red square')), isEmpty);
      final card = (await QueueService(e.db, e.settings).cardById((await e.db.select(e.db.cards).get()).single.id))!;
      expect(card.imageSha, sha);
      expect(card.imageOnFront, isFalse);
      expect(card.imageAlt, 'A red square');
      // the card without a picture
      await e.addBasic(1, domain: 'Chem');
      final plain = (await svc.search(query: 'Chem')).single;
      expect(plain.fields['image'], isNull);
    });

    test('removing or replacing a picture cleans up the old one; a shared picture survives', () async {
      await e.addBasic(2);
      final notes = await svc.search();
      final sha = await media.save(png);
      await svc.update(notes[0].noteId, edit(notes[0], image: sha));
      await svc.update(notes[1].noteId, edit(notes[1], image: sha));
      await svc.update(notes[0].noteId, edit(notes[0], image: '')); // removed from one note
      expect(await media.bytes(sha), isNotNull); // the other note still uses it
      final other = await media.save(png2);
      await svc.update(notes[1].noteId, edit(notes[1], image: other)); // replaced
      expect(await media.bytes(sha), isNull);
      expect(await media.bytes(other), isNotNull);
      await svc.delete(notes[1].noteId); // deleting the card deletes its now-unused picture
      expect(await media.bytes(other), isNull);
      expect((await media.usage()).count, 0);
    });

    test('a too-long description is refused and nothing changes', () async {
      await e.addBasic(1);
      final n = (await svc.search()).single;
      final sha = await media.save(png);
      final errors = await svc.update(n.noteId, edit(n, image: sha, alt: 'x' * 301));
      expect(errors.single, contains('description'));
      expect((await svc.note(n.noteId))!.fields['image'], isNull);
    });

    test('editing never touches scheduling: replay == live with pictures attached', () async {
      await e.addBasic(1);
      final c = (await e.db.select(e.db.cards).get()).single;
      await e.review.review(cardId: c.id, rating: 3, durationMs: 800, now: DateTime.utc(2025, 1, 1, 9));
      final n = (await svc.search()).single;
      await svc.update(n.noteId, edit(n, image: await media.save(png)));
      expect(await e.review.rebuildAll(apply: false), isEmpty);
    });
  });

  group('pictures travel with backups', () {
    test('export, wipe, restore: the picture and the card that points to it come back', () async {
      final tmp = Directory.systemTemp.createTempSync('p3backup');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final dbFile = File('${tmp.path}/learning.db');
      final backupDir = Directory('${tmp.path}/saf')..createSync();
      var db = AppDatabase(NativeDatabase(dbFile));
      final settings = SettingsRepo(db);
      await db.into(db.domains).insert(DomainsCompanion.insert(name: 'Art', createdAt: 1));
      final sha = await MediaService(db).save(png);
      await db.into(db.notes).insert(NotesCompanion.insert(
          guid: 'g1', domainId: 1, type: 'basic', fieldsJson: '{"front":"Who painted this?","back":"Monet","image":"$sha"}', createdAt: 1));
      await db.into(db.cards).insert(CardsCompanion.insert(noteId: 1, due: 1));
      await db.into(db.fsrsParamsTable).insert(FsrsParamsTableCompanion.insert(createdAt: 0, version: 'x', paramsJson: '{}', desiredRetention: 0.9));

      final storage = DirectoryBackupStorage(backupDir);
      expect(await BackupService(db, settings).export(storage, tmp, now: DateTime.utc(2025, 1, 1)), isNull);
      await db.close();
      dbFile.deleteSync();
      db = AppDatabase(NativeDatabase(dbFile));
      expect((await MediaService(db).usage()).count, 0);

      final f = (await storage.list()).single;
      final fetched = File('${tmp.path}/fetched');
      await storage.readToFile(f, fetched);
      await BackupService.restore(
        source: fetched,
        dbFile: dbFile,
        tmpDir: tmp,
        closeDb: () => db.close(),
        reopen: () async => db = AppDatabase(NativeDatabase(dbFile)),
      );
      expect(await MediaService(db).bytes(sha), png);
      final note = await db.select(db.notes).getSingle();
      expect(note.fieldsJson, contains(sha));
      await db.close();
    });
  });

  group('read-aloud settings', () {
    test('a subject keeps its language and which side is in it; off clears it', () async {
      final e = Env();
      await e.addBasic(1, domain: 'Spanish');
      final id = (await e.db.select(e.db.domains).getSingle()).id;
      final learn = LearnService(e.db, e.settings, QueueService(e.db, e.settings));
      var d = await e.db.select(e.db.domains).getSingle();
      expect((d.speechLang, d.speechSide), (null, 'back'));
      await learn.setSubjectSpeech(id, 'es-ES', side: 'front');
      d = await e.db.select(e.db.domains).getSingle();
      expect((d.speechLang, d.speechSide), ('es-ES', 'front'));
      await learn.setSubjectSpeech(id, 'es-ES', side: 'nonsense'); // anything unknown falls back to the answer side
      expect((await e.db.select(e.db.domains).getSingle()).speechSide, 'back');
      await learn.setSubjectSpeech(id, null);
      expect((await e.db.select(e.db.domains).getSingle()).speechLang, isNull);
    });
  });
}
