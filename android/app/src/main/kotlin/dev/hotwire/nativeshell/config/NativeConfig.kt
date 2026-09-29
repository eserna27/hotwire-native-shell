package dev.hotwire.nativeshell.config

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.buildClassSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.put
import java.net.URI

/**
 * Rails `GET /native/config` document.
 *
 * Unknown keys are ignored so the server can add fields before the shell
 * ships a matching release. Missing bridge flags default to off. A bad `tabs`
 * entry is skipped; it does not reject the rest of the document.
 */
@Serializable
data class NativeConfig(
    val name: String,
    @SerialName("base_url") val baseUrl: String,
    @SerialName("start_path") val startPath: String = "/",
    @Serializable(with = NativeTabListSerializer::class)
    val tabs: List<NativeTab> = emptyList(),
    val bridges: BridgeFlags = BridgeFlags(),
    val push: PushConfig = PushConfig()
) {
    val startLocation: String
        get() = locationFor(startPath)

    fun locationFor(path: String): String {
        return joinHttp(baseUrl, path) ?: FALLBACK_LOCATION
    }

    /**
     * Cold-start tabs from this document. Fewer than two means one navigator
     * and no bottom bar; a single kept tab still supplies that navigator's
     * start location. At most [MAX_TABS] are kept, in document order.
     *
     * The `tabs` bridge replaces this list once a page connects.
     */
    fun resolveTabs(languageTag: String): TabResolution {
        return presentTabs(baseUrl, tabs.map { it to false }, languageTag).resolution
    }

    companion object {
        const val MAX_TABS = 5
        const val FALLBACK_LOCATION = "about:blank"
    }
}

data class TabResolution(
    val tabs: List<ResolvedTab>,
    val dropped: Int,
    val overflow: Int
)

data class PresentedTabs(
    val resolution: TabResolution,
    val selectedIndex: Int
)

private val bridgeJson = Json { ignoreUnknownKeys = true }

/**
 * Parses a `tabs` bridge `connect` payload. Returns null when `tabs` is
 * missing or the body is not an object, so a bad message leaves the current
 * bar alone. A present array is applied even if every entry is skipped.
 */
fun parsePresentedTabs(jsonData: String, baseUrl: String, languageTag: String): PresentedTabs? {
    val root = runCatching { bridgeJson.parseToJsonElement(jsonData) }.getOrNull() as? JsonObject ?: return null
    val tabsElement = root["tabs"] ?: return null
    val array = tabsElement as? JsonArray ?: return null
    val items = array.map { element ->
        val tab = runCatching { bridgeJson.decodeFromJsonElement(NativeTabSerializer, element) }
            .getOrDefault(NativeTab())
        tab to element.isActive()
    }
    return presentTabs(baseUrl, items, languageTag)
}

fun presentTabs(
    baseUrl: String,
    items: List<Pair<NativeTab, Boolean>>,
    languageTag: String
): PresentedTabs {
    val seen = mutableSetOf<String>()
    val valid = mutableListOf<Pair<ResolvedTab, Boolean>>()
    var dropped = 0
    for ((tab, active) in items) {
        val resolved = tab.resolve(baseUrl, languageTag)
        if (resolved == null || !seen.add(resolved.id)) {
            dropped += 1
            continue
        }
        valid += resolved to active
    }
    val overflow = (valid.size - NativeConfig.MAX_TABS).coerceAtLeast(0)
    val kept = valid.take(NativeConfig.MAX_TABS)
    val selected = kept.indexOfFirst { it.second }.let { if (it < 0) 0 else it }
    return PresentedTabs(
        resolution = TabResolution(
            tabs = kept.map { it.first },
            dropped = dropped,
            overflow = overflow
        ),
        selectedIndex = selected
    )
}

private fun JsonElement.isActive(): Boolean {
    val primitive = this as? JsonObject
    val value = primitive?.get("active") as? JsonPrimitive ?: return false
    if (value.booleanOrNull == true) return true
    return value.isString && value.content.equals("true", ignoreCase = true)
}

data class ResolvedTab(
    val id: String,
    val title: String,
    val location: String,
    val icon: String,
    val androidIcon: String
)

