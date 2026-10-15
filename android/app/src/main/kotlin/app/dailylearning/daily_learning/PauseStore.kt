package app.dailylearning.daily_learning

import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock

/**
 * "Pause before apps" (D58): what to watch, the free-time passes, a pause waiting for its five cards, and a
 * weekly count of what the learner chose. The learner's choices live in the app's own settings (they are in the
 * backup); the app copies them here on every change and at start, because this service runs without the app.
 * Nothing here leaves the phone. Free time is only ever granted by this app's own code: the pause screen (not
 * reachable from other apps) and the review screen, after counting real answers.
 */
object PauseStore {
    private const val FILE = "daily_learning_pause"
    const val KEY_APPS = "apps"
    const val KEY_WHOLE = "whole_browsers"
    const val KEY_RULES = "rules"
    const val KEY_FREE = "free_minutes"
    const val KEY_RISING = "rising_wait"
    const val KEY_LIMIT = "open_limit"
    const val KEY_SHOW_NEXT = "show_next"
    const val KEY_ROLLOVER = "rollover_hour"
    const val KEY_MOVES = "moves"
    const val KEY_CARDS_EVERY = "cards_every"
    const val KEY_TALK_MIN = "talk_minutes"
    const val KEY_TALK_OFFERED = "talk_offered"
    const val KEY_ALL_UNTIL = "all_until"
    private const val PASS = "pass:"
    private const val PENDING_KEY = "pending_key"
    private const val PENDING_LABEL = "pending_label"
    private const val PENDING_PKG = "pending_pkg"
    private const val PENDING_AT = "pending_at"
    private const val PENDING_KIND = "pending_kind"
    private const val TALK_NOTE = "talk_note"
    private const val TALK_ORD = "talk_ord"
    private const val TALK_ELAPSED = "talk_start_elapsed"
    private const val TALK_WALL = "talk_start_wall"

    /** The least time between sharing the Socratic prompt and opening the app (D66), on the clock that keeps counting in sleep. */
    const val TALK_MIN_SECONDS = 180

    /** Once a conversation has started the visit lives an hour from then, however long the pause had been waiting. */
    private const val TALK_MAX_MS = 60 * 60 * 1000L

    const val KIND_CARDS = "cards"
    const val KIND_TALK = "talk"

    /** A "Do 5 cards" older than this earns nothing (the learner went away). */
    private const val PENDING_MAX_MS = 30 * 60 * 1000L

    const val CHOICE_BACK = "back"
    const val CHOICE_OPEN = "open"
    const val CHOICE_CARDS = "cards"
    const val CHOICE_MOVE = "move"
    const val CHOICE_TALK = "talk"

    data class Config(
        val apps: Set<String>,
        val wholeBrowsers: Set<String>,
        val rules: List<PauseRules.Rule>,
        val freeMinutes: Int,
        val rising: Boolean = true,
        val openLimit: Int = 0,
        val showNext: Boolean = true,
        val rolloverHour: Int = 4,
        val moves: List<Move> = emptyList(),
        val cardsEvery: Int = 2,
        val talkMinutes: Int = 5,
        val talkOffered: Boolean = false,
    )

    /** An exercise offered as "Move first" (D61): a name and how many seconds the countdown runs. */
    data class Move(val name: String, val seconds: Int)

    /** Mirror of parsePauseMove / pauseMovesOf (lib/domain/pause_moves.dart); the Dart side holds the tested reference. */
    fun parseMoves(stored: String?): List<Move> {
        val out = mutableListOf<Move>()
        for (line in (stored ?: "").split('\n')) {
            val bar = line.lastIndexOf('|')
            if (bar <= 0) continue
            val name = line.substring(0, bar).replace(Regex("[ \\t\\r\\n\\u000C\\u000B]+"), " ").trim()
            val seconds = line.substring(bar + 1).trim().toIntOrNull() ?: continue
            if (name.isEmpty() || name.length > 40 || name.contains('|') || name.any { it.isISOControl() || it == '\u2028' || it == '\u2029' }) continue
            if (seconds < 10 || seconds > 300) continue
            if (out.none { it.name.equals(name, ignoreCase = true) }) out += Move(name, seconds)
            if (out.size >= 12) break
        }
        return out
    }

