package dev.hotwire.nativeshell.config

import java.net.URI

/**
 * What one `tabs` bridge `connect` should do.
 *
 * The iOS copy is `TabChromePlan` in `NativeConfig.swift`. Keep the two aligned.
 *
 * A modal is ignored, so `/dashboard/posts/new` cannot rebuild or switch the bar.
 * The same tab list does not rebuild. A page with no `active` flag does not move
 * the selection. A URL that belongs to another tab is shown on that tab. A
 * different list replaces every navigator: login gets fresh tab stacks, and
 * `tabs: []` gets one navigator rooted at the page that sent the message.
 * A later `[]` matches that empty list and does not replace again.
 */
object TabChromePlan {
    fun decide(
        currentTabs: List<ResolvedTab>,
        next: PresentedTabs,
        sourceLocation: String?,
        currentIndex: Int?,
        isModal: Boolean
    ): TabChromeDecision {
        if (isModal) return TabChromeDecision.Ignore
        if (currentTabs == next.resolution.tabs) {
            return selection(next, sourceLocation, currentIndex)
        }
        val root = if (next.resolution.tabs.isEmpty()) {
            sourceLocation?.let { canonicalHttpLocation(it) }
        } else {
            null
        }
        val index = if (next.resolution.tabs.size < 2) {
            next.selectedIndex
        } else {
            next.selectedIndex ?: 0
        }
        return TabChromeDecision.Replace(
            PresentedTabs(
                resolution = next.resolution,
                selectedIndex = index,
                singleRoot = root
            )
        )
    }

    /**
     * Longest tab path that owns [location]. A tab path of `/` owns every path
     * on that origin. `/dashboard/posts` wins over `/dashboard`.
     */
    fun owningTabIndex(location: String, tabs: List<ResolvedTab>): Int? {
        val page = parse(location) ?: return null
        var bestIndex: Int? = null
        var bestLength = -1
        tabs.forEachIndexed { index, tab ->
            val root = parse(tab.location) ?: return@forEachIndexed
            if (root.origin != page.origin) return@forEachIndexed
            if (!pathOwns(root.path, page.path)) return@forEachIndexed
            val length = root.path.length
            if (length > bestLength) {
                bestIndex = index
                bestLength = length
            }
        }
        return bestIndex
    }

    fun sameDocument(left: String?, right: String?): Boolean {
        if (left == null || right == null) return false
        val a = parse(left) ?: return false
        val b = parse(right) ?: return false
        return a.origin == b.origin && normalizePath(a.path) == normalizePath(b.path)
    }

    private fun selection(
        next: PresentedTabs,
        sourceLocation: String?,
        currentIndex: Int?
    ): TabChromeDecision {
        val tabs = next.resolution.tabs
        if (tabs.size < 2) return TabChromeDecision.Keep
        val location = sourceLocation?.takeIf { canonicalHttpLocation(it) != null } ?: return TabChromeDecision.Keep
        val owner = owningTabIndex(location, tabs)
        if (owner != null && currentIndex != null && owner != currentIndex) {
            return TabChromeDecision.Route(owner, location)
        }
        return TabChromeDecision.Keep
    }

    private fun pathOwns(tabPath: String, locationPath: String): Boolean {
        val tab = normalizePath(tabPath)
        val loc = normalizePath(locationPath)
        if (tab == "/") return true
        return loc == tab || loc.startsWith("$tab/")
    }

    private fun normalizePath(path: String): String {
        val trimmed = path.trim()
        if (trimmed.isEmpty() || trimmed == "/") return "/"
        return trimmed.trimEnd('/').ifEmpty { "/" }
    }

    private fun parse(value: String): Parsed? {
        if (canonicalHttpLocation(value) == null) return null
        return try {
            val uri = URI(value)
            val scheme = uri.scheme?.lowercase() ?: return null
            val host = uri.host?.lowercase() ?: return null
            val port = if (uri.port == -1) {
                if (scheme == "http") 80 else 443
            } else {
                uri.port
            }
            Parsed(
                origin = "$scheme://$host:$port",
                path = uri.rawPath?.takeIf { it.isNotEmpty() } ?: "/"
            )
        } catch (_: Exception) {
            null
        }
    }

    private data class Parsed(val origin: String, val path: String)
}

sealed class TabChromeDecision {
    data object Ignore : TabChromeDecision()
    data object Keep : TabChromeDecision()
    data class Route(val index: Int, val location: String) : TabChromeDecision()
    data class Replace(val presented: PresentedTabs) : TabChromeDecision()
}
