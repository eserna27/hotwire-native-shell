package dev.hotwire.nativeshell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class FirstVisitSplashTest {
    @Before
    fun reset() {
        FirstVisitSplash.reset()
    }

    @Test
    fun splashStaysUntilTheVisitSettlesOrTheTimeout() {
        assertTrue(FirstVisitSplash.shouldKeepOnScreen(0))
        assertTrue(FirstVisitSplash.shouldKeepOnScreen(FirstVisitSplash.TIMEOUT_MS - 1))
        assertFalse(FirstVisitSplash.shouldKeepOnScreen(FirstVisitSplash.TIMEOUT_MS))

        FirstVisitSplash.settle(null)
        assertFalse(FirstVisitSplash.shouldKeepOnScreen(0))
    }
}
