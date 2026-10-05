package dev.hotwire.nativeshell.config

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TabChromePlanTest {
    private val origin = "https://itsjustmy.blog"
    private val signIn = "$origin/users/sign_in"

    private val signedIn = listOf(
        tab("home", "/dashboard"),
        tab("posts", "/dashboard/posts"),
        tab("account", "/dashboard/settings")
    )

    private val cachedPublic = listOf(
        tab("home", "/"),
        tab("about", "/acerca"),
        tab("sign_in", "/users/sign_in")
    )

    @Test
    fun loginReplacesTheSignInNavigatorWithTheActiveTab() {
        val next = presented(signedIn, active = "home")
        val decision = TabChromePlan.decide(
            currentTabs = emptyList(),
            next = next,
            sourceLocation = signIn,
            currentIndex = null,
            isModal = false
        )
        val replace = decision as TabChromeDecision.Replace
        assertEquals(listOf("home", "posts", "account"), replace.presented.resolution.tabs.map { it.id })
        assertEquals(0, replace.presented.selectedIndex)
        assertNull(replace.presented.singleRoot)
    }

    @Test
    fun logoutRootsAFreshNavigatorOnTheSignInPage() {
        val decision = TabChromePlan.decide(
            currentTabs = signedIn,
            next = presented(emptyList(), active = null),
            sourceLocation = "$signIn?from=logout",
            currentIndex = 2,
            isModal = false
        )
        val replace = decision as TabChromeDecision.Replace
        assertTrue(replace.presented.resolution.tabs.isEmpty())
        assertEquals("$signIn?from=logout", replace.presented.singleRoot)
    }

    @Test
    fun aLaterEmptyListDoesNotReplaceAgain() {
        val decision = TabChromePlan.decide(
            currentTabs = emptyList(),
            next = presented(emptyList(), active = null),
            sourceLocation = "$origin/users/password/new",
            currentIndex = null,
            isModal = false
        )
        assertEquals(TabChromeDecision.Keep, decision)
    }

    @Test
    fun theFirstPageReplacesACachedTabList() {
        val signedOut = TabChromePlan.decide(
            currentTabs = cachedPublic,
            next = presented(emptyList(), active = null),
            sourceLocation = signIn,
            currentIndex = 0,
            isModal = false
        ) as TabChromeDecision.Replace
        assertTrue(signedOut.presented.resolution.tabs.isEmpty())
        assertEquals(signIn, signedOut.presented.singleRoot)

        val signedInDecision = TabChromePlan.decide(
            currentTabs = cachedPublic,
            next = presented(signedIn, active = "home"),
            sourceLocation = "$origin/dashboard",
            currentIndex = 0,
            isModal = false
        ) as TabChromeDecision.Replace
        assertEquals("home", signedInDecision.presented.resolution.tabs.first().id)
        assertNull(signedInDecision.presented.singleRoot)
    }

    @Test
    fun aPageWithNoActiveTabDoesNotChangeSelection() {
        val decision = TabChromePlan.decide(
            currentTabs = signedIn,
            next = presented(signedIn, active = null),
            sourceLocation = "$origin/dashboard/posts/123",
            currentIndex = 1,
            isModal = false
        )
        assertEquals(TabChromeDecision.Keep, decision)
    }

    @Test
    fun aCrossTabVisitRoutesToTheLongestMatchingTab() {
        val decision = TabChromePlan.decide(
            currentTabs = signedIn,
            next = presented(signedIn, active = "home"),
            sourceLocation = "$origin/dashboard/settings/profile",
            currentIndex = 0,
            isModal = false
        )
        val route = decision as TabChromeDecision.Route
        assertEquals(2, route.index)
        assertEquals("$origin/dashboard/settings/profile", route.location)
    }

    @Test
    fun anActiveFlagForATabThatDoesNotOwnThePageLeavesItVisible() {
        val decision = TabChromePlan.decide(
            currentTabs = signedIn,
            next = presented(signedIn, active = "home"),
            sourceLocation = "$origin/eserna27/a-post",
            currentIndex = 1,
            isModal = false
        )
        assertEquals(TabChromeDecision.Keep, decision)
    }

    @Test
    fun aModalDoesNotRebuildOrSwitch() {
        val decision = TabChromePlan.decide(
            currentTabs = signedIn,
            next = presented(emptyList(), active = null),
            sourceLocation = "$origin/dashboard/posts/new",
            currentIndex = 1,
            isModal = true
        )
        assertEquals(TabChromeDecision.Ignore, decision)
    }

    @Test
    fun oneUsableTabUsesThatTabInsteadOfTheSender() {
        val only = listOf(tab("home", "/dashboard"))
        val decision = TabChromePlan.decide(
            currentTabs = signedIn,
            next = presented(only, active = "home"),
            sourceLocation = signIn,
            currentIndex = 0,
            isModal = false
        ) as TabChromeDecision.Replace
        assertEquals(1, decision.presented.resolution.tabs.size)
        assertNull(decision.presented.singleRoot)
    }

    @Test
    fun pathOwnershipPrefersTheLongestPrefixAndARootOwnsItsOrigin() {
        val blog = ResolvedTab(
            id = "blog",
            title = "Mi blog",
            location = "https://eserna27.itsjustmy.blog/",
            icon = "home",
            androidIcon = ""
        )
        val tabs = signedIn + blog
        assertEquals(0, TabChromePlan.owningTabIndex("$origin/dashboard", tabs))
        assertEquals(1, TabChromePlan.owningTabIndex("$origin/dashboard/posts/123", tabs))
        assertEquals(1, TabChromePlan.owningTabIndex("$origin/dashboard/posts/new", tabs))
        assertEquals(2, TabChromePlan.owningTabIndex("$origin/dashboard/settings", tabs))
        assertEquals(3, TabChromePlan.owningTabIndex("https://eserna27.itsjustmy.blog/a-post", tabs))
        assertNull(TabChromePlan.owningTabIndex("$origin/eserna27/a-post", tabs))
        assertTrue(TabChromePlan.sameDocument("$origin/dashboard/", "$origin/dashboard?x=1"))
    }

    private fun presented(tabs: List<ResolvedTab>, active: String?): PresentedTabs {
        return PresentedTabs(
            resolution = TabResolution(tabs = tabs, dropped = 0, overflow = 0),
            selectedIndex = active?.let { id -> tabs.indexOfFirst { it.id == id }.takeIf { it >= 0 } }
        )
    }

    private fun tab(id: String, path: String): ResolvedTab {
        return ResolvedTab(
            id = id,
            title = id,
            location = origin + path,
            icon = "home",
            androidIcon = ""
        )
    }
}
