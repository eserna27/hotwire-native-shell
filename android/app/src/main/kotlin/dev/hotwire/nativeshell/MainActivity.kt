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
import dev.hotwire.nativeshell.config.ShellTabs

class MainActivity : HotwireActivity() {
    private val config get() = ShellApplication.current

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        if (config.tabs.isEmpty()) {
            setContentView(R.layout.activity_main)
            findViewById<View>(R.id.main_nav_host).applyDefaultImeWindowInsets()
            return
        }

        if (config.tabs.size > ShellTabs.MAX_TABS) {
            Log.w(TAG, "Config declares ${config.tabs.size} tabs; showing the first ${ShellTabs.MAX_TABS}.")
        }

        setContentView(R.layout.activity_main_tabs)
        findViewById<View>(R.id.root).applyDefaultImeWindowInsets()

        val tabs = ShellTabs.from(config)
        HotwireBottomNavigationController(
            activity = this,
            view = findViewById(R.id.bottom_nav),
            lazyLoadTabs = true
        ).load(tabs)
    }

    override fun navigatorConfigurations(): List<NavigatorConfiguration> {
        val shellConfig = ShellApplication.current
        if (shellConfig.tabs.isEmpty()) {
            return listOf(
                NavigatorConfiguration(
                    name = "main",
                    startLocation = shellConfig.startLocation,
                    navigatorHostId = R.id.main_nav_host
                )
            )
        }
        return ShellTabs.from(shellConfig).navigatorConfigurations
    }

    private companion object {
        const val TAG = "MainActivity"
    }
}
