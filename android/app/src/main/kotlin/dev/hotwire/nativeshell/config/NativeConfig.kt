package dev.hotwire.nativeshell.config

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Rails `GET /native/config` document.
 *
 * Unknown keys are ignored so the server can add fields before the shell
 * ships a matching release. Missing bridge flags default to off.
 */
@Serializable
data class NativeConfig(
    val name: String,
    @SerialName("base_url") val baseUrl: String,
    @SerialName("start_path") val startPath: String = "/",
    val tabs: List<NativeTab> = emptyList(),
    val bridges: BridgeFlags = BridgeFlags(),
    val push: PushConfig = PushConfig()
) {
    val startLocation: String
        get() = locationFor(startPath)

    fun locationFor(path: String): String {
        val base = baseUrl.trimEnd('/')
        val normalized = if (path.startsWith("/")) path else "/$path"
        return base + normalized
    }
}

@Serializable
data class NativeTab(
    val id: String,
    val title: String,
    val path: String,
    val icon: String = "home"
)

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
