package app.dailylearning.daily_learning

import android.animation.ValueAnimator
import android.app.Activity
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.Button
import android.window.OnBackInvokedDispatcher
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * The pause (D58): shown by PauseService when a watched app or site comes to the front. Native, not Flutter, so
 * it appears at once (a cold Flutter start would leave the app visible for a second or more). Not exported: no
 * other app can open it or ask it for free time.
 *
 * Three ways out: do five cards (then everything watched is free for a few minutes), breathe then open (that one
 * app or site is free for a few minutes), or not now (back to the home screen). Back = not now.
 * Accessibility: text in sp, buttons at least 56 dp high, every control labelled, no animation when the phone's
 * animations are off, and the breathing words are announced by screen readers.
 */
class PauseActivity : Activity() {
    private val main = Handler(Looper.getMainLooper())
    private var key = ""
    private var pkg = ""
    private var label = ""
    private var animator: ValueAnimator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        listenForBack()
        read(intent)
        build()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        stopBreathing()
        read(intent)
        build()
    }

    override fun onResume() {
        super.onResume()
        showing = true
    }

    override fun onPause() {
        showing = false
        super.onPause()
    }

    override fun onDestroy() {
        stopBreathing()
        super.onDestroy()
    }

    // Back on this screen means "not now" (back would only reveal the paused app). Android 13+ hands back to a
    // registered callback (and, for apps targeting Android 16, no longer calls onBackPressed); older versions send the key.
    private fun listenForBack() {
        if (Build.VERSION.SDK_INT >= 33) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT) { notNow() }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK && Build.VERSION.SDK_INT < 33) {
            notNow()
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun read(i: Intent?) {
        key = i?.getStringExtra(EXTRA_KEY) ?: ""
        pkg = i?.getStringExtra(EXTRA_PKG) ?: ""
        label = i?.getStringExtra(EXTRA_LABEL) ?: pkg
        if (key.isEmpty() || pkg.isEmpty()) finish()
    }

    // ---- layout ----------------------------------------------------------------------------------------

    private val dark get() = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
    private val ink get() = if (dark) Color.parseColor("#F2F1EC") else Color.parseColor("#1C1B19")
    private val inkSoft get() = if (dark) Color.parseColor("#C9C7BF") else Color.parseColor("#4A4843")
    private val paper get() = if (dark) Color.parseColor("#151513") else Color.parseColor("#FBFAF6")
    private val accent get() = if (dark) Color.parseColor("#7FC8B4") else Color.parseColor("#1F6F5C")
    private val onAccent get() = if (dark) Color.parseColor("#0E2620") else Color.WHITE

    private fun dp(v: Int): Int = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    private fun text(s: String, sp: Float, color: Int, bold: Boolean = false): TextView = TextView(this).apply {
        text = s
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
        setTextColor(color)
        gravity = Gravity.CENTER
        if (bold) typeface = Typeface.DEFAULT_BOLD
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(10) }
    }

    private fun button(s: String, primary: Boolean, onClick: () -> Unit): Button = Button(this).apply {
        text = s
        isAllCaps = false
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
        minHeight = dp(56)
        minimumHeight = dp(56)
        setTextColor(if (primary) onAccent else accent)
        background = GradientDrawable().apply {
            cornerRadius = dp(28).toFloat()
            if (primary) setColor(accent) else {
                setColor(Color.TRANSPARENT)
                setStroke(dp(2), accent)
            }
        }
        setOnClickListener { onClick() }
        layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(14) }
    }

    private lateinit var column: LinearLayout

    private fun build() {
        if (isFinishing) return
        val cfg = PauseStore.config(this)
        val free = cfg.freeMinutes
        val due = DueStore.due(this)
        val now = System.currentTimeMillis()
        // D59: the wait grows with each pause of this app today, and a daily open limit leaves only the cards.
        val wait = PauseStore.waitSeconds(PauseStore.countToday(this, PauseStore.KIND_SHOWN, key, now), cfg.rising)
        val opens = PauseStore.countToday(this, PauseStore.CHOICE_OPEN, key, now)
        val limitReached = cfg.openLimit > 0 && opens >= cfg.openLimit
        column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(48), dp(24), dp(32))
        }
        column.addView(text(label, 30f, ink, bold = true).apply {
            accessibilityHeading()
        })
        column.addView(text("You were about to open $label. Take a moment first.", 18f, inkSoft))
        val cardsLine = when {
            due == null -> null
            due == 0 -> "No cards are due right now."
            else -> "$due ${if (due == 1) "card" else "cards"} waiting, about ${DueStore.minutes(this)} min."
        }
        if (cardsLine != null) column.addView(text(cardsLine, 18f, ink))
        val next = if (cfg.showNext && due != 0) DueStore.next(this) else null
        if (next != null) {
            column.addView(text("Next card: $next", 18f, ink).apply {
                setTypeface(typeface, Typeface.ITALIC)
                setPadding(dp(12), dp(12), dp(12), dp(12))
                background = GradientDrawable().apply {
                    cornerRadius = dp(12).toFloat()
                    setStroke(dp(1), inkSoft)
                }
            })
        }

        if (due != 0) {
            column.addView(button("Do 5 cards", primary = true) { doCards() }.apply {
                contentDescription = "Do 5 cards. Then everything you pause is free for $free ${minutesWord(free)}."
            })
            column.addView(text("Then everything you pause is free for $free ${minutesWord(free)}.", 15f, inkSoft).apply {
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO // said by the button
            })
        }
        if (limitReached) {
            column.addView(text(
                "You opened $label $opens ${if (opens == 1) "time" else "times"} today, your daily limit. " +
                    (if (due == 0) "No cards are due, so it opens again tomorrow." else "Do 5 cards, or come back tomorrow."),
                16f, ink,
            ))
        } else {
            column.addView(button(if (wait > 10) "Breathe ($wait s), then open" else "Breathe, then open", primary = due == 0) { breathe(free, wait) })
        }
        column.addView(button("Not now", primary = false) { notNow() })

        val scroll = ScrollView(this).apply {
            setBackgroundColor(paper)
            isFillViewport = true
            fitsSystemWindows = true // keep the buttons clear of the status and navigation bars (edge-to-edge)
            addView(column)
        }
        window.setBackgroundDrawable(ColorDrawable(paper))
        setContentView(scroll)
    }

    private fun TextView.accessibilityHeading() {
        if (Build.VERSION.SDK_INT >= 28) isAccessibilityHeading = true
    }

    private fun minutesWord(n: Int) = if (n == 1) "minute" else "minutes"

    // ---- the three ways out ----------------------------------------------------------------------------

    /** Five cards in the app; the review screen grants the free time once they are answered (D58). */
    private fun doCards() {
        val now = System.currentTimeMillis()
        PauseStore.log(this, PauseStore.CHOICE_CARDS, key, now)
        PauseStore.setPending(this, key, label, pkg, now)
        startActivity(DueStore.openIntent(this, DueStore.ROUTE_PAUSE))
        finish()
    }

    private fun notNow() {
        PauseStore.log(this, PauseStore.CHOICE_BACK, key, System.currentTimeMillis())
        try {
            startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: Exception) {
            // no home screen app: just close
        }
        finish()
    }

    private fun open(free: Int) {
        val now = System.currentTimeMillis()
        PauseStore.log(this, PauseStore.CHOICE_OPEN, key, now)
        PauseStore.grant(this, key, now + free * 60_000L)
        launchTarget(this, pkg)
        finish()
    }

    /** [seconds] of slow breathing (5 in, 5 out), then the open button. */
    private fun breathe(free: Int, seconds: Int) {
        column.removeAllViews()
        column.addView(text(label, 26f, ink, bold = true).apply { accessibilityHeading() })
        val still = Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
        val size = dp(160)
        val circle = View(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(accent)
                alpha = 70
            }
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            layoutParams = LinearLayout.LayoutParams(size, size).apply { topMargin = dp(28); bottomMargin = dp(12) }
        }
        column.addView(circle)
        val words = text("Breathe in", 22f, ink).apply { accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE }
        column.addView(words)
        val left = text("$seconds", 18f, inkSoft).apply { importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO }
        column.addView(left)
        column.addView(button("Not now", primary = false) { notNow() })

        if (!still) {
            animator = ValueAnimator.ofFloat(0.55f, 1f).apply {
                duration = 5000
                repeatMode = ValueAnimator.REVERSE
                repeatCount = (seconds / 5 - 1).coerceAtLeast(0)
                interpolator = AccelerateDecelerateInterpolator()
                addUpdateListener {
                    val v = it.animatedValue as Float
                    circle.scaleX = v
                    circle.scaleY = v
                }
                start()
            }
        }
        for (s in 1..seconds) {
            main.postDelayed({
                left.text = "${seconds - s}"
                if (s % 5 == 0 && s < seconds) words.text = if ((s / 5) % 2 == 1) "Breathe out" else "Breathe in"
                if (s == seconds) {
                    words.text = "Ready when you are."
                    left.visibility = View.GONE
                    column.addView(button("Open $label for $free ${minutesWord(free)}", primary = true) { open(free) }, 3)
                }
            }, s * 1000L)
        }
    }

    private fun stopBreathing() {
        main.removeCallbacksAndMessages(null)
        animator?.cancel()
        animator = null
    }

    companion object {
        const val EXTRA_KEY = "key"
        const val EXTRA_PKG = "pkg"
        const val EXTRA_LABEL = "label"
        @Volatile var showing = false
        @Volatile var lastLaunch = 0L

        /** Bring the paused app (or browser) back to the front, as it was. */
        fun launchTarget(ctx: android.content.Context, pkg: String): Boolean {
            val i = ctx.packageManager.getLaunchIntentForPackage(pkg) ?: return false
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            return try {
                ctx.startActivity(i)
                true
            } catch (e: Exception) {
                false
            }
        }
    }
}
