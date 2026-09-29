package dev.hotwire.nativeshell.bridge

import android.os.Build
import android.util.Log
import android.view.HapticFeedbackConstants
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable

/**
 * Stimulus: `static component = "haptic"`, event `vibrate`, data `{feedback}`.
 * `feedback` is `success` (default), `warning`, or `error`.
 */
class HapticComponent(
    name: String,
    private val bridgeDelegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, bridgeDelegate) {

    override fun onReceive(message: Message) {
        when (message.event) {
            "vibrate" -> vibrate(message)
            else -> Log.w(TAG, "Unknown event for message: $message")
        }
    }

    private fun vibrate(message: Message) {
        val view = bridgeDelegate.destination.fragment.view
        if (view == null) {
            Log.w(TAG, "No view to perform haptic feedback")
            return
        }
        val feedback = message.data<MessageData>()?.feedback ?: "success"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val constant = when (feedback) {
                "warning", "error" -> HapticFeedbackConstants.REJECT
                else -> HapticFeedbackConstants.CONFIRM
            }
            view.performHapticFeedback(constant, HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING)
        } else {
            view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
        }
    }

    @Serializable
    data class MessageData(
        val feedback: String = "success"
    )

    private companion object {
        const val TAG = "HapticComponent"
    }
}
