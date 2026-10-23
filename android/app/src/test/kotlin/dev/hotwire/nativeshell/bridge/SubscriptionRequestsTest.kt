package dev.hotwire.nativeshell.bridge

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SubscriptionRequestsTest {
    @Test
    fun productIdsKeepThePrimaryIdFirstAndDropBlanks() {
        assertEquals(
            listOf("monthly", "yearly"),
            subscriptionProductIds(" monthly ", listOf("yearly", "monthly", " ", ""))
        )
        assertEquals(listOf("yearly"), subscriptionProductIds(null, listOf("yearly")))
        assertEquals(emptyList<String>(), subscriptionProductIds("  ", null))
    }

    @Test
    fun offerTokenWinsWhenTheStoreReturnedIt() {
        val offers = listOf(
            SubscriptionOfferChoice("monthly", null, "base-token"),
            SubscriptionOfferChoice("monthly", "intro", "intro-token")
        )

        assertEquals("intro-token", selectSubscriptionOffer(offers, "monthly", "intro-token"))
        assertNull(selectSubscriptionOffer(offers, "monthly", "missing"))
    }

    @Test
    fun basePlanPrefersTheOfferWithoutAnOfferId() {
        val offers = listOf(
            SubscriptionOfferChoice("monthly", "intro", "intro-token"),
            SubscriptionOfferChoice("monthly", null, "base-token"),
            SubscriptionOfferChoice("yearly", null, "year-token")
        )

        assertEquals("base-token", selectSubscriptionOffer(offers, "monthly", null))
        assertEquals("year-token", selectSubscriptionOffer(offers, "yearly", " "))
        assertNull(selectSubscriptionOffer(offers, "weekly", null))
    }

    @Test
    fun missingBasePlanUsesTheFirstPlainOffer() {
        val offers = listOf(
            SubscriptionOfferChoice("monthly", "intro", "intro-token"),
            SubscriptionOfferChoice("yearly", null, "year-token")
        )

        assertEquals("year-token", selectSubscriptionOffer(offers, null, null))
        assertEquals("intro-token", selectSubscriptionOffer(listOf(offers[0]), null, null))
        assertNull(selectSubscriptionOffer(emptyList(), null, null))
    }

    @Test
    fun playAccountTokenDropsBlankAndOverlongValues() {
        assertEquals("user-1", playAccountToken(" user-1 "))
        assertNull(playAccountToken(" "))
        assertNull(playAccountToken(null))
        assertNull(playAccountToken("x".repeat(65)))
        assertEquals("x".repeat(64), playAccountToken("x".repeat(64)))
    }

    @Test
    fun replyEchoesRequestedProductIds() {
        val reply = subscriptionReply(
            SubscriptionRequest(productId = "monthly", productIds = listOf("yearly")),
            status = "success",
            packageName = "blog.example.app"
        )

        assertEquals("success", reply.status)
        assertEquals("android", reply.platform)
        assertEquals("monthly", reply.productId)
        assertEquals(listOf("monthly", "yearly"), reply.productIds)
        assertEquals("blog.example.app", reply.packageName)
        assertNull(reply.error)
        assertNull(reply.bundleId)
    }
}
