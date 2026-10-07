package dev.hotwire.nativeshell.config

/**
 * Order of the navigator configurations [dev.hotwire.nativeshell.MainActivity]
 * returns.
 *
 * Hotwire's activity delegate treats the first entry as the current navigator,
 * so that host has to be the one in the layout about to be shown. Every other
 * host stays in the list. `recreate()` restores the previous `NavigatorHost`
 * fragments, and a missing id throws "No configuration found for NavigatorHost".
 *
 * Fewer than two tabs (cold start, one tab, or `tabs: []`) shows
 * `main_nav_host`. Two or more shows the tab hosts. Login and logout cross
 * that boundary, so both sets are always returned.
 */
internal object NavigatorHostPlan {
    fun <T> order(main: T, tabs: List<T>, presentedTabCount: Int): List<T> {
        return if (presentedTabCount < 2) listOf(main) + tabs else tabs + listOf(main)
    }
}
