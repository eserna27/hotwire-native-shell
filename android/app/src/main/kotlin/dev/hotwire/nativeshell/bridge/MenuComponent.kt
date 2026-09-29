package dev.hotwire.nativeshell.bridge

import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.material.bottomsheet.BottomSheetDialog
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Stimulus: `static component = "menu"`, event `display`.
 *
 * Presents a native bottom sheet and replies with `{ "selectedIndex" }`.
 * The index is the item's position in the web `item` target list. Dismissing
 * the sheet does not reply. Matches the Hotwire Native Android 1.3.1 demo
 * message. `source` on the payload is ignored; Android does not use it.
 */
class MenuComponent(
    name: String,
    private val bridgeDelegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, bridgeDelegate) {

    override fun onReceive(message: Message) {
        when (message.event) {
            "display" -> display(message)
            else -> Log.w(TAG, "Unknown event for message: $message")
        }
    }

    private fun display(message: Message) {
        val data = message.data<MessageData>() ?: return
        val context = bridgeDelegate.destination.fragment.context ?: return
        val sheet = BottomSheetDialog(context)
        val density = context.resources.displayMetrics.density
        val pad = (16 * density).toInt()
        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, pad, 0, pad)
        }

        container.addView(TextView(context).apply {
            text = data.title
            setPadding(pad, 0, pad, pad / 2)
            setTextAppearance(com.google.android.material.R.style.TextAppearance_Material3_TitleMedium)
        })

        val selectable = TypedValue()
        context.theme.resolveAttribute(android.R.attr.selectableItemBackground, selectable, true)

        data.items.forEach { item ->
            container.addView(TextView(context).apply {
                text = item.title
                minHeight = (48 * density).toInt()
                gravity = Gravity.CENTER_VERTICAL
                setPadding(pad, pad / 2, pad, pad / 2)
                setTextAppearance(com.google.android.material.R.style.TextAppearance_Material3_BodyLarge)
                if (selectable.resourceId != 0) {
                    setBackgroundResource(selectable.resourceId)
                }
                setOnClickListener {
                    sheet.dismiss()
                    replyTo("display", SelectionMessageData(selectedIndex = item.index))
                }
            })
        }

        sheet.setContentView(container)
        sheet.show()
    }

    @Serializable
    data class MessageData(
        val title: String,
        val items: List<Item>
    )

    @Serializable
    data class Item(
        val title: String,
        val index: Int
    )

    @Serializable
    data class SelectionMessageData(
        @SerialName("selectedIndex") val selectedIndex: Int
    )

    private companion object {
        const val TAG = "MenuComponent"
    }
}
