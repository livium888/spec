package app.dailylearning.daily_learning

import android.app.PendingIntent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/** A Quick Settings tile: how many cards are waiting; one tap opens the review. */
class DueTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        update()
    }

    private fun update() {
        val tile = qsTile ?: return
        val due = DueStore.due(this)
        tile.label = getString(R.string.tile_label)
        if (Build.VERSION.SDK_INT >= 29) {
            tile.subtitle = when {
                due == null -> getString(R.string.tile_open)
                due == 0 -> getString(R.string.tile_done)
                else -> getString(R.string.tile_due, due)
            }
        }
        tile.state = if (due != null && due > 0) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        val intent = DueStore.openIntent(this, DueStore.ROUTE_REVIEW)
        if (Build.VERSION.SDK_INT >= 34) {
            val pi = PendingIntent.getActivity(
                this, 3, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            startActivityAndCollapse(pi)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
