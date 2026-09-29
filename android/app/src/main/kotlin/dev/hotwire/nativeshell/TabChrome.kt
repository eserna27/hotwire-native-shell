package dev.hotwire.nativeshell

import android.util.Log
import dev.hotwire.nativeshell.config.NativeConfig
import dev.hotwire.nativeshell.config.PresentedTabs
import dev.hotwire.nativeshell.config.parsePresentedTabs
import java.util.Locale

/**
 * Cold start uses `tabs` from `/native/config`. A `tabs` bridge `connect`
 * replaces that list. The replacement is committed on the next activity
 * creation so navigator hosts are not reconfigured under a live graph.
 */
object TabChrome {
    private var applied: PresentedTabs? = null
    private var pending: PresentedTabs? = null

    fun commitPending() {
        pending?.let {
            applied = it
            pending = null
        }
    }

    fun presented(config: NativeConfig, languageTag: String): PresentedTabs {
        return applied ?: PresentedTabs(config.resolveTabs(languageTag), selectedIndex = 0)
    }

    fun update(activity: MainActivity, jsonData: String) {
        val config = ShellApplication.current
        val language = Locale.getDefault().toLanguageTag()
        val next = parsePresentedTabs(jsonData, config.baseUrl, language)
        if (next == null) {
            Log.w(TAG, "Ignoring tabs connect that has no tabs array.")
            return
        }
        log(next)
        val current = pending ?: presented(config, language)
        if (next.resolution.tabs == current.resolution.tabs) {
            applied = next
            activity.selectTabIfNeeded(next.selectedIndex)
            return
        }
        pending = next
        val decor = activity.window?.decorView
        if (decor == null) {
            activity.recreate()
            return
        }
        decor.post {
            if (!activity.isFinishing && !activity.isDestroyed) {
                activity.recreate()
            }
        }
    }

    private fun log(presented: PresentedTabs) {
        val resolution = presented.resolution
        if (resolution.dropped > 0) {
            Log.w(TAG, "Ignored ${resolution.dropped} invalid tabs bridge entries.")
        }
        if (resolution.overflow > 0) {
            Log.w(TAG, "Tabs bridge has more than ${NativeConfig.MAX_TABS} valid tabs; showing the first ${NativeConfig.MAX_TABS}.")
        }
    }

    private const val TAG = "TabChrome"
}
