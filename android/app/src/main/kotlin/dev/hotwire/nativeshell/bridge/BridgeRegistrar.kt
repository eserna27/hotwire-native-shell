package dev.hotwire.nativeshell.bridge

import android.util.Log
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.config.Hotwire
import dev.hotwire.navigation.config.registerBridgeComponents
import dev.hotwire.navigation.destinations.HotwireDestination
import dev.hotwire.nativeshell.config.BridgeFlags

/**
 * Registers the bridge components whose contract flags are on.
 *
 * Component names match `@hotwired/hotwire-native-bridge` `static component`
 * values used by the public bridge catalog (`notification-token`, `share`,
 * `haptic`). Flags for components this skeleton does not ship stay off and
 * are not registered, so they never appear in the WebView user agent.
 */
object BridgeRegistrar {
    private const val TAG = "BridgeRegistrar"

    fun register(flags: BridgeFlags) {
        val factories = ArrayList<BridgeComponentFactory<HotwireDestination, BridgeComponent<HotwireDestination>>>()

        if (flags.notificationToken) {
            factories += BridgeComponentFactory("notification-token", ::NotificationTokenComponent)
        }
        if (flags.share) {
            factories += BridgeComponentFactory("share", ::ShareComponent)
        }
        if (flags.haptic) {
            factories += BridgeComponentFactory("haptic", ::HapticComponent)
        }

        val waiting = unimplemented(flags)
        if (waiting.isNotEmpty()) {
            Log.w(TAG, "Bridge flags are on, but this shell has no component yet: $waiting")
        }

        Hotwire.registerBridgeComponents(*factories.toTypedArray())
        Log.i(TAG, "Registered bridge components: ${factories.joinToString { it.name }}")
    }

    private fun unimplemented(flags: BridgeFlags): List<String> {
        return buildList {
            if (flags.camera) add("camera")
            if (flags.biometric) add("biometric")
            if (flags.clipboard) add("clipboard")
            if (flags.fileDownload) add("file_download")
        }
    }
}
