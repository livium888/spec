package app.dailylearning.daily_learning

/**
 * Which sites bring up the pause in a browser (D58). This is a MIRROR of lib/domain/site_rule.dart
 * (parseAddress and SiteRule.matches), which holds the tested reference: change both together.
 * The rules arrive already checked and in canonical form (`*.host/path`) from the Dart side.
 * The address bar text is untrusted (a web page sets it): it is only compared, never stored or logged.
 */
object PauseRules {
    /**
     * Browsers whose address bar can be read, with the id of the bar. Ids differ between browsers and can change
     * with a browser update (verify against each browser's current version on a phone); a browser not listed here,
     * or one whose bar is not found, never brings up a pause for a site rule.
     */
    val BROWSERS: Map<String, String> = linkedMapOf(
        "com.android.chrome" to "com.android.chrome:id/url_bar",
        "com.chrome.beta" to "com.chrome.beta:id/url_bar",
        "com.brave.browser" to "com.brave.browser:id/url_bar",
        "com.microsoft.emmx" to "com.microsoft.emmx:id/url_bar",
        "com.vivaldi.browser" to "com.vivaldi.browser:id/url_bar",
        "com.opera.browser" to "com.opera.browser:id/url_field",
        "com.sec.android.app.sbrowser" to "com.sec.android.app.sbrowser:id/location_bar_edit_text",
        "org.mozilla.firefox" to "org.mozilla.firefox:id/mozac_browser_toolbar_url_view",
        "com.duckduckgo.mobile.android" to "com.duckduckgo.mobile.android:id/omnibarTextInput",
    )

    data class Rule(val host: String, val wildcard: Boolean, val path: String) {
        val canonical: String get() = (if (wildcard) "*." else "") + host + path
        val label: String get() = host + path
    }

    /** One canonical rule as the Dart side stores it; null for anything else. */
    fun parseRule(canonical: String): Rule? {
        var s = canonical.trim()
        var wildcard = false
        if (s.startsWith("*.")) {
            wildcard = true
            s = s.substring(2)
        }
        val a = address(s) ?: return null
        return Rule(a.first, wildcard, a.second)
    }

    fun parseRules(stored: String?): List<Rule> =
        (stored ?: "").split('\n').mapNotNull { parseRule(it) }.distinct().take(200)

    private val label = Regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$")
    private val digits = Regex("^[0-9]+$")

    /** Host and path of an address as a browser shows it; null when it is not one (a search, the empty bar). */
    fun address(shown: String): Pair<String, String>? {
        var s = shown.trim().lowercase()
        if (s.isEmpty() || s.contains(' ') || s.length > 2048) return null
        val scheme = s.indexOf("://")
        if (scheme >= 0) {
            val name = s.substring(0, scheme)
            if (name != "http" && name != "https") return null
            s = s.substring(scheme + 3)
        }
        val cut = s.indexOfFirst { it == '?' || it == '#' }
        if (cut >= 0) s = s.substring(0, cut)
        val slash = s.indexOf('/')
        var host = if (slash < 0) s else s.substring(0, slash)
        var path = if (slash < 0) "" else s.substring(slash)
        val at = host.lastIndexOf('@')
        if (at >= 0) host = host.substring(at + 1)
        val colon = host.indexOf(':')
        if (colon >= 0) host = host.substring(0, colon)
        host = host.trimEnd('.')
        path = path.trimEnd('/')
        if (host.isEmpty() || host.length > 253 || !host.contains('.')) return null
        val parts = host.split('.')
        if (parts.any { !label.matches(it) } || digits.matches(parts.last())) return null
        return Pair(host, path)
    }

    fun matches(rule: Rule, shown: String): Boolean {
        val a = address(shown) ?: return false
        val host = a.first
        val hostOk = host == rule.host || host == "www." + rule.host || (rule.wildcard && host.endsWith("." + rule.host))
        if (!hostOk) return false
        return rule.path.isEmpty() || a.second == rule.path || a.second.startsWith(rule.path + "/")
    }

    fun firstMatch(rules: List<Rule>, shown: String): Rule? = rules.firstOrNull { matches(it, shown) }
}
