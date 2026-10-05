package dev.hotwire.nativeshell.bridge

import android.util.Log
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import dev.hotwire.nativeshell.MainActivity
import dev.hotwire.nativeshell.TabChrome

/**
 * Stimulus: `static component = "tabs"`, event `connect`.
 *
 * The page sends one object per tab (`id`, `title`, `icon`, `path` or `url`,
 * and `active`). There is no `/native/config` flag. A bad payload is ignored.
 * Fewer than two usable tabs leaves the single navigator.
 */
class TabsComponent(
    name: String,
    private val bridgeDelegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, bridgeDelegate) {

    override fun onReceive(message: Message) {
        if (message.event != "connect") {
            Log.w(TAG, "Unknown event for message: $message")
            return
        }
        val destination = bridgeDelegate.destination
        val activity = destination.fragment.activity as? MainActivity
        if (activity == null) {
            Log.w(TAG, "No activity for the tabs bridge")
            return
        }
        TabChrome.update(
            activity = activity,
            jsonData = message.jsonData,
            sourceLocation = destination.location,
            isModal = destination.isModal,
            currentIndex = activity.tabIndex(destination)
        )
    }

    private companion object {
        const val TAG = "TabsComponent"
    }
}
