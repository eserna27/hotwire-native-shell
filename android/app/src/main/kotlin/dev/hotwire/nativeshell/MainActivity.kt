package dev.hotwire.nativeshell

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.View
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.destinations.HotwireDestination
import dev.hotwire.navigation.navigator.Navigator
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController
import dev.hotwire.navigation.tabs.navigatorConfigurations
import dev.hotwire.navigation.util.applyDefaultImeWindowInsets
import dev.hotwire.nativeshell.config.NativeConfig
import dev.hotwire.nativeshell.config.PresentedTabs
import dev.hotwire.nativeshell.config.ShellTabs
import dev.hotwire.nativeshell.config.TabChromePlan
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
        val index = (presented.selectedIndex ?: 0).coerceIn(0, presented.resolution.tabs.lastIndex)
        controller.load(ShellTabs.from(this, config, presented.resolution.tabs), index)
    }

    /**
     * Login and logout start a new task so the previous navigator fragments
     * are not restored from saved state.
     */
    fun relaunchFresh() {
        val launch = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        startActivity(launch)
        if (Build.VERSION.SDK_INT >= 34) {
            overrideActivityTransition(Activity.OVERRIDE_TRANSITION_OPEN, 0, 0)
        } else {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }
        finish()
    }

    /**
     * Index of the tab navigator that is showing [destination]. A hidden tab
     * can still send `connect` after a pop; that index is the one that matters,
     * not whichever tab is selected.
     */
    fun tabIndex(destination: HotwireDestination): Int? {
        if (presented().resolution.tabs.size < 2) return null
        val name = destination.navigator.configuration.name
        val index = presented().resolution.tabs.indexOfFirst { it.id == name }
        return index.takeIf { it >= 0 }
    }

    /**
     * Shows [location] on the tab that owns it and pops that visit off the
     * navigator that received it, when that navigator is a different tab.
     */
    fun routeToTab(index: Int, location: String, fromIndex: Int?) {
        val controller = bottomNavigationController ?: return
        val tabs = presented().resolution.tabs
        if (index !in tabs.indices) return
        val fromNav = fromIndex?.let { navigatorAt(controller, it) }
        if (fromIndex != index) {
            controller.selectTab(index)
        }
        val hop = Runnable {
            if (isFinishing || isDestroyed) return@Runnable
            val target = navigatorAt(controller, index)
            if (target != null && !TabChromePlan.sameDocument(target.location, location)) {
                target.route(location)
            }
            if (fromNav != null && fromIndex != index && fromNav.isReady() &&
                !fromNav.isAtStartDestination() &&
                TabChromePlan.sameDocument(fromNav.location, location)
            ) {
                fromNav.pop()
            }
        }
        window?.decorView?.post(hop) ?: hop.run()
    }

    override fun navigatorConfigurations(): List<NavigatorConfiguration> {
        val shellConfig = ShellApplication.current
        val presented = TabChrome.presented(shellConfig, deviceLanguage())
        if (presented.resolution.tabs.size < 2) {
            return listOf(
                NavigatorConfiguration(
                    name = "main",
                    startLocation = presented.singleRoot
                        ?: presented.resolution.tabs.firstOrNull()?.location
                        ?: shellConfig.startLocation,
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

    private fun navigatorAt(controller: HotwireBottomNavigationController, index: Int): Navigator? {
        val tab = controller.tabs.getOrNull(index) ?: return null
        return delegate.findNavigatorHost(tab.configuration.navigatorHostId)?.navigator
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
