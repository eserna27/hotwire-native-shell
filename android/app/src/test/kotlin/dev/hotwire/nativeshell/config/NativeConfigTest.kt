package dev.hotwire.nativeshell.config

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeConfigTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun bundledShapeResolvesLocalizedTitlesAndLocations() {
        val config = decode(
            """
            {
              "name": "itsjustmy",
              "base_url": "https://itsjustmy.blog",
              "start_path": "/",
              "tabs": [
                {
                  "id": "home",
                  "title": "Inicio",
                  "titles": { "es": "Inicio", "en": "Home" },
                  "path": "/",
                  "icon": "home"
                },
                {
                  "id": "about",
                  "title": "Acerca",
                  "titles": { "es": "Acerca", "en": "About" },
                  "path": "/acerca",
                  "icon": "info",
                  "sf_symbol": "info.circle"
                },
                {
                  "id": "sign_in",
                  "title": "Entrar",
                  "titles": { "ES": "Entrar", "en": "Sign in" },
                  "path": "/users/sign_in",
                  "icon": "profile",
                  "android_icon": "ic_tab_profile"
                }
              ]
            }
            """.trimIndent()
        )

        val spanish = config.resolveTabs("es-MX")
        assertEquals(listOf("Inicio", "Acerca", "Entrar"), spanish.tabs.map { it.title })
        assertEquals(
            listOf(
                "https://itsjustmy.blog/",
                "https://itsjustmy.blog/acerca",
                "https://itsjustmy.blog/users/sign_in"
            ),
            spanish.tabs.map { it.location }
        )
        assertEquals("ic_tab_profile", spanish.tabs[2].androidIcon)
        assertEquals(0, spanish.dropped)
        assertEquals(0, spanish.overflow)

        val english = config.resolveTabs("en-US")
        assertEquals(listOf("Home", "About", "Sign in"), english.tabs.map { it.title })
    }

    @Test
    fun fewerThanTwoTabsStayResolvedForTheSingleNavigator() {
        val config = decode(
            """
            {"name":"itsjustmy","base_url":"https://itsjustmy.blog","tabs":[
              {"id":"only","title":"Solo","path":"/acerca"}
            ]}
            """.trimIndent()
        )
        val resolution = config.resolveTabs("en")
        assertEquals(1, resolution.tabs.size)
        assertEquals("https://itsjustmy.blog/acerca", resolution.tabs.single().location)
    }

    @Test
    fun badEntriesAreSkippedAndTheDocumentStillDecodes() {
        val config = decode(
            """
            {
              "name": "itsjustmy",
              "base_url": "https://itsjustmy.blog",
              "future_key": true,
              "tabs": [
                "nope",
                {"id":"","title":"Missing id","path":"/"},
                {"id":"bad id","title":"Spaces","path":"/"},
                {"id":"home","title":"Inicio","path":"/"},
                {"id":"home","title":"Duplicate","path":"/acerca"},
                {"id":"blank","title":"   ","path":"/"},
                {"title":"No id","path":"/"},
                {"id":"offsite","title":"Away","url":"https://eserna27.itsjustmy.blog/","path":"/ignored"},
                {"id":"script","title":"Script","url":"javascript:alert(1)","path":"/acerca"},
                {"id":"not-a-url","title":"Bad","path":"https://evil.example/"},
                4,
                {"id":"local","titles":{"es":"Local","en":"Local EN"},"path":"privacidad"}
              ]
            }
            """.trimIndent()
        )

        val resolution = config.resolveTabs("es")
        assertEquals(listOf("home", "offsite", "script", "local"), resolution.tabs.map { it.id })
        assertEquals("https://eserna27.itsjustmy.blog/", resolution.tabs[1].location)
        assertEquals("https://itsjustmy.blog/acerca", resolution.tabs[2].location)
        assertEquals("https://itsjustmy.blog/privacidad", resolution.tabs[3].location)
        assertEquals("Local", resolution.tabs[3].title)
        assertTrue(resolution.dropped >= 6)
        assertEquals("https://itsjustmy.blog/", config.startLocation)

        val encoded = json.encodeToString(NativeConfig.serializer(), config)
        val again = json.decodeFromString(NativeConfig.serializer(), encoded)
        assertEquals(resolution.tabs.map { it.id }, again.resolveTabs("es").tabs.map { it.id })
    }

    @Test
    fun nonArrayTabsAndOverflowDoNotCrash() {
        val notArray = decode(
            """
            {"name":"itsjustmy","base_url":"https://itsjustmy.blog","tabs":{"id":"home"}}
            """.trimIndent()
        )
        assertTrue(notArray.resolveTabs("en").tabs.isEmpty())
        assertEquals("https://itsjustmy.blog/", notArray.startLocation)

        val many = (1..6).joinToString(",") { index ->
            """{"id":"t$index","title":"Tab $index","path":"/$index"}"""
        }
        val overflow = decode(
            """
            {"name":"itsjustmy","base_url":"https://itsjustmy.blog","tabs":[$many]}
            """.trimIndent()
        ).resolveTabs("en")
        assertEquals(5, overflow.tabs.size)
        assertEquals(1, overflow.overflow)
        assertEquals("t1", overflow.tabs.first().id)
        assertEquals("t5", overflow.tabs.last().id)
    }

    @Test
    fun titleObjectAndUnknownAndroidIcon() {
        val config = decode(
            """
            {"name":"itsjustmy","base_url":"http://10.0.2.2:9292","tabs":[
              {"id":"home","title":{"es":"Inicio","en":"Home"},"path":"/","icon":"Nope","android_icon":"../secrets","sf_symbol":"not a symbol"}
            ]}
            """.trimIndent()
        )
        val tab = config.resolveTabs("en").tabs.single()
        assertEquals("Home", tab.title)
        assertEquals("nope", tab.icon)
        assertEquals("", tab.androidIcon)
        assertEquals("http://10.0.2.2:9292/", tab.location)
        assertEquals(NativeConfig.FALLBACK_LOCATION, config.locationFor(""))
    }

    @Test
    fun bridgePayloadSelectsTheFirstKeptActiveTab() {
        val presented = parsePresentedTabs(
            """
            {"tabs":[
              {"id":"","title":"Bad","path":"/","active":true},
              {"id":"home","title":"Home","path":"/","active":false},
              {"id":"about","title":"About","path":"/acerca","active":"true"}
            ]}
            """.trimIndent(),
            "https://itsjustmy.blog",
            "en"
        )
        checkNotNull(presented)
        assertEquals(listOf("home", "about"), presented.resolution.tabs.map { it.id })
        assertEquals(1, presented.selectedIndex)
        assertEquals(1, presented.resolution.dropped)

        val duplicate = parsePresentedTabs(
            """
            {"tabs":[
              {"id":"home","title":"Home","path":"/","active":false},
              {"id":"home","title":"Other","path":"/acerca","active":true}
            ]}
            """.trimIndent(),
            "https://itsjustmy.blog",
            "en"
        )
        checkNotNull(duplicate)
        assertEquals("https://itsjustmy.blog/", duplicate.resolution.tabs.single().location)
        assertNull(duplicate.selectedIndex)
    }

    @Test
    fun bridgePayloadWithoutAnArrayLeavesTheBarAlone() {
        assertNull(parsePresentedTabs("{}", "https://itsjustmy.blog", "en"))
        assertNull(parsePresentedTabs("""{"tabs":{"id":"home"}}""", "https://itsjustmy.blog", "en"))
        assertNull(parsePresentedTabs("[]", "https://itsjustmy.blog", "en"))
        assertNull(parsePresentedTabs("not json", "https://itsjustmy.blog", "en"))
    }

    @Test
    fun emptyBridgeArrayClearsTheBarAndActivePastTheCapIsDropped() {
        val empty = parsePresentedTabs("""{"tabs":[]}""", "https://itsjustmy.blog", "en")
        checkNotNull(empty)
        assertTrue(empty.resolution.tabs.isEmpty())
        assertNull(empty.selectedIndex)

        val many = (1..6).joinToString(",") { index ->
            val active = if (index == 6) ""","active":true""" else ""
            """{"id":"t$index","title":"Tab $index","path":"/$index"$active}"""
        }
        val overflow = parsePresentedTabs(
            """{"tabs":[$many]}""",
            "https://itsjustmy.blog",
            "en"
        )
        checkNotNull(overflow)
        assertEquals(5, overflow.resolution.tabs.size)
        assertEquals(1, overflow.resolution.overflow)
        assertNull(overflow.selectedIndex)
        assertEquals("t5", overflow.resolution.tabs.last().id)
    }

    private fun decode(body: String): NativeConfig {
        return json.decodeFromString(NativeConfig.serializer(), body)
    }
}
