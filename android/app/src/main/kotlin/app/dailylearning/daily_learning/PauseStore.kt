package app.dailylearning.daily_learning

import android.content.Context
import android.content.SharedPreferences

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
    const val KEY_ALL_UNTIL = "all_until"
    private const val PASS = "pass:"
    private const val PENDING_KEY = "pending_key"
    private const val PENDING_LABEL = "pending_label"
    private const val PENDING_PKG = "pending_pkg"
    private const val PENDING_AT = "pending_at"

    /** A "Do 5 cards" older than this earns nothing (the learner went away). */
    private const val PENDING_MAX_MS = 30 * 60 * 1000L

    const val CHOICE_BACK = "back"
    const val CHOICE_OPEN = "open"
    const val CHOICE_CARDS = "cards"

    data class Config(
        val apps: Set<String>,
        val wholeBrowsers: Set<String>,
        val rules: List<PauseRules.Rule>,
        val freeMinutes: Int,
        val rising: Boolean = true,
        val openLimit: Int = 0,
        val showNext: Boolean = true,
        val rolloverHour: Int = 4,
    )

    data class Pending(val key: String, val label: String, val pkg: String, val atMs: Long)

    fun prefs(ctx: Context): SharedPreferences = ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun writeConfig(
        ctx: Context, apps: List<String>, whole: List<String>, rules: String, freeMinutes: Int,
        rising: Boolean, openLimit: Int, showNext: Boolean, rolloverHour: Int,
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

    fun setPending(ctx: Context, key: String, label: String, pkg: String, atMs: Long) {
        prefs(ctx).edit().putString(PENDING_KEY, key).putString(PENDING_LABEL, label)
            .putString(PENDING_PKG, pkg).putLong(PENDING_AT, atMs).apply()
    }

    fun pending(ctx: Context, now: Long): Pending? {
        val p = prefs(ctx)
        val at = p.getLong(PENDING_AT, 0L)
        if (at <= 0L || now - at > PENDING_MAX_MS || now < at) return null
        val key = p.getString(PENDING_KEY, null) ?: return null
        val pkg = p.getString(PENDING_PKG, null) ?: return null
        return Pending(key, p.getString(PENDING_LABEL, null) ?: pkg, pkg, at)
    }

    fun clearPending(ctx: Context) {
        prefs(ctx).edit().remove(PENDING_KEY).remove(PENDING_LABEL).remove(PENDING_PKG).remove(PENDING_AT).apply()
    }

    // ---- the log of pauses (D59) ------------------------------------------------------------------------------
    // One line per event: ms<TAB>kind<TAB>key. Read by the app for Progress and Today (lib/domain/pause_stats.dart
    // parses it and skips damaged lines). Kept 60 days, at most 4000 lines; never leaves the phone.

    private const val KEY_LOG = "log"
    private const val LOG_DAYS = 60L
    private const val LOG_MAX = 4000

    const val KIND_SHOWN = "shown"

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
