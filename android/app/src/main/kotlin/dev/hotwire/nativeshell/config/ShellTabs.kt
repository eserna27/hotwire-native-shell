package dev.hotwire.nativeshell.config

import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomTab
import dev.hotwire.nativeshell.R

/**
 * Maps contract tabs onto the four hosts in `activity_main_tabs.xml`.
 * Unused hosts stay in the layout with `isVisible = false` so every
 * `NavigatorHost` has a configuration.
 */
object ShellTabs {
    const val MAX_TABS = 4

    private val hostIds = intArrayOf(
        R.id.tab_host_0,
        R.id.tab_host_1,
        R.id.tab_host_2,
        R.id.tab_host_3
    )

    fun from(config: NativeConfig): List<HotwireBottomTab> {
        val declared = config.tabs.take(MAX_TABS)
        return hostIds.mapIndexed { index, hostId ->
            val tab = declared.getOrNull(index)
            if (tab == null) {
                HotwireBottomTab(
                    title = "",
                    iconResId = R.drawable.ic_tab_home,
                    isVisible = false,
                    configuration = NavigatorConfiguration(
                        name = "unused-$index",
                        navigatorHostId = hostId,
                        startLocation = config.startLocation
                    )
                )
            } else {
                HotwireBottomTab(
                    title = tab.title,
                    iconResId = iconRes(tab.icon),
                    configuration = NavigatorConfiguration(
                        name = tab.id,
                        navigatorHostId = hostId,
                        startLocation = config.locationFor(tab.path)
                    )
                )
            }
        }
    }

    private fun iconRes(name: String): Int {
        return when (name) {
            "posts" -> R.drawable.ic_tab_posts
            "search" -> R.drawable.ic_tab_search
            "profile" -> R.drawable.ic_tab_profile
            else -> R.drawable.ic_tab_home
        }
    }
}
