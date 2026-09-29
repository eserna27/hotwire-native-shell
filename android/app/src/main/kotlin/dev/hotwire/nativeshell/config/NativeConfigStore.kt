package dev.hotwire.nativeshell.config

import android.content.Context
import android.util.Log
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Startup uses the bundled flavor JSON, replaced by a cached remote document
 * after one successful fetch. A fresh `GET /native/config` runs in the
 * background and is applied on the next cold start, matching Hotwire's
 * path-configuration cache.
 */
object NativeConfigStore {
    private const val TAG = "NativeConfig"
    private const val ASSET_PATH = "native/config.json"
    private const val CACHE_NAME = "native-config.json"
    private const val TIMEOUT_MS = 8_000

    private val json = Json {
        ignoreUnknownKeys = true
    }

    fun loadStartup(context: Context): NativeConfig {
        val bundled = loadBundled(context)
        val cached = loadCached(context)
        return cached ?: bundled
    }

    fun refreshInBackground(context: Context, startup: NativeConfig) {
        val appContext = context.applicationContext
        thread(name = "native-config", isDaemon = true) {
            try {
                val remote = fetch(startup.baseUrl)
                appContext.openFileOutput(CACHE_NAME, Context.MODE_PRIVATE).use { output ->
                    output.write(json.encodeToString(NativeConfig.serializer(), remote).toByteArray())
                }
                Log.i(
                    TAG,
                    "Cached remote /native/config for ${remote.name}. It applies on the next cold start."
                )
            } catch (error: IOException) {
                Log.w(TAG, "Remote /native/config unavailable. Using the bundled or cached document.", error)
            } catch (error: SerializationException) {
                Log.w(TAG, "Remote /native/config was not the expected JSON. Leaving the cache unchanged.", error)
            }
        }
    }

    private fun loadBundled(context: Context): NativeConfig {
        val text = context.assets.open(ASSET_PATH).bufferedReader().use { it.readText() }
        return json.decodeFromString(NativeConfig.serializer(), text)
    }

    private fun loadCached(context: Context): NativeConfig? {
        val file = context.filesDir.resolve(CACHE_NAME)
        if (!file.exists()) return null
        return try {
            json.decodeFromString(NativeConfig.serializer(), file.readText())
        } catch (error: SerializationException) {
            Log.w(TAG, "Ignoring unreadable cached /native/config.", error)
            null
        } catch (error: IOException) {
            Log.w(TAG, "Ignoring unreadable cached /native/config.", error)
            null
        }
    }

    private fun fetch(baseUrl: String): NativeConfig {
        val endpoint = baseUrl.trimEnd('/') + "/native/config"
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = TIMEOUT_MS
            readTimeout = TIMEOUT_MS
            instanceFollowRedirects = true
            setRequestProperty("Accept", "application/json")
            setRequestProperty("User-Agent", "hotwire-native-shell")
        }
        try {
            val status = connection.responseCode
            if (status !in 200..299) {
                throw IOException("GET $endpoint returned HTTP $status")
            }
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val config = json.decodeFromString(NativeConfig.serializer(), body)
            if (config.name.isBlank() || config.baseUrl.isBlank()) {
                throw SerializationException("name and base_url are required")
            }
            return config
        } finally {
            connection.disconnect()
        }
    }
}
