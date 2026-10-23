package dev.hotwire.nativeshell.bridge

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams

/**
 * One Play Billing connection for the process. Purchases are not acknowledged
 * here. The page verifies the token on the server, then sends `finish`.
 */
internal class SubscriptionBilling(private val appContext: Context) {
    private val main = Handler(Looper.getMainLooper())
    private val client: BillingClient
    private val waiters = ArrayDeque<(BillingClient?) -> Unit>()
    private var connecting = false
    private var purchaseActive = false

    init {
        client = BillingClient.newBuilder(appContext)
            .setListener { result, purchases ->
                main.post { onPurchasesUpdated(result, purchases) }
            }
            .enablePendingPurchases(
                PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()
            )
            .enableAutoServiceReconnection()
            .build()
    }

    fun purchase(activity: Activity, request: SubscriptionRequest, callback: (SubscriptionReply) -> Unit) {
        main.post {
            if (purchaseActive) {
                callback(reply(request, "error", "busy"))
                return@post
            }
            val productId = subscriptionProductIds(request.productId, request.productIds).firstOrNull()
            if (productId == null) {
                callback(reply(request, "error", "missing_product_id"))
                return@post
            }
            purchaseActive = true
            var completed = false
            fun finish(payload: SubscriptionReply) {
                if (completed) return
                completed = true
                purchaseActive = false
                purchaseCallback = null
                callback(payload)
            }
            purchaseCallback = { result, purchases ->
                deliverPurchase(request, result, purchases, ::finish)
            }
            connect { billing ->
                if (billing == null) {
                    finish(reply(request, "error", "store_unavailable"))
                    return@connect
                }
                queryProduct(billing, productId) { details, result ->
                    if (!purchaseActive || completed) return@queryProduct
                    if (details == null) {
                        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                            val (status, error) = statusAndError(result)
                            finish(reply(request, status, error))
                        } else {
                            finish(reply(request, "error", "product_unavailable"))
                        }
                        return@queryProduct
                    }
                    val offerToken = selectSubscriptionOffer(
                        offers = details.subscriptionOfferDetails.orEmpty().map { offer ->
                            SubscriptionOfferChoice(
                                basePlanId = offer.basePlanId,
                                offerId = offer.offerId,
                                offerToken = offer.offerToken
                            )
                        },
                        basePlanId = request.basePlanId,
                        offerToken = request.offerToken
                    )
                    if (offerToken == null) {
                        finish(reply(request, "error", "offer_unavailable"))
                        return@queryProduct
                    }
                    val productParams = BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(details)
                        .setOfferToken(offerToken)
                        .build()
                    val flow = BillingFlowParams.newBuilder()
                        .setProductDetailsParamsList(listOf(productParams))
                    playAccountToken(request.accountToken)?.let { flow.setObfuscatedAccountId(it) }
                    val launched = billing.launchBillingFlow(activity, flow.build())
                    if (launched.responseCode == BillingClient.BillingResponseCode.OK) return@queryProduct
                    // The sheet did not open. Drop the listener so a late callback cannot reply twice.
                    purchaseCallback = null
                    if (launched.responseCode == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED) {
                        queryOwned(billing, request) { payload ->
                            finish(payload.copy(status = "error", error = "already_owned"))
                        }
                        return@queryProduct
                    }
                    val (status, error) = statusAndError(launched)
                    Log.w(TAG, "launchBillingFlow ${launched.responseCode} ${launched.debugMessage}")
                    finish(reply(request, status, error))
                }
            }
        }
    }

    fun query(request: SubscriptionRequest, callback: (SubscriptionReply) -> Unit) {
        main.post {
            connect { billing ->
                if (billing == null) {
                    callback(reply(request, "error", "store_unavailable"))
                    return@connect
                }
                queryOwned(billing, request, callback)
            }
        }
    }

    fun acknowledge(request: SubscriptionRequest, callback: (SubscriptionReply) -> Unit) {
        main.post {
            val token = request.purchaseToken?.trim().orEmpty()
            val transactionId = request.transactionId?.trim().orEmpty()
            val productId = subscriptionProductIds(request.productId, request.productIds).firstOrNull().orEmpty()
            if (token.isEmpty() && transactionId.isEmpty() && productId.isEmpty()) {
                callback(reply(request, "error", "not_found"))
                return@post
            }
            connect { billing ->
                if (billing == null) {
                    callback(reply(request, "error", "store_unavailable"))
                    return@connect
                }
                querySubs(billing) { result, purchases ->
                    if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                        val (status, error) = statusAndError(result)
                        Log.w(TAG, "queryPurchases ${result.responseCode} ${result.debugMessage}")
                        callback(reply(request, status, error))
                        return@querySubs
                    }
                    val matches = purchases.filter { purchase ->
                        when {
                            token.isNotEmpty() -> purchase.purchaseToken == token
                            transactionId.isNotEmpty() -> purchase.orderId == transactionId
                            else -> purchase.products.contains(productId)
                        }
                    }
                    if (matches.isEmpty()) {
                        callback(reply(request, "error", "not_found"))
                        return@querySubs
                    }
                    acknowledgeAll(billing, request, matches, callback)
                }
            }
        }
    }

    private var purchaseCallback: ((BillingResult, List<Purchase>?) -> Unit)? = null

    private fun onPurchasesUpdated(result: BillingResult, purchases: List<Purchase>?) {
        val callback = purchaseCallback ?: return
        purchaseCallback = null
        callback(result, purchases)
    }

    private fun deliverPurchase(
        request: SubscriptionRequest,
        result: BillingResult,
        purchases: List<Purchase>?,
        finish: (SubscriptionReply) -> Unit
    ) {
        when (result.responseCode) {
            BillingClient.BillingResponseCode.OK -> {
                val transactions = purchases.orEmpty().flatMap { it.toSubscriptionTransactions() }
                val status = when {
                    transactions.any { it.state == "purchased" } -> "success"
                    transactions.any { it.state == "pending" } -> "pending"
                    else -> "success"
                }
                finish(reply(request, status, transactions = transactions))
            }
            BillingClient.BillingResponseCode.USER_CANCELED -> finish(reply(request, "cancelled"))
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> {
                connect { billing ->
                    if (billing == null) {
                        finish(reply(request, "error", "already_owned"))
                        return@connect
                    }
                    queryOwned(billing, request) { payload ->
                        finish(payload.copy(status = "error", error = "already_owned"))
                    }
                }
            }
            else -> {
                val (status, error) = statusAndError(result)
                Log.w(TAG, "onPurchasesUpdated ${result.responseCode} ${result.debugMessage}")
                finish(reply(request, status, error))
            }
        }
    }

    private fun queryOwned(
        billing: BillingClient,
        request: SubscriptionRequest,
        callback: (SubscriptionReply) -> Unit
    ) {
        querySubs(billing) { result, purchases ->
            if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                val (status, error) = statusAndError(result)
                Log.w(TAG, "queryPurchases ${result.responseCode} ${result.debugMessage}")
                callback(reply(request, status, error))
                return@querySubs
            }
            val ids = subscriptionProductIds(request.productId, request.productIds).toSet()
            val transactions = purchases.flatMap { it.toSubscriptionTransactions() }
                .filter { ids.isEmpty() || it.productId in ids }
            callback(reply(request, "success", transactions = transactions))
        }
    }

    private fun acknowledgeAll(
        billing: BillingClient,
        request: SubscriptionRequest,
        matches: List<Purchase>,
        callback: (SubscriptionReply) -> Unit
    ) {
        val pending = matches.any { it.purchaseState == Purchase.PurchaseState.PENDING }
        val toAcknowledge = matches.filter {
            it.purchaseState == Purchase.PurchaseState.PURCHASED && !it.isAcknowledged
        }
        if (toAcknowledge.isEmpty()) {
            val status = if (pending && matches.none { it.purchaseState == Purchase.PurchaseState.PURCHASED }) {
                "pending"
            } else {
                "success"
            }
            callback(reply(request, status, transactions = matches.flatMap { it.toSubscriptionTransactions() }))
            return
        }
        var remaining = toAcknowledge.size
        var failed = false
        val acknowledgedTokens = mutableSetOf<String>()
        toAcknowledge.forEach { purchase ->
            val params = AcknowledgePurchaseParams.newBuilder()
                .setPurchaseToken(purchase.purchaseToken)
                .build()
            billing.acknowledgePurchase(params) { result ->
                main.post {
                    if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                        acknowledgedTokens.add(purchase.purchaseToken)
                    } else {
                        failed = true
                        Log.w(TAG, "acknowledge ${result.responseCode} ${result.debugMessage}")
                    }
                    remaining -= 1
                    if (remaining > 0) return@post
                    val transactions = matches.flatMap { item ->
                        item.toSubscriptionTransactions().map { transaction ->
                            if (item.purchaseToken in acknowledgedTokens) {
                                transaction.copy(acknowledged = true)
                            } else {
                                transaction
                            }
                        }
                    }
                    if (failed) {
                        callback(reply(request, "error", "unknown", transactions))
                    } else {
                        callback(reply(request, "success", transactions = transactions))
                    }
                }
            }
        }
    }

    private fun queryProduct(
        billing: BillingClient,
        productId: String,
        block: (ProductDetails?, BillingResult) -> Unit
    ) {
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                listOf(
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(productId)
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()
                )
            )
            .build()
        billing.queryProductDetailsAsync(params) { result, details ->
            main.post {
                if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                    Log.w(TAG, "queryProductDetails ${result.responseCode} ${result.debugMessage}")
                    block(null, result)
                    return@post
                }
                val match = details.productDetailsList.firstOrNull { it.productId == productId }
                block(match, result)
            }
        }
    }

    private fun querySubs(
        billing: BillingClient,
        block: (BillingResult, List<Purchase>) -> Unit
    ) {
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.SUBS)
            .build()
        billing.queryPurchasesAsync(params) { result, purchases ->
            main.post { block(result, purchases) }
        }
    }

    private fun connect(block: (BillingClient?) -> Unit) {
        if (client.isReady) {
            block(client)
            return
        }
        waiters.add(block)
        if (connecting) return
        connecting = true
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                main.post {
                    connecting = false
                    val ready = result.responseCode == BillingClient.BillingResponseCode.OK && client.isReady
                    if (!ready) {
                        Log.w(TAG, "billing setup ${result.responseCode} ${result.debugMessage}")
                    }
                    val pending = waiters.toList()
                    waiters.clear()
                    pending.forEach { waiter -> waiter(if (ready) client else null) }
                }
            }

            override fun onBillingServiceDisconnected() {
                Log.i(TAG, "Play Billing disconnected")
            }
        })
    }

    private fun reply(
        request: SubscriptionRequest,
        status: String,
        error: String? = null,
        transactions: List<SubscriptionTransaction> = emptyList()
    ): SubscriptionReply {
        return subscriptionReply(
            request = request,
            status = status,
            error = error,
            transactions = transactions,
            packageName = appContext.packageName
        )
    }

    private fun statusAndError(result: BillingResult): Pair<String, String?> {
        return when (result.responseCode) {
            BillingClient.BillingResponseCode.OK -> "success" to null
            BillingClient.BillingResponseCode.USER_CANCELED -> "cancelled" to null
            BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> "error" to "already_owned"
            BillingClient.BillingResponseCode.ITEM_UNAVAILABLE -> "error" to "product_unavailable"
            BillingClient.BillingResponseCode.ITEM_NOT_OWNED -> "error" to "not_found"
            BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE,
            BillingClient.BillingResponseCode.SERVICE_DISCONNECTED,
            BillingClient.BillingResponseCode.NETWORK_ERROR -> "error" to "network"
            BillingClient.BillingResponseCode.BILLING_UNAVAILABLE,
            BillingClient.BillingResponseCode.FEATURE_NOT_SUPPORTED -> "error" to "store_unavailable"
            else -> "error" to "unknown"
        }
    }

    private fun Purchase.toSubscriptionTransactions(): List<SubscriptionTransaction> {
        val state = when (purchaseState) {
            Purchase.PurchaseState.PURCHASED -> "purchased"
            Purchase.PurchaseState.PENDING -> "pending"
            else -> "unknown"
        }
        val account = accountIdentifiers?.obfuscatedAccountId
        val productIds = products.ifEmpty { listOf("") }.filter { it.isNotEmpty() }
        return productIds.map { productId ->
            SubscriptionTransaction(
                productId = productId,
                transactionId = orderId,
                purchaseToken = purchaseToken,
                orderId = orderId,
                originalJson = originalJson,
                signature = signature,
                state = state,
                acknowledged = isAcknowledged,
                accountToken = account
            )
        }
    }

    companion object {
        private const val TAG = "SubscriptionBilling"
        private val lock = Any()
        private var instance: SubscriptionBilling? = null

        fun get(context: Context): SubscriptionBilling {
            return synchronized(lock) {
                instance ?: SubscriptionBilling(context.applicationContext).also { instance = it }
            }
        }
    }
}
