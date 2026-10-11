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

    data class Config(val apps: Set<String>, val wholeBrowsers: Set<String>, val rules: List<PauseRules.Rule>, val freeMinutes: Int)

    data class Pending(val key: String, val label: String, val pkg: String, val atMs: Long)

    fun prefs(ctx: Context): SharedPreferences = ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun writeConfig(ctx: Context, apps: List<String>, whole: List<String>, rules: String, freeMinutes: Int) {
        prefs(ctx).edit()
            .putStringSet(KEY_APPS, apps.toSet())
            .putStringSet(KEY_WHOLE, whole.toSet())
            .putString(KEY_RULES, rules)
            .putInt(KEY_FREE, freeMinutes.coerceIn(1, 60))
            .apply()
    }

    fun config(ctx: Context): Config {
        val p = prefs(ctx)
        return Config(
            apps = p.getStringSet(KEY_APPS, emptySet())?.toSet() ?: emptySet(),
            wholeBrowsers = p.getStringSet(KEY_WHOLE, emptySet())?.toSet() ?: emptySet(),
            rules = PauseRules.parseRules(p.getString(KEY_RULES, "")),
            freeMinutes = p.getInt(KEY_FREE, 2).coerceIn(1, 60),
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

    // ---- what the learner chose, per day (kept two weeks) ----------------------------------------------------

    private fun dayOf(ms: Long): Long = ms / 86_400_000L

    fun count(ctx: Context, choice: String, now: Long) {
        val p = prefs(ctx)
        val today = dayOf(now)
        val e = p.edit()
        for (k in p.all.keys) {
            if (k.startsWith("n:")) {
                val d = k.split(':').getOrNull(1)?.toLongOrNull()
                if (d == null || d < today - 14) e.remove(k)
            }
        }
        val key = "n:$today:$choice"
        e.putInt(key, p.getInt(key, 0) + 1).apply()
    }

    /** Choices over the last 7 days: back, open, cards. */
    fun week(ctx: Context, now: Long): Map<String, Int> {
        val today = dayOf(now)
        val out = mutableMapOf(CHOICE_BACK to 0, CHOICE_OPEN to 0, CHOICE_CARDS to 0)
        for ((k, v) in prefs(ctx).all) {
            if (!k.startsWith("n:")) continue
            val parts = k.split(':')
            val d = parts.getOrNull(1)?.toLongOrNull() ?: continue
            val c = parts.getOrNull(2) ?: continue
            if (d > today - 7 && d <= today && out.containsKey(c)) out[c] = out[c]!! + (v as? Int ?: 0)
        }
        return out
    }
}
