package dev.hotwire.nativeshell.config

import org.junit.Assert.assertEquals
import org.junit.Test

class NavigatorHostPlanTest {
    private val main = "main"
    // ShellTabs always emits five hosts, including the unused ones. An empty
    // bridge list still has to name those ids so logout can restore them.
    private val tabHosts = listOf("tab0", "tab1", "tab2", "tab3", "tab4")

    @Test
    fun noTabsKeepsMainFirstAndStillListsEveryTabHost() {
        val ordered = NavigatorHostPlan.order(main, tabHosts, presentedTabCount = 0)
        assertEquals(main, ordered.first())
        assertEquals(tabHosts, ordered.drop(1))
    }

    @Test
    fun oneTabKeepsTheSingleNavigatorHostFirst() {
        val ordered = NavigatorHostPlan.order(main, tabHosts, presentedTabCount = 1)
        assertEquals(listOf(main) + tabHosts, ordered)
    }

    @Test
    fun fourTabsKeepMainLastSoTheRestoredSingleHostStillResolves() {
        val ordered = NavigatorHostPlan.order(main, tabHosts, presentedTabCount = 4)
        assertEquals(tabHosts + main, ordered)
    }

    @Test
    fun twoTabsLeadWithTheTabHosts() {
        val ordered = NavigatorHostPlan.order(main, tabHosts, presentedTabCount = 2)
        assertEquals(tabHosts.first(), ordered.first())
        assertEquals(main, ordered.last())
        assertEquals(tabHosts.toSet() + main, ordered.toSet())
    }
}
