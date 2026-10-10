package app.dailylearning.daily_learning

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives text another app shares to Daily Learning (an AI's answer) and keeps it until the
 * Dart side asks for it. The text is untrusted: Dart only ever shows it in the import preview.
 */
class MainActivity : FlutterActivity() {
    private var sharedText: String? = null

    // Where a shortcut, the widget, the Quick Settings tile or the reminder asked the app to open (only the
    // values DueStore names are accepted; anything else an outside app sends is ignored).
    private var route: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        capture(intent)
        captureRoute(intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "daily_learning/launch")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeRoute" -> {
                        result.success(route)
                        route = null
                    }
                    "publishDue" -> {
                        val due = call.argument<Int>("due") ?: 0
                        val minutes = call.argument<Int>("minutes") ?: 1
                        val dayEnd = call.argument<Number>("dayEndMs")?.toLong() ?: 0L
                        DueStore.write(applicationContext, due, minutes, dayEnd)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "daily_learning/share")
            .setMethodCallHandler { call, result ->
                if (call.method == "takeSharedText") {
                    result.success(sharedText)
                    sharedText = null
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        capture(intent)
        captureRoute(intent)
    }

    private fun captureRoute(intent: Intent?) {
        val r = intent?.getStringExtra(DueStore.EXTRA_ROUTE)
        if (r == DueStore.ROUTE_REVIEW || r == DueStore.ROUTE_QUICK) {
            route = r
            intent?.removeExtra(DueStore.EXTRA_ROUTE) // so recreating the activity does not open it twice
        }
    }

    private fun capture(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type?.startsWith("text/") == true) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!text.isNullOrBlank()) sharedText = text
        }
    }
}
