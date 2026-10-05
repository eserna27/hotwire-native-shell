package dev.hotwire.nativeshell

import android.app.Activity
import android.view.View

/**
 * Holds the Android splash until the first Hotwire visit renders or fails.
 * A network that never answers still loses the splash after [TIMEOUT_MS].
 */
internal object FirstVisitSplash {
    const val TIMEOUT_MS = 8_000L

    @Volatile
    var settled: Boolean = false
        private set

    fun settle(activity: Activity?) {
        settled = true
        activity?.findViewById<View>(android.R.id.content)?.invalidate()
    }

    fun shouldKeepOnScreen(elapsedSinceStartMs: Long): Boolean {
        if (settled) return false
        return elapsedSinceStartMs < TIMEOUT_MS
    }

    fun reset() {
        settled = false
    }
}
