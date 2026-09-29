package dev.hotwire.nativeshell.bridge

import android.content.Intent
import android.util.Log
import android.view.Menu
import android.view.MenuItem
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import dev.hotwire.navigation.fragments.HotwireFragment
import kotlinx.serialization.Serializable

/**
 * Stimulus: `static component = "share"`, event `connect`, data `{url}`.
 * Adds a toolbar action that opens the system share sheet. The sheet shares
 * `url`, or the page URL from the bridge message when `url` is omitted.
 */
class ShareComponent(
    name: String,
    private val bridgeDelegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, bridgeDelegate) {

    override fun onReceive(message: Message) {
        when (message.event) {
            "connect" -> addButton(message)
            "disconnect" -> removeButton()
            else -> Log.w(TAG, "Unknown event for message: $message")
        }
    }

    private fun addButton(message: Message) {
        val toolbar = (bridgeDelegate.destination.fragment as? HotwireFragment)?.toolbarForNavigation()
        if (toolbar == null) {
            Log.w(TAG, "No toolbar for the share action")
            return
        }
        val url = message.data<MessageData>()?.url ?: message.metadata?.url
        if (url.isNullOrBlank()) {
            Log.w(TAG, "Share connect missing url")
            return
        }
        toolbar.menu.removeItem(MENU_ID)
        toolbar.menu.add(Menu.NONE, MENU_ID, Menu.NONE, "Share").apply {
            setShowAsAction(MenuItem.SHOW_AS_ACTION_IF_ROOM)
            setOnMenuItemClickListener {
                share(url)
                true
            }
        }
    }

    private fun removeButton() {
        val toolbar = (bridgeDelegate.destination.fragment as? HotwireFragment)?.toolbarForNavigation()
        toolbar?.menu?.removeItem(MENU_ID)
    }

    private fun share(url: String) {
        val fragment = bridgeDelegate.destination.fragment
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, url)
        }
        fragment.startActivity(Intent.createChooser(intent, "Share"))
    }

    @Serializable
    data class MessageData(
        val url: String? = null
    )

    private companion object {
        const val TAG = "ShareComponent"
        const val MENU_ID = 41
    }
}