/**
 * One declared tab, before validation. Blank or illegal fields survive
 * decoding and are dropped by [NativeConfig.resolveTabs].
 */
@Serializable(with = NativeTabSerializer::class)
data class NativeTab(
    val id: String = "",
    val title: String = "",
    val titles: Map<String, String> = emptyMap(),
    val path: String = "",
    val url: String = "",
    val icon: String = "home",
    @SerialName("sf_symbol") val sfSymbol: String = "",
    @SerialName("android_icon") val androidIcon: String = ""
) {
    fun resolve(baseUrl: String, languageTag: String): ResolvedTab? {
        val safeId = id.trim()
        if (!isSafeId(safeId)) return null
        val label = displayTitle(languageTag)
        if (label.isEmpty()) return null
        val location = startLocation(baseUrl) ?: return null
        val catalogIcon = icon.trim().lowercase().ifEmpty { "home" }
        val drawable = androidIcon.trim().takeIf { isAndroidIconName(it) }.orEmpty()
        return ResolvedTab(
            id = safeId,
            title = label,
            location = location,
            icon = catalogIcon,
            androidIcon = drawable
        )
    }

    private fun displayTitle(languageTag: String): String {
        for (candidate in languageCandidates(languageTag)) {
            titles[candidate]?.let { cleanTitle(it) }?.takeIf { it.isNotEmpty() }?.let { return it }
        }
        cleanTitle(title).takeIf { it.isNotEmpty() }?.let { return it }
        for (fallback in listOf("en", "es")) {
            titles[fallback]?.let { cleanTitle(it) }?.takeIf { it.isNotEmpty() }?.let { return it }
        }
        return titles.values.firstNotNullOfOrNull { cleanTitle(it).takeIf { label -> label.isNotEmpty() } }.orEmpty()
    }

    private fun startLocation(baseUrl: String): String? {
        val absolute = url.trim()
        if (absolute.isNotEmpty()) {
            httpUrl(absolute)?.let { return it }
        }
        return joinHttp(baseUrl, path)
    }
}

@Serializable
data class BridgeFlags(
    @SerialName("notification_token") val notificationToken: Boolean = false,
    val share: Boolean = false,
    val haptic: Boolean = false,
    val camera: Boolean = false,
    val biometric: Boolean = false,
    val clipboard: Boolean = false,
    @SerialName("file_download") val fileDownload: Boolean = false
)

@Serializable
data class PushConfig(
    val enabled: Boolean = false,
    val topics: List<String> = emptyList()
)

object NativeTabListSerializer : KSerializer<List<NativeTab>> {
    private val delegate = kotlinx.serialization.builtins.ListSerializer(NativeTabSerializer)
    override val descriptor: SerialDescriptor
        get() = delegate.descriptor

    override fun serialize(encoder: Encoder, value: List<NativeTab>) {
        encoder.encodeSerializableValue(delegate, value)
    }

    override fun deserialize(decoder: Decoder): List<NativeTab> {
        val jsonDecoder = decoder as? JsonDecoder ?: return emptyList()
        val element = runCatching { jsonDecoder.decodeJsonElement() }.getOrNull() ?: return emptyList()
        if (element !is JsonArray) return emptyList()
        return element.map { item ->
            runCatching { jsonDecoder.json.decodeFromJsonElement(NativeTabSerializer, item) }
                .getOrDefault(NativeTab())
        }
    }
}

object NativeTabSerializer : KSerializer<NativeTab> {
    override val descriptor: SerialDescriptor = buildClassSerialDescriptor("NativeTab")

    override fun serialize(encoder: Encoder, value: NativeTab) {
        val jsonEncoder = encoder as? JsonEncoder
        if (jsonEncoder == null) {
            encoder.encodeString(value.id)
            return
        }
        jsonEncoder.encodeJsonElement(buildJsonObject {
            put("id", value.id)
            put("title", value.title)
            put("titles", buildJsonObject {
                value.titles.forEach { (key, label) -> put(key, label) }
            })
            put("path", value.path)
            put("url", value.url)
            put("icon", value.icon)
            if (value.sfSymbol.isNotEmpty()) put("sf_symbol", value.sfSymbol)
            if (value.androidIcon.isNotEmpty()) put("android_icon", value.androidIcon)
        })
    }

