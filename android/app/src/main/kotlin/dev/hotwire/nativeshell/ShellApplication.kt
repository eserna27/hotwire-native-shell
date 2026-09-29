package dev.hotwire.nativeshell

import android.app.Application
import android.util.Log
import dev.hotwire.core.bridge.KotlinXJsonConverter
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.logging.HotwireLogLevel
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.config.defaultFragmentDestination
import dev.hotwire.navigation.config.registerFragmentDestinations
import dev.hotwire.navigation.fragments.HotwireWebBottomSheetFragment
import dev.hotwire.navigation.fragments.HotwireWebFragment
import dev.hotwire.nativeshell.bridge.BridgeRegistrar
import dev.hotwire.nativeshell.config.NativeConfig
import dev.hotwire.nativeshell.config.NativeConfigStore

class ShellApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val config = NativeConfigStore.loadStartup(this)
        current = config
        configureHotwire(config)
        Log.i(
            TAG,
            "Shell ${config.name} push.enabled=${config.push.enabled} topics=${config.push.topics}"
        )
        NativeConfigStore.refreshInBackground(this, config)
    }

    private fun configureHotwire(config: NativeConfig) {
        Hotwire.defaultFragmentDestination = HotwireWebFragment::class
        Hotwire.registerFragmentDestinations(
            HotwireWebFragment::class,
            HotwireWebBottomSheetFragment::class
        )
        BridgeRegistrar.register(config.bridges)

        Hotwire.config.jsonConverter = KotlinXJsonConverter()
        Hotwire.config.applicationUserAgentPrefix = "${config.name};"
        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG
        Hotwire.config.logger.logLevel = if (BuildConfig.DEBUG) {
            HotwireLogLevel.DEBUG
        } else {
            HotwireLogLevel.NONE
        }

        val remotePathConfiguration = config.locationFor("/configurations/android_v1.json")
        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                assetFilePath = "json/path-configuration.json",
                remoteFileUrl = remotePathConfiguration
            )
        )
    }

    companion object {
        private const val TAG = "ShellApplication"

        lateinit var current: NativeConfig
            private set
    }
}
