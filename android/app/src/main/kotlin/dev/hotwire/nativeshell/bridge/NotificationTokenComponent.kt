package dev.hotwire.nativeshell.bridge

import android.util.Log
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable

/**
 * Stimulus: `static component = "notification-token"`.
 *
 * Replies to `connect` and `get` with a placeholder token. This is not an FCM
 * registration token. Wire Firebase in the client app before sending the
 * value to Rails. See docs/BRIDGES.md.
 */
class NotificationTokenComponent(
    name: String,
    bridgeDelegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, bridgeDelegate) {

    override fun onReceive(message: Message) {
        when (message.event) {
            "connect", "get" -> replyTo(
                message.event,
                TokenResponse(token = PLACEHOLDER_TOKEN, provider = "placeholder")
            )
            else -> Log.w(TAG, "Unknown event for message: $message")
        }
    }

    @Serializable
    data class TokenResponse(
        val token: String,
        val provider: String
    )

    private companion object {
        const val TAG = "NotificationToken"
        const val PLACEHOLDER_TOKEN = "placeholder-not-a-device-token"
    }
}
