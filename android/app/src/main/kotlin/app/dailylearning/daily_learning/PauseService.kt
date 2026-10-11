package app.dailylearning.daily_learning

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent

/**
 * "Pause before apps" (D58). Android tells this service when one of the watched apps comes to the front; it then
 * shows the pause screen, unless free time is running.
 *
 * What it can see, and what it looks at:
 * - Events only from the watched packages (the learner's apps, plus supported browsers when there are site rules
 *   or a whole browser is watched). With nothing to watch, only this app's own package is listed: an empty list
 *   would mean "every app".
 * - In a watched app: only the package name of the event. Nothing on the screen is read.
 * - In a supported browser: the text of the address bar, found by its view id, never by walking the screen; it is
 *   compared with the site rules and dropped. While the bar has focus it holds the learner's typing, so it is
 *   skipped.
 * Android could let this service read more than that (it can read window content); this code does not.
 */
class PauseService : AccessibilityService(), SharedPreferences.OnSharedPreferenceChangeListener {
    private val main = Handler(Looper.getMainLooper())
    private var config: PauseStore.Config? = null
    private var browserPkg: String? = null
    private var browserCheckPending = false
    private val browserCheck = Runnable {
        browserCheckPending = false
        browserPkg?.let { check(it, fromWindowChange = false) }
    }
    private val expiryCheck = Runnable { recheckFront() }

    override fun onServiceConnected() {
        super.onServiceConnected()
        running = true
        PauseStore.prefs(this).registerOnSharedPreferenceChangeListener(this)
        reload()
    }

    override fun onDestroy() {
        running = false
        PauseStore.prefs(this).unregisterOnSharedPreferenceChangeListener(this)
        main.removeCallbacksAndMessages(null)
        browserCheckPending = false
        super.onDestroy()
    }

    override fun onInterrupt() {}

    override fun onSharedPreferenceChanged(p: SharedPreferences?, key: String?) {
        when {
            key == PauseStore.KEY_APPS || key == PauseStore.KEY_WHOLE || key == PauseStore.KEY_RULES || key == PauseStore.KEY_FREE || key == null -> reload()
            key == PauseStore.KEY_ALL_UNTIL || key.startsWith("pass:") -> scheduleExpiryCheck()
        }
    }

    private fun reload() {
        val c = PauseStore.config(this)
        config = c
        val watched = mutableSetOf<String>()
        watched.addAll(c.apps)
        watched.addAll(c.wholeBrowsers)
        if (c.rules.isNotEmpty()) watched.addAll(PauseRules.BROWSERS.keys)
        watched.remove(packageName)
        val info = serviceInfo ?: return
        info.packageNames = if (watched.isEmpty()) arrayOf(packageName) else watched.toTypedArray()
        serviceInfo = info
        scheduleExpiryCheck()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val e = event ?: return
        val pkg = e.packageName?.toString() ?: return
        if (pkg == packageName) return
        val c = config ?: return
        val stateChange = e.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        if (pkg in c.apps || pkg in c.wholeBrowsers) {
            if (stateChange) check(pkg, fromWindowChange = true)
            // A whole app is checked when it comes to the front; inside it nothing more is looked at.
            if (pkg in c.apps) return
        }
        if (c.rules.isNotEmpty() && PauseRules.BROWSERS.containsKey(pkg)) {
            // Pages change without a new window: look at the address bar at most every BROWSER_CHECK_MS. A throttle,
            // not a debounce: a page that never stops changing (a feed, a video) would starve a debounce forever.
            browserPkg = pkg
            if (!browserCheckPending) {
                browserCheckPending = true
                main.postDelayed(browserCheck, BROWSER_CHECK_MS)
            }
        }
    }

    /** Decide for [pkg], now in front: the whole app, or (in a browser) the site it shows. */
    private fun check(pkg: String, fromWindowChange: Boolean) {
        val c = config ?: return
        val now = System.currentTimeMillis()
        if (pkg in c.apps || pkg in c.wholeBrowsers) {
            if (fromWindowChange) show(pkg, pkg, appLabel(pkg), now)
            if (pkg in c.apps) return
        }
        if (c.rules.isEmpty()) return
        val barId = PauseRules.BROWSERS[pkg] ?: return
        val root = try { rootInActiveWindow } catch (e: Exception) { null } ?: return
        if (root.packageName?.toString() != pkg) return
        val bar = try { root.findAccessibilityNodeInfosByViewId(barId).firstOrNull() } catch (e: Exception) { null } ?: return
        if (bar.isFocused) return // the learner is typing: the bar holds their words, not the page
        val shown = bar.text?.toString() ?: return
        val rule = PauseRules.firstMatch(c.rules, shown) ?: return
        show("site:" + rule.canonical, pkg, rule.label, now)
    }

    private fun show(key: String, pkg: String, label: String, now: Long) {
        if (PauseStore.isFree(this, key, now)) return
        // Never stack pauses: the screen behind keeps sending events while ours opens.
        if (PauseActivity.showing || now - PauseActivity.lastLaunch < RELAUNCH_GAP_MS) return
        PauseActivity.lastLaunch = now
        PauseStore.log(this, PauseStore.KIND_SHOWN, key, now) // an attempt to open (D59)
        val i = Intent(this, PauseActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NO_ANIMATION)
            putExtra(PauseActivity.EXTRA_KEY, key)
            putExtra(PauseActivity.EXTRA_PKG, pkg)
            putExtra(PauseActivity.EXTRA_LABEL, label)
        }
        try {
            startActivity(i)
        } catch (e: Exception) {
            // Some phones refuse a start from the background; then there is no pause this time.
        }
    }

    /** When free time runs out while a watched app or site is still in front, pause again. */
    private fun scheduleExpiryCheck() {
        main.removeCallbacks(expiryCheck)
        val now = System.currentTimeMillis()
        val next = PauseStore.nextExpiry(this, now) ?: return
        main.postDelayed(expiryCheck, (next - now + 500L).coerceAtLeast(500L))
    }

    private fun recheckFront() {
        val pkg = try { rootInActiveWindow?.packageName?.toString() } catch (e: Exception) { null }
        if (pkg != null && pkg != packageName) check(pkg, fromWindowChange = true)
        scheduleExpiryCheck()
    }

    private fun appLabel(pkg: String): String = try {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
    } catch (e: Exception) {
        pkg
    }

    companion object {
        /** True while Android has this service switched on and connected (read by the settings screen). */
        @Volatile var running = false
        private const val BROWSER_CHECK_MS = 600L
        private const val RELAUNCH_GAP_MS = 1500L
    }
}