    /** A pause waiting for what it asked for. [kind] is `cards` or `talk`; for a talk visit, [noteId] is set once the conversation starts. */
    data class Pending(val key: String, val label: String, val pkg: String, val atMs: Long, val kind: String = KIND_CARDS, val noteId: Int? = null, val ord: Int = 0, val started: Boolean = false)

    fun prefs(ctx: Context): SharedPreferences = ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun writeConfig(
        ctx: Context, apps: List<String>, whole: List<String>, rules: String, freeMinutes: Int,
        rising: Boolean, openLimit: Int, showNext: Boolean, rolloverHour: Int, moves: String, cardsEvery: Int,
        talkMinutes: Int, talkOffered: Boolean,
    ) {
        prefs(ctx).edit()
            .putStringSet(KEY_APPS, apps.toSet())
            .putStringSet(KEY_WHOLE, whole.toSet())
            .putString(KEY_RULES, rules)
            .putInt(KEY_FREE, freeMinutes.coerceIn(1, 60))
            .putBoolean(KEY_RISING, rising)
            .putInt(KEY_LIMIT, openLimit.coerceIn(0, 50))
            .putBoolean(KEY_SHOW_NEXT, showNext)
            .putInt(KEY_ROLLOVER, rolloverHour.coerceIn(0, 23))
            .putString(KEY_MOVES, moves)
            .putInt(KEY_CARDS_EVERY, cardsEvery.coerceIn(0, 3))
            .putInt(KEY_TALK_MIN, talkMinutes.coerceIn(1, 60))
            .putBoolean(KEY_TALK_OFFERED, talkOffered)
            .apply()
    }

    fun config(ctx: Context): Config {
        val p = prefs(ctx)
        return Config(
            apps = p.getStringSet(KEY_APPS, emptySet())?.toSet() ?: emptySet(),
            wholeBrowsers = p.getStringSet(KEY_WHOLE, emptySet())?.toSet() ?: emptySet(),
            rules = PauseRules.parseRules(p.getString(KEY_RULES, "")),
            freeMinutes = p.getInt(KEY_FREE, 2).coerceIn(1, 60),
            rising = p.getBoolean(KEY_RISING, true),
            openLimit = p.getInt(KEY_LIMIT, 0).coerceIn(0, 50),
            showNext = p.getBoolean(KEY_SHOW_NEXT, true),
            rolloverHour = p.getInt(KEY_ROLLOVER, 4).coerceIn(0, 23),
            moves = parseMoves(p.getString(KEY_MOVES, "")),
            cardsEvery = p.getInt(KEY_CARDS_EVERY, 2).coerceIn(0, 3),
            talkMinutes = p.getInt(KEY_TALK_MIN, 5).coerceIn(1, 60),
            talkOffered = p.getBoolean(KEY_TALK_OFFERED, false),
        )
    }

    // ---- free time ---------------------------------------------------------------------------------------

    /** Free time for everything watched (earned with cards). */
    fun grantAll(ctx: Context, untilMs: Long) {
        prefs(ctx).edit().putLong(KEY_ALL_UNTIL, untilMs).apply()
    }

    /** Free time for one app or one site (after the breathing pause). */
    fun grant(ctx: Context, key: String, untilMs: Long) {
        val p = prefs(ctx)
        val e = p.edit()
        // Drop expired passes so the file stays small.
        val now = System.currentTimeMillis()
        for ((k, v) in p.all) {
            if (k.startsWith(PASS) && (v as? Long ?: 0L) < now) e.remove(k)
        }
        e.putLong(PASS + key, untilMs).apply()
    }

    fun isFree(ctx: Context, key: String, now: Long): Boolean {
        val p = prefs(ctx)
        return p.getLong(KEY_ALL_UNTIL, 0L) > now || p.getLong(PASS + key, 0L) > now
    }

