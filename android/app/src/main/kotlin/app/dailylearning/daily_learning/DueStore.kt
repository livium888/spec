package app.dailylearning.daily_learning

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService

/**
 * How many cards are waiting today, written by the app (Dart) and read by the home-screen widget and the
 * Quick Settings tile. A number is only shown for the day it was written for: once that day is over the
 * widget and tile say "open the app" instead of showing yesterday's count.
 */
object DueStore {
    const val EXTRA_ROUTE = "dl_route"
    const val ROUTE_REVIEW = "review"
    const val ROUTE_QUICK = "quick5"
    private const val FILE = "daily_learning_due"

    fun write(ctx: Context, due: Int, minutes: Int, dayEndMs: Long) {
        ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit()
            .putInt("due", due)
            .putInt("minutes", minutes)
            .putLong("dayEnd", dayEndMs)
            .apply()
        refresh(ctx)
    }

    /** Cards waiting for today, or null when nothing is known for the current day. */
    fun due(ctx: Context): Int? {
        val p = ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        if (!p.contains("due")) return null
        if (System.currentTimeMillis() >= p.getLong("dayEnd", 0L)) return null
        return p.getInt("due", 0)
    }

    fun minutes(ctx: Context): Int =
        ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE).getInt("minutes", 1)

    /** Redraw the widget(s) and ask the system to refresh the tile. */
    fun refresh(ctx: Context) {
        try {
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, DueWidget::class.java))
            if (ids.isNotEmpty()) DueWidget.render(ctx, mgr, ids)
            TileService.requestListeningState(ctx, ComponentName(ctx, DueTileService::class.java))
        } catch (e: Exception) {
            // A widget or tile that cannot refresh must never break the app.
        }
    }

    /** The intent that opens the app straight into the review ([route] is one of the ROUTE_ values). */
    fun openIntent(ctx: Context, route: String): Intent =
        Intent(ctx, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_ROUTE, route)
        }

    fun pending(ctx: Context, route: String, requestCode: Int): PendingIntent =
        PendingIntent.getActivity(
            ctx,
            requestCode,
            openIntent(ctx, route),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
}
