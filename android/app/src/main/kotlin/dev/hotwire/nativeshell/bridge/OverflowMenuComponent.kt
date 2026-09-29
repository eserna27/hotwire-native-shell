package dev.hotwire.nativeshell.bridge

import android.content.res.ColorStateList
import android.util.Log
import android.view.Menu
import android.view.MenuItem
import com.google.android.material.color.MaterialColors
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import dev.hotwire.navigation.fragments.HotwireFragment
import dev.hotwire.nativeshell.R
import kotlinx.serialization.Serializable

/**
 * Stimulus: `static component = "overflow-menu"`, event `connect`, data `{label}`.
 *
 * Adds a trailing toolbar action. Tapping it replies to `connect` with no
 * data, which the web controller uses to click the same element and open
 * `menu`. Order is higher than `share`, so the ellipsis stays at the end.
 */
class OverflowMenuComponent(
    name: String,
    private val bridgeDelegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, bridgeDelegate) {

    override fun onReceive(message: Message) {
        when (message.event) {
            "connect" -> showItem(message)
            else -> Log.w(TAG, "Unknown event for message: $message")
        }
    }

    private fun showItem(message: Message) {
        val toolbar = (bridgeDelegate.destination.fragment as? HotwireFragment)?.toolbarForNavigation()
        if (toolbar == null) {
            Log.w(TAG, "No toolbar for the overflow menu")
            return
        }
        val label = message.data<MessageData>()?.label
        if (label.isNullOrBlank()) {
            Log.w(TAG, "Overflow connect missing label")
            return
        }

        toolbar.menu.removeItem(MENU_ID)
        toolbar.menu.add(Menu.NONE, MENU_ID, MENU_ORDER, label).apply {
            setIcon(R.drawable.ic_overflow)
            iconTintList = ColorStateList.valueOf(
                MaterialColors.getColor(toolbar, android.R.attr.colorControlNormal)
            )
            setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
            setOnMenuItemClickListener {
                replyTo("connect")
                true
            }
        }
    }

    @Serializable
    data class MessageData(
        val label: String
    )

    private companion object {
        const val TAG = "OverflowMenuComponent"
        const val MENU_ID = 42
        const val MENU_ORDER = 999
    }
}