    /** The next moment a pass runs out (to look again then), or null. */
    fun nextExpiry(ctx: Context, now: Long): Long? =
        prefs(ctx).all.filter { (k, _) -> k == KEY_ALL_UNTIL || k.startsWith(PASS) }
            .values.mapNotNull { it as? Long }.filter { it > now }.minOrNull()

    // ---- a pause waiting for its five cards ------------------------------------------------------------------

    fun setPending(ctx: Context, key: String, label: String, pkg: String, atMs: Long, kind: String = KIND_CARDS) {
        prefs(ctx).edit().putString(PENDING_KEY, key).putString(PENDING_LABEL, label)
            .putString(PENDING_PKG, pkg).putLong(PENDING_AT, atMs).putString(PENDING_KIND, kind)
            .remove(TALK_NOTE).remove(TALK_ORD).remove(TALK_ELAPSED).remove(TALK_WALL).apply()
    }

    /**
     * The pause waiting for its cards or its conversation, or null once it has run out. A cards visit lives
     * [PENDING_MAX_MS] from the pause; a conversation, an hour from when it started (a long chat must not run out
     * before the learner is back).
     */
    fun pending(ctx: Context, now: Long, elapsedNow: Long = SystemClock.elapsedRealtime()): Pending? {
        val p = prefs(ctx)
        val at = p.getLong(PENDING_AT, 0L)
        if (at <= 0L || now < at) return null
        val kind = if (p.getString(PENDING_KIND, KIND_CARDS) == KIND_TALK) KIND_TALK else KIND_CARDS
        val wall = p.getLong(TALK_WALL, 0L)
        val startElapsed = p.getLong(TALK_ELAPSED, 0L)
        // A reboot makes the elapsed clock start again: a start in the "future" is no start at all.
        val started = kind == KIND_TALK && startElapsed > 0L && wall > 0L && elapsedNow >= startElapsed
        if (started) {
            if (now < wall || now - wall > TALK_MAX_MS) return null
        } else if (now - at > PENDING_MAX_MS) {
            return null
        }
        val key = p.getString(PENDING_KEY, null) ?: return null
        val pkg = p.getString(PENDING_PKG, null) ?: return null
        val noteId = if (started) p.getInt(TALK_NOTE, -1).takeIf { it > 0 } else null
        return Pending(key, p.getString(PENDING_LABEL, null) ?: pkg, pkg, at, kind, noteId, p.getInt(TALK_ORD, 0), started && noteId != null)
    }

    /** The learner shared or copied the Socratic prompt: keep the card and start the clock. Only the first call counts. */
    fun startTalk(ctx: Context, noteId: Int, ord: Int, now: Long, elapsedNow: Long = SystemClock.elapsedRealtime()) {
        val p = pending(ctx, now, elapsedNow) ?: return
        if (p.kind != KIND_TALK || p.started || noteId <= 0) return
        prefs(ctx).edit().putInt(TALK_NOTE, noteId).putInt(TALK_ORD, ord).putLong(TALK_ELAPSED, elapsedNow.coerceAtLeast(1L)).putLong(TALK_WALL, now).apply()
    }

    /**
     * Seconds before the app may be opened, from the elapsed-realtime start. Not started, or a clock that went backwards
     * (a reboot), means the whole minimum. Mirror of nothing: the app only displays this number.
     */
    fun talkSecondsLeft(startElapsed: Long, nowElapsed: Long): Int {
        if (startElapsed <= 0L || nowElapsed < startElapsed) return TALK_MIN_SECONDS
        val passed = (nowElapsed - startElapsed) / 1000
        return (TALK_MIN_SECONDS - passed).coerceIn(0L, TALK_MIN_SECONDS.toLong()).toInt()
    }

    fun talkSecondsLeft(ctx: Context, nowElapsed: Long = SystemClock.elapsedRealtime()): Int =
        talkSecondsLeft(prefs(ctx).getLong(TALK_ELAPSED, 0L), nowElapsed)

