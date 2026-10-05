package dev.hotwire.nativeshell

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.View
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController
import dev.hotwire.navigation.tabs.navigatorConfigurations
import dev.hotwire.navigation.util.applyDefaultImeWindowInsets
import dev.hotwire.nativeshell.config.NativeConfig
import dev.hotwire.nativeshell.config.PresentedTabs
import dev.hotwire.nativeshell.config.ShellTabs
import java.util.Locale

class MainActivity : HotwireActivity() {
    private val config get() = ShellApplication.current
    private var bottomNavigationController: HotwireBottomNavigationController? = null

    private val splashHandler = Handler(Looper.getMainLooper())
    private val revealSplashAfterTimeout = Runnable {
        findViewById<View>(android.R.id.content)?.invalidate()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        TabChrome.commitPending()
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        val splashStartedAt = SystemClock.uptimeMillis()
        splashScreen.setKeepOnScreenCondition {
            FirstVisitSplash.shouldKeepOnScreen(SystemClock.uptimeMillis() - splashStartedAt)
        }
        splashHandler.postDelayed(revealSplashAfterTimeout, FirstVisitSplash.TIMEOUT_MS)

        val presented = presented()
        logTabs(presented)
        if (presented.resolution.tabs.size < 2) {
            setContentView(R.layout.activity_main)
            findViewById<View>(R.id.main_nav_host).applyDefaultImeWindowInsets()
            return
        }

        setContentView(R.layout.activity_main_tabs)
        findViewById<View>(R.id.root).applyDefaultImeWindowInsets()
        val controller = HotwireBottomNavigationController(
            activity = this,
            view = findViewById(R.id.bottom_nav),
            lazyLoadTabs = true
        )
        bottomNavigationController = controller
        val index = presented.selectedIndex.coerceIn(0, presented.resolution.tabs.lastIndex)
        controller.load(ShellTabs.from(this, config, presented.resolution.tabs), index)
    }

    override fun navigatorConfigurations(): List<NavigatorConfiguration> {
        val shellConfig = ShellApplication.current
        val presented = TabChrome.presented(shellConfig, deviceLanguage())
        if (presented.resolution.tabs.size < 2) {
            return listOf(
                NavigatorConfiguration(
                    name = "main",
                    startLocation = presented.resolution.tabs.firstOrNull()?.location ?: shellConfig.startLocation,
                    navigatorHostId = R.id.main_nav_host
                )
            )
        }
        return ShellTabs.from(this, shellConfig, presented.resolution.tabs).navigatorConfigurations
    }

    override fun onDestroy() {
        splashHandler.removeCallbacks(revealSplashAfterTimeout)
        super.onDestroy()
    }

    fun selectTabIfNeeded(index: Int) {
        val controller = bottomNavigationController ?: return
        if (controller.tabs.isEmpty()) return
        val safe = index.coerceIn(0, controller.tabs.lastIndex)
        if (controller.view.selectedItemId == safe) return
        controller.selectTab(safe)
    }

    private fun presented(): PresentedTabs {
        return TabChrome.presented(config, deviceLanguage())
    }

    private fun logTabs(presented: PresentedTabs) {
        val resolution = presented.resolution
        if (resolution.dropped > 0) {
            Log.w(TAG, "Ignored ${resolution.dropped} invalid tab entries.")
        }
        if (resolution.overflow > 0) {
            Log.w(
                TAG,
                "Tab list has more than ${NativeConfig.MAX_TABS} valid tabs; showing the first ${NativeConfig.MAX_TABS}."
            )
        }
        if (resolution.tabs.size < 2) {
            Log.i(TAG, "Single navigator (${resolution.tabs.size} valid tabs).")
        }
    }

    private companion object {
        const val TAG = "MainActivity"

        fun deviceLanguage(): String = Locale.getDefault().toLanguageTag()
    }
}
