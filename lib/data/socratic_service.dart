import '../domain/day_clock.dart';
import '../domain/socratic_pick.dart';
import '../domain/talk_prompt.dart' show TalkCard, kTalkedThroughTag;
import 'db/database.dart';
import 'talk_service.dart';

/// Cards that were reviewed at least once and are in play: not new, not suspended or retired, not a problem.
const _inPlay = "c.state != 'new' AND c.suspended = 0 AND c.retired_at IS NULL AND n.type != 'problem'";

/// Whether there is any card to talk about (the pause only offers the way when there is).
Future<bool> socraticHasCandidate(AppDatabase db) async {
  final r = await db.customSelect('SELECT 1 AS x FROM card c JOIN note n ON n.id = c.note_id WHERE $_inPlay LIMIT 1').get();
  return r.isNotEmpty;
}

/// The Socratic way out of the pause (D66): which card to talk about, read from the learner's own reviews. Nothing is
/// sent from here (the screen hands the prompt to the share sheet or the clipboard) and the schedule is not touched.
class SocraticService {
  SocraticService(this.db, this.talk);
  final AppDatabase db;
  final TalkService talk;

  Future<bool> hasCandidate() => socraticHasCandidate(db);

  Future<List<SocraticCandidate>> candidates() async {
    final rows = await db.customSelect(
      'SELECT c.note_id AS note, c.ord AS ord, c.lapses AS lapses, c.difficulty AS d, c.stability AS s, n.tags AS tags '
      'FROM card c JOIN note n ON n.id = c.note_id WHERE $_inPlay',
    ).get();
    return [
      for (final r in rows)
        SocraticCandidate(
          noteId: r.read<int>('note'),
          ord: r.read<int>('ord'),
          lapses: r.read<int>('lapses'),
          difficulty: r.read<double?>('d'),
          stability: r.read<double?>('s'),
          talkedThrough: ' ${r.read<String>('tags')} '.contains(' $kTalkedThroughTag '),
        ),
    ];
  }

  /// The card for this pause: stable within it, different on the next ([talksToday] is the day's conversations so far).
  Future<SocraticCandidate?> pick({required DateTime now, required DayClock clock, required int talksToday}) async =>
      pickSocraticCard(await candidates(), seed: socraticSeed(dayIndex: clock.dayIndex(now.toUtc()), talksToday: talksToday));

  Future<TalkCard?> load(int noteId, int ord) => talk.load(noteId, ord);
}
