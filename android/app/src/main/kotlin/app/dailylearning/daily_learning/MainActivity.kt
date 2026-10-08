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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        capture(intent)
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
    }

    private fun capture(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type?.startsWith("text/") == true) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!text.isNullOrBlank()) sharedText = text
        }
    }
}