    fun clearPending(ctx: Context) {
        prefs(ctx).edit().remove(PENDING_KEY).remove(PENDING_LABEL).remove(PENDING_PKG).remove(PENDING_AT).remove(PENDING_KIND)
            .remove(TALK_NOTE).remove(TALK_ORD).remove(TALK_ELAPSED).remove(TALK_WALL).apply()
    }

    // ---- the log of pauses (D59) ------------------------------------------------------------------------------
    // One line per event: ms<TAB>kind<TAB>key. Read by the app for Progress and Today (lib/domain/pause_stats.dart
    // parses it and skips damaged lines). Kept 60 days, at most 4000 lines; never leaves the phone.

    private const val KEY_LOG = "log"
    private const val LOG_DAYS = 60L
    private const val LOG_MAX = 4000

    const val KIND_SHOWN = "shown"
    const val KIND_AGAIN = "again"
    const val KIND_EARNED = "earned"

    fun log(ctx: Context, kind: String, key: String, now: Long) {
        val p = prefs(ctx)
        val cutoff = now - LOG_DAYS * 86_400_000L
        val lines = (p.getString(KEY_LOG, "") ?: "").split('\n')
            .filter { l -> l.isNotEmpty() && (l.substringBefore('\t').toLongOrNull() ?: 0L) >= cutoff }
            .takeLast(LOG_MAX - 1)
        val clean = key.replace('\t', ' ').replace('\n', ' ').take(300)
        val e = p.edit().putString(KEY_LOG, (lines + "$now\t$kind\t$clean").joinToString("\n"))
        // Counters from the first version of the pause: replaced by this log.
        for (k in p.all.keys) if (k.startsWith("n:")) e.remove(k)
        e.apply()
    }

    fun logText(ctx: Context): String = prefs(ctx).getString(KEY_LOG, "") ?: ""

    /** How many [kind] events [key] had since the app's day began (rolls over at the learner's hour, local time). */
    fun countToday(ctx: Context, kind: String, key: String, now: Long): Int {
        val start = dayStartMs(now, config(ctx).rolloverHour)
        return logText(ctx).split('\n').count { l ->
            val p = l.split('\t')
            p.size == 3 && p[1] == kind && p[2] == key && (p[0].toLongOrNull() ?: 0L) >= start
        }
    }

    /**
     * Cards come first (D62). Openings by breathing or an exercise since the last real cards session (`earned`), over
     * every app and site, from the start of the app day; the test pause is ignored. Mirror of pauseOpeningsSinceCards
     * (lib/domain/pause_stats.dart), which reads the same lines: a damaged line is skipped.
     */
    fun openingsSinceCards(ctx: Context, now: Long): Int = openingsSinceCards(logText(ctx), dayStartMs(now, config(ctx).rolloverHour))

    fun openingsSinceCards(log: String, dayStart: Long): Int {
        var n = 0
        for (l in log.split('\n')) {
            val p = l.split('\t')
            if (p.size != 3 || p[2].isEmpty() || p[2].length > 300) continue
            if (p[0].isEmpty() || p[0].length > 18 || !p[0].all { it in '0'..'9' }) continue // plain digits, as the Dart reader
            val at = p[0].toLong()
            if (at < dayStart || p[2].startsWith("test:")) continue
            when (p[1]) {
                KIND_EARNED -> n = 0
                CHOICE_OPEN, CHOICE_MOVE, CHOICE_TALK -> n++
            }
        }
        return n
    }

    /** Mirror of DayClock.dayStartMs (lib/domain/day_clock.dart): the day turns at [rolloverHour] local time. */
    fun dayStartMs(now: Long, rolloverHour: Int): Long {
        val day = 86_400_000L
        val shift = java.util.TimeZone.getDefault().getOffset(now).toLong() - rolloverHour * 3_600_000L
        return Math.floorDiv(now + shift, day) * day - shift
    }

    /** Mirror of pauseWaitSeconds (lib/domain/pause_stats.dart). */
    fun waitSeconds(shownToday: Int, rising: Boolean): Int {
        if (!rising || shownToday <= 1) return 10
        return (10 + 5 * (shownToday - 1)).coerceAtMost(60)
    }
}
