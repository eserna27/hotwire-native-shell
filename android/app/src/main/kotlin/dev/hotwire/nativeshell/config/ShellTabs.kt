package dev.hotwire.nativeshell.config

import android.content.Context
import android.util.Log
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomTab
import dev.hotwire.nativeshell.R

/**
 * Maps resolved contract tabs onto the five hosts in `activity_main_tabs.xml`.
 * Material's bottom bar holds at most five items, so every host is always
 * configured. Hosts past the resolved list stay in the menu with
 * `isVisible = false`.
 *
 * Icons use the shared catalog name (`icon`). `android_icon` is an optional
 * drawable resource name that must already be in this APK. An unknown name
 * falls back to the catalog, then to `ic_tab_home`.
 */
object ShellTabs {
    private const val TAG = "ShellTabs"

    private val hostIds = intArrayOf(
        R.id.tab_host_0,
        R.id.tab_host_1,
        R.id.tab_host_2,
        R.id.tab_host_3,
        R.id.tab_host_4
    )

    fun from(context: Context, config: NativeConfig, tabs: List<ResolvedTab>): List<HotwireBottomTab> {
        return hostIds.mapIndexed { index, hostId ->
            val tab = tabs.getOrNull(index)
            if (tab == null) {
                HotwireBottomTab(
                    title = "",
                    iconResId = R.drawable.ic_tab_home,
                    isVisible = false,
                    configuration = NavigatorConfiguration(
                        name = "shell-unused-$index",
                        navigatorHostId = hostId,
                        startLocation = config.startLocation
                    )
                )
            } else {
                HotwireBottomTab(
                    title = tab.title,
                    iconResId = iconRes(context, tab),
                    configuration = NavigatorConfiguration(
                        name = tab.id,
                        navigatorHostId = hostId,
                        startLocation = tab.location
                    )
                )
            }
        }
    }

    private fun iconRes(context: Context, tab: ResolvedTab): Int {
        val override = tab.androidIcon
        if (override.isNotEmpty()) {
            val id = context.resources.getIdentifier(override, "drawable", context.packageName)
            if (id != 0) return id
            Log.w(TAG, "Unknown android_icon '$override' for tab ${tab.id}; using the shared icon.")
        }
        return catalog(tab.icon)
    }

    private fun catalog(name: String): Int {
        return when (name) {
            "posts" -> R.drawable.ic_tab_posts
            "search" -> R.drawable.ic_tab_search
            "profile" -> R.drawable.ic_tab_profile
            "info" -> R.drawable.ic_tab_info
            else -> R.drawable.ic_tab_home
        }
    }
}