    override fun deserialize(decoder: Decoder): NativeTab {
        val jsonDecoder = decoder as? JsonDecoder ?: return NativeTab()
        val element = runCatching { jsonDecoder.decodeJsonElement() }.getOrNull() ?: return NativeTab()
        val obj = element as? JsonObject ?: return NativeTab()
        val titleElement = obj["title"]
        val title = (titleElement as? JsonPrimitive)?.contentOrBlank().orEmpty()
        val locales = linkedMapOf<String, String>()
        if (titleElement is JsonObject) locales.putAll(localeMap(titleElement))
        (obj["titles"] as? JsonObject)?.let { locales.putAll(localeMap(it)) }
        val icon = jsonString(obj, "icon").lowercase().ifEmpty { "home" }
        return NativeTab(
            id = jsonString(obj, "id"),
            title = if (titleElement is JsonPrimitive && titleElement.isString) title.trim() else "",
            titles = locales,
            path = jsonString(obj, "path"),
            url = jsonString(obj, "url"),
            icon = icon,
            sfSymbol = jsonString(obj, "sf_symbol"),
            androidIcon = jsonString(obj, "android_icon")
        )
    }
}

private fun jsonString(obj: JsonObject, key: String): String {
    val primitive = obj[key] as? JsonPrimitive ?: return ""
    if (!primitive.isString) return ""
    return primitive.content.trim()
}

private fun JsonPrimitive.contentOrBlank(): String {
    return if (isString) content else ""
}

private fun localeMap(obj: JsonObject): Map<String, String> {
    val map = linkedMapOf<String, String>()
    for ((key, value) in obj) {
        val primitive = value as? JsonPrimitive ?: continue
        if (!primitive.isString) continue
        val name = key.trim().lowercase().replace('_', '-')
        val label = primitive.content.trim()
        if (name.isNotEmpty() && label.isNotEmpty()) map[name] = label
    }
    return map
}

private fun languageCandidates(languageTag: String): List<String> {
    val tag = languageTag.trim().lowercase().replace('_', '-')
    if (tag.isEmpty()) return emptyList()
    val base = tag.substringBefore('-')
    return listOf(tag, base).filter { it.isNotEmpty() }.distinct()
}

private fun cleanTitle(raw: String): String {
    val collapsed = raw.split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")
    if (collapsed.isEmpty()) return ""
    return collapsed.take(TITLE_LIMIT).trimEnd()
}

private fun isSafeId(value: String): Boolean {
    if (value.length !in 1..64) return false
    if (!isAsciiLetterOrDigit(value[0])) return false
    return value.all { isAsciiLetterOrDigit(it) || it == '.' || it == '_' || it == '-' }
}

private fun isAndroidIconName(value: String): Boolean {
    if (value.length !in 1..80) return false
    if (value[0] !in 'a'..'z') return false
    return value.all { it in 'a'..'z' || it in '0'..'9' || it == '_' }
}

private fun isAsciiLetterOrDigit(ch: Char): Boolean {
    return ch in 'A'..'Z' || ch in 'a'..'z' || ch in '0'..'9'
}

private fun joinHttp(baseUrl: String, path: String): String? {
    val relative = path.trim()
    if (relative.isEmpty() || relative.contains("://")) return null
    if (relative.any { it.isWhitespace() || it == '\\' || it.isISOControl() }) return null
    val base = baseUrl.trim().trimEnd('/')
    if (httpUrl(base) == null) return null
    val normalized = if (relative.startsWith("/")) relative else "/$relative"
    return httpUrl(base + normalized)
}

private fun httpUrl(value: String): String? {
    if (value.isEmpty() || value.any { it.isISOControl() }) return null
    return try {
        val uri = URI(value)
        val scheme = uri.scheme?.lowercase() ?: return null
        if (scheme != "http" && scheme != "https") return null
        if (uri.host.isNullOrBlank()) return null
        value
    } catch (_: Exception) {
        null
    }
}

private const val TITLE_LIMIT = 40
