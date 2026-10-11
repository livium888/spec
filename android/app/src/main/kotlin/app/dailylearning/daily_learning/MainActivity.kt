package app.dailylearning.daily_learning

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "daily_learning/pause")
            .setMethodCallHandler { call, result -> pause(call, result) }
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

    /** Pause before apps (D58): settings, the app list, and the free time earned with five cards. */
    private fun pause(call: MethodCall, result: MethodChannel.Result) {
        val ctx = applicationContext
        val now = System.currentTimeMillis()
        when (call.method) {
            "setConfig" -> {
                PauseStore.writeConfig(
                    ctx,
                    call.argument<List<String>>("apps") ?: emptyList(),
                    call.argument<List<String>>("wholeBrowsers") ?: emptyList(),
                    call.argument<String>("rules") ?: "",
                    call.argument<Int>("freeMinutes") ?: 2,
                )
                result.success(null)
            }
            "apps" -> {
                val pm = ctx.packageManager
                val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                val apps = pm.queryIntentActivities(launcher, 0)
                    .map { it.activityInfo.packageName }
                    .distinct()
                    .filter { it != ctx.packageName }
                    .map { p -> mapOf("pkg" to p, "label" to label(p), "browser" to PauseRules.BROWSERS.containsKey(p)) }
                    .sortedBy { (it["label"] as String).lowercase() }
                result.success(apps)
            }
            "status" -> {
                val week = PauseStore.week(ctx, now)
                result.success(mapOf(
                    "on" to serviceOn(),
                    "back" to week[PauseStore.CHOICE_BACK],
                    "open" to week[PauseStore.CHOICE_OPEN],
                    "cards" to week[PauseStore.CHOICE_CARDS],
                ))
            }
            "openAccessibility" -> result.success(start(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)))
            "openAppInfo" -> result.success(start(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + ctx.packageName))))
            "visit" -> {
                val p = PauseStore.pending(ctx, now)
                result.success(p?.let { mapOf("label" to it.label, "atMs" to it.atMs, "freeMinutes" to PauseStore.config(ctx).freeMinutes) })
            }
            "grantAll" -> {
                // Asked by the review screen only after it counted the answers given since the pause (D58).
                val p = PauseStore.pending(ctx, now)
                if (p == null) {
                    result.success(false)
                } else {
                    PauseStore.grantAll(ctx, now + PauseStore.config(ctx).freeMinutes * 60_000L)
                    PauseStore.clearPending(ctx)
                    result.success(PauseActivity.launchTarget(this, p.pkg))
                }
            }
            "dropVisit" -> {
                PauseStore.clearPending(ctx)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun label(pkg: String): String = try {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
    } catch (e: Exception) {
        pkg
    }

    /** Is the pause service switched on in Settings > Accessibility? */
    private fun serviceOn(): Boolean {
        if (PauseService.running) return true
        val enabled = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        val me = ComponentName(this, PauseService::class.java)
        return enabled.split(':').any {
            it.equals(me.flattenToString(), ignoreCase = true) || it.equals(me.flattenToShortString(), ignoreCase = true)
        }
    }

    private fun start(i: Intent): Boolean = try {
        startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: Exception) {
        false
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        capture(intent)
        captureRoute(intent)
    }

    private fun captureRoute(intent: Intent?) {
        val r = intent?.getStringExtra(DueStore.EXTRA_ROUTE)
        if (r == DueStore.ROUTE_REVIEW || r == DueStore.ROUTE_QUICK || r == DueStore.ROUTE_PAUSE) {
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
