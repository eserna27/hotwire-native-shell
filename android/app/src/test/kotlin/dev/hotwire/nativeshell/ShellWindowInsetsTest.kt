package dev.hotwire.nativeshell

import org.junit.Assert.assertEquals
import org.junit.Test

class ShellWindowInsetsTest {
    @Test
    fun padsTheStatusBarAndTheNavigationBar() {
        val plan = ShellWindowInsets.plan(
            barLeft = 0,
            barTop = 80,
            barRight = 0,
            barBottom = 48,
            imeBottom = 0
        )
        assertEquals(0, plan.paddingLeft)
        assertEquals(80, plan.paddingTop)
        assertEquals(0, plan.paddingRight)
        assertEquals(48, plan.paddingBottom)
    }

    @Test
    fun keyboardReplacesTheNavigationBarInset() {
        val plan = ShellWindowInsets.plan(
            barLeft = 0,
            barTop = 80,
            barRight = 0,
            barBottom = 48,
            imeBottom = 720
        )
        assertEquals(80, plan.paddingTop)
        assertEquals(720, plan.paddingBottom)
    }

    @Test
    fun navigationBarWinsWhenItIsTallerThanTheKeyboard() {
        val plan = ShellWindowInsets.plan(
            barLeft = 0,
            barTop = 0,
            barRight = 0,
            barBottom = 120,
            imeBottom = 40
        )
        assertEquals(120, plan.paddingBottom)
    }

    @Test
    fun sideSystemBarsPadTheRoot() {
        val plan = ShellWindowInsets.plan(
            barLeft = 96,
            barTop = 40,
            barRight = 24,
            barBottom = 0,
            imeBottom = 0
        )
        assertEquals(96, plan.paddingLeft)
        assertEquals(40, plan.paddingTop)
        assertEquals(24, plan.paddingRight)
        assertEquals(0, plan.paddingBottom)
    }
}
