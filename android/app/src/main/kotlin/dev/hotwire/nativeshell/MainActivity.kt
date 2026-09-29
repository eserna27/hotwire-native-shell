package dev.hotwire.nativeshell

import android.os.Bundle
import android.util.Log
import android.view.View
import androidx.activity.enableEdgeToEdge
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController
import dev.hotwire.navigation.tabs.navigatorConfigurations
import dev.hotwire.navigation.util.applyDefaultImeWindowInsets
import dev.hotwire.nativeshell.config.NativeConfig
import dev.hotwire.nativeshell.config.ShellTabs
import dev.hotwire.nativeshell.config.TabResolution
import java.util.Locale

class MainActivity : HotwireActivity() {
    private val config get() = ShellApplication.current

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        val resolution = resolvedTabs()
        logTabs(resolution)

        if (resolution.tabs.size < 2) {
            setContentView(R.layout.activity_main)
            findViewById<View>(R.id.main_nav_host).applyDefaultImeWindowInsets()
            return
        }

        setContentView(R.layout.activity_main_tabs)
        findViewById<View>(R.id.root).applyDefaultImeWindowInsets()

        HotwireBottomNavigationController(
            activity = this,
            view = findViewById(R.id.bottom_nav),
            lazyLoadTabs = true
        ).load(ShellTabs.from(this, config, resolution.tabs))
    }

    override fun navigatorConfigurations(): List<NavigatorConfiguration> {
        val shellConfig = ShellApplication.current
        val resolution = shellConfig.resolveTabs(deviceLanguage())
        if (resolution.tabs.size < 2) {
            return listOf(
                NavigatorConfiguration(
                    name = "main",
                    startLocation = resolution.tabs.firstOrNull()?.location ?: shellConfig.startLocation,
                    navigatorHostId = R.id.main_nav_host
                )
            )
        }
        return ShellTabs.from(this, shellConfig, resolution.tabs).navigatorConfigurations
    }

    private fun resolvedTabs(): TabResolution {
        return config.resolveTabs(deviceLanguage())
    }

    private fun logTabs(resolution: TabResolution) {
        if (resolution.dropped > 0) {
            Log.w(TAG, "Ignored ${resolution.dropped} invalid tab entries in /native/config.")
        }
        if (resolution.overflow > 0) {
            Log.w(
                TAG,
                "Config has more than ${NativeConfig.MAX_TABS} valid tabs; showing the first ${NativeConfig.MAX_TABS}."
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
