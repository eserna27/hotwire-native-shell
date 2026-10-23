package dev.hotwire.nativeshell.bridge

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Web → native payload for `purchase`, `restore`, `status`, and `finish`.
 * Product ids are store subscription ids supplied by the host app.
 */
@Serializable
data class SubscriptionRequest(
    @SerialName("product_id") val productId: String? = null,
    @SerialName("product_ids") val productIds: List<String>? = null,
    @SerialName("base_plan_id") val basePlanId: String? = null,
    @SerialName("offer_token") val offerToken: String? = null,
    @SerialName("account_token") val accountToken: String? = null,
    @SerialName("transaction_id") val transactionId: String? = null,
    @SerialName("purchase_token") val purchaseToken: String? = null
)

@Serializable
data class SubscriptionTransaction(
    @SerialName("product_id") val productId: String,
    @SerialName("transaction_id") val transactionId: String? = null,
    @SerialName("original_transaction_id") val originalTransactionId: String? = null,
    @SerialName("purchase_token") val purchaseToken: String? = null,
    @SerialName("order_id") val orderId: String? = null,
    @SerialName("signed_transaction") val signedTransaction: String? = null,
    @SerialName("original_json") val originalJson: String? = null,
    val signature: String? = null,
    val state: String,
    @SerialName("expires_at") val expiresAt: String? = null,
    val acknowledged: Boolean = false,
    val environment: String? = null,
    @SerialName("account_token") val accountToken: String? = null
)

@Serializable
data class SubscriptionReply(
    val status: String,
    val platform: String,
    @SerialName("product_id") val productId: String? = null,
    @SerialName("product_ids") val productIds: List<String> = emptyList(),
    val transactions: List<SubscriptionTransaction> = emptyList(),
    val error: String? = null,
    @SerialName("bundle_id") val bundleId: String? = null,
    @SerialName("package_name") val packageName: String? = null
)

internal data class SubscriptionOfferChoice(
    val basePlanId: String,
    val offerId: String?,
    val offerToken: String
)

internal fun subscriptionProductIds(productId: String?, productIds: List<String>?): List<String> {
    val ids = LinkedHashSet<String>()
    fun add(value: String?) {
        val trimmed = value?.trim().orEmpty()
        if (trimmed.isNotEmpty()) ids.add(trimmed)
    }
    add(productId)
    productIds?.forEach { add(it) }
    return ids.toList()
}

internal fun subscriptionReply(
    request: SubscriptionRequest?,
    status: String,
    error: String? = null,
    transactions: List<SubscriptionTransaction> = emptyList(),
    packageName: String? = null
): SubscriptionReply {
    val ids = subscriptionProductIds(request?.productId, request?.productIds)
    return SubscriptionReply(
        status = status,
        platform = "android",
        productId = ids.firstOrNull(),
        productIds = ids,
        transactions = transactions,
        error = error,
        bundleId = null,
        packageName = packageName
    )
}

/**
 * Play subscription products have one or more base plans, and each base plan
 * has offers. An offer with a null [SubscriptionOfferChoice.offerId] is the
 * base plan itself. A token the page already resolved wins. Otherwise the
 * matching base plan's own offer wins over an introductory offer.
 */
internal fun selectSubscriptionOffer(
    offers: List<SubscriptionOfferChoice>,
    basePlanId: String?,
    offerToken: String?
): String? {
    if (offers.isEmpty()) return null
    val requestedToken = offerToken?.trim().orEmpty()
    if (requestedToken.isNotEmpty()) {
        return offers.firstOrNull { it.offerToken == requestedToken }?.offerToken
    }
    val requestedPlan = basePlanId?.trim().orEmpty()
    val pool = if (requestedPlan.isNotEmpty()) {
        offers.filter { it.basePlanId == requestedPlan }
    } else {
        offers
    }
    if (pool.isEmpty()) return null
    return pool.firstOrNull { it.offerId.isNullOrBlank() }?.offerToken ?: pool.first().offerToken
}

/** Play's obfuscated account id is at most 64 characters and must not be PII. */
internal fun playAccountToken(raw: String?): String? {
    val token = raw?.trim().orEmpty()
    if (token.isEmpty() || token.length > 64) return null
    return token
}
