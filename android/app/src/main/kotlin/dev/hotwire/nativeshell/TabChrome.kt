package dev.hotwire.nativeshell

import android.util.Log
import dev.hotwire.nativeshell.config.NativeConfig
import dev.hotwire.nativeshell.config.PresentedTabs
import dev.hotwire.nativeshell.config.TabChromeDecision
import dev.hotwire.nativeshell.config.TabChromePlan
import dev.hotwire.nativeshell.config.parsePresentedTabs
import java.util.Locale

/**
 * Cold start uses `tabs` from `/native/config`. The first `tabs` bridge
 * `connect` replaces that list, including a cached copy from an older install.
 *
 * Login (fewer than two tabs, then the signed-in set) and logout (`tabs: []`)
 * start a new task so no previous back stack is restored. The same list does
 * not start another task, so a later page that sends `[]` again stays on the
 * sign-in navigator.
 */
object TabChrome {
    private var applied: PresentedTabs? = null
    private var pending: PresentedTabs? = null
    private var replacing = false

    fun commitPending() {
        pending?.let {
            applied = it
            pending = null
        }
        replacing = false
    }

    fun presented(config: NativeConfig, languageTag: String): PresentedTabs {
        return applied ?: PresentedTabs(config.resolveTabs(languageTag), selectedIndex = 0)
    }

    fun update(
        activity: MainActivity,
        jsonData: String,
        sourceLocation: String?,
        isModal: Boolean,
        currentIndex: Int?
    ) {
        if (replacing || activity.isFinishing || activity.isDestroyed) return
        val config = ShellApplication.current
        val language = Locale.getDefault().toLanguageTag()
        val next = parsePresentedTabs(jsonData, config.baseUrl, language)
        if (next == null) {
            Log.w(TAG, "Ignoring tabs connect that has no tabs array.")
            return
        }
        log(next)
        val current = pending ?: presented(config, language)
        when (
            val decision = TabChromePlan.decide(
                currentTabs = current.resolution.tabs,
                next = next,
                sourceLocation = sourceLocation,
                currentIndex = currentIndex,
                isModal = isModal
            )
        ) {
            TabChromeDecision.Ignore -> Log.i(TAG, "Ignoring tabs connect from a modal.")
            TabChromeDecision.Keep -> Unit
            is TabChromeDecision.Route -> activity.routeToTab(
                index = decision.index,
                location = decision.location,
                fromIndex = currentIndex
            )
            is TabChromeDecision.Replace -> {
                if (pending?.resolution?.tabs == decision.presented.resolution.tabs &&
                    pending?.singleRoot == decision.presented.singleRoot
                ) {
                    return
                }
                Log.i(TAG, "Replacing tab chrome (${decision.presented.resolution.tabs.size} tabs).")
                pending = decision.presented
                replacing = true
                activity.relaunchFresh()
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
