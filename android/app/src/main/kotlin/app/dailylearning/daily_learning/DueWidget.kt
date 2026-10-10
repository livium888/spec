package app.dailylearning.daily_learning

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews

/** The home-screen widget: how many cards are waiting, one tap into the review, one into a quick five. */
class DueWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        render(context, appWidgetManager, appWidgetIds)
    }

    companion object {
        fun render(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
            val due = DueStore.due(ctx)
            for (id in ids) {
                val v = RemoteViews(ctx.packageName, R.layout.widget_due)
                val headline: String
                val detail: String
                when {
                    due == null -> {
                        headline = ctx.getString(R.string.widget_open)
                        detail = ctx.getString(R.string.widget_open_detail)
                    }
                    due == 0 -> {
                        headline = ctx.getString(R.string.widget_done)
                        detail = ctx.getString(R.string.widget_done_detail)
                    }
                    else -> {
                        headline = ctx.resources.getQuantityString(R.plurals.widget_cards_waiting, due, due)
                        detail = ctx.getString(R.string.widget_minutes, DueStore.minutes(ctx))
                    }
                }
                v.setTextViewText(R.id.widget_headline, headline)
                v.setTextViewText(R.id.widget_detail, detail)
                v.setOnClickPendingIntent(R.id.widget_root, DueStore.pending(ctx, DueStore.ROUTE_REVIEW, 1))
                if (due != null && due > 5) {
                    v.setViewVisibility(R.id.widget_quick, View.VISIBLE)
                    v.setOnClickPendingIntent(R.id.widget_quick, DueStore.pending(ctx, DueStore.ROUTE_QUICK, 2))
                } else {
                    v.setViewVisibility(R.id.widget_quick, View.GONE)
                }
                mgr.updateAppWidget(id, v)
            }
        }
    }
}
