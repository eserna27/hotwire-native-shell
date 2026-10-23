package dev.hotwire.nativeshell.bridge

import android.util.Log
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination

/**
 * Stimulus: `static component = "subscription"`.
 *
 * Events: `purchase`, `restore`, `status`, `finish`. The page sends store
 * subscription product ids. This shell buys through Play Billing and replies
 * with the purchase token. It does not acknowledge until `finish`, which the
 * page sends after its server has verified the token.
 */
class SubscriptionComponent(
    name: String,
    private val bridgeDelegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, bridgeDelegate) {

    override fun onReceive(message: Message) {
        when (message.event) {
            "purchase" -> purchase(message)
            "restore", "status" -> query(message)
            "finish" -> finish(message)
            "disconnect" -> Unit
            else -> Log.w(TAG, "Unknown event for message: ${message.event}")
        }
    }

    private fun purchase(message: Message) {
        val request = message.data<SubscriptionRequest>()
        if (request == null) {
            send(message.event, subscriptionReply(null, "error", "invalid_payload"))
            return
        }
        val activity = bridgeDelegate.destination.fragment.activity
        val context = bridgeDelegate.destination.fragment.context
        if (activity == null || context == null) {
            send(message.event, subscriptionReply(request, "error", "store_unavailable"))
            return
        }
        SubscriptionBilling.get(context).purchase(activity, request) { payload ->
            send(message.event, payload)
        }
    }

    private fun query(message: Message) {
        val request = message.data<SubscriptionRequest>() ?: SubscriptionRequest()
        val context = bridgeDelegate.destination.fragment.context
        if (context == null) {
            send(message.event, subscriptionReply(request, "error", "store_unavailable"))
            return
        }
        SubscriptionBilling.get(context).query(request) { payload ->
            send(message.event, payload)
        }
    }

    private fun finish(message: Message) {
        val request = message.data<SubscriptionRequest>()
        if (request == null) {
            send(message.event, subscriptionReply(null, "error", "invalid_payload"))
            return
        }
        val context = bridgeDelegate.destination.fragment.context
        if (context == null) {
            send(message.event, subscriptionReply(request, "error", "store_unavailable"))
            return
        }
        SubscriptionBilling.get(context).acknowledge(request) { payload ->
            send(message.event, payload)
        }
    }

    private fun send(event: String, payload: SubscriptionReply) {
        try {
            replyTo(event, payload)
        } catch (error: RuntimeException) {
            Log.w(TAG, "Subscription reply failed for $event")
        }
    }

    private companion object {
        const val TAG = "SubscriptionComponent"
    }
}
