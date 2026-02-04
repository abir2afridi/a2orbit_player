package com.example.a2orbit_player.player

import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.os.Build
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Detects and caches audio decoder capabilities based on available MediaCodec decoders.
 */
object AudioDecoderCapabilityDetector {

    private val initialized = AtomicBoolean(false)
    private val cachedCapabilities = mutableMapOf<String, Boolean>()

    private val capabilityAliases: Map<String, List<String>> = mapOf(
        "audio/ac3" to listOf("audio/ac3", "audio/vnd.dolby.dd-raw"),
        "audio/eac3" to listOf("audio/eac3", "audio/vnd.dolby.dds", "audio/vnd.dolby.heaac.2"),
        "audio/dts" to listOf("audio/dts", "audio/vnd.dts", "audio/vnd.dts.hd"),
        "audio/aac" to listOf("audio/aac", "audio/mp4a-latm"),
        "audio/mp3" to listOf("audio/mpeg", "audio/mp3"),
    )

    private val aliasToCanonical: Map<String, String> = buildMap {
        capabilityAliases.forEach { (canonical, aliases) ->
            aliases.forEach { alias -> put(alias.lowercase(), canonical) }
            put(canonical.lowercase(), canonical)
        }
    }

    fun getCapabilities(): Map<String, Boolean> {
        ensureInitialized()
        return capabilityAliases.keys.associateWith { mime ->
            cachedCapabilities[mime] ?: false
        }
    }

    fun canonicalize(mimeType: String?): String? {
        val normalized = mimeType?.lowercase() ?: return null
        return aliasToCanonical[normalized] ?: normalized.takeIf { capabilityAliases.containsKey(it) }
    }

    fun supportsMime(mimeType: String?): Boolean {
        ensureInitialized()
        val canonical = canonicalize(mimeType) ?: return true
        return cachedCapabilities[canonical] ?: false
    }

    @Synchronized
    private fun ensureInitialized() {
        if (initialized.compareAndSet(false, true) || cachedCapabilities.isEmpty()) {
            detectCapabilities()
        }
    }

    private fun detectCapabilities() {
        val supported = mutableSetOf<String>()
        try {
            val codecInfos: List<MediaCodecInfo> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                MediaCodecList(MediaCodecList.ALL_CODECS).codecInfos.toList()
            } else {
                emptyList()
            }

            codecInfos.filterNot { it.isEncoder }.forEach { codecInfo ->
                codecInfo.supportedTypes.forEach { type ->
                    supported.add(type.lowercase())
                }
            }
        } catch (_: Throwable) {
            // Ignore detection errors; defaults handled below
        }

        capabilityAliases.forEach { (canonicalMime, aliases) ->
            val hasSupport = aliases.any { alias -> supported.contains(alias.lowercase()) }
            // AAC and MP3 should always be treated as supported if detection fails
            cachedCapabilities[canonicalMime] = when (canonicalMime) {
                "audio/aac", "audio/mp3" -> true
                else -> hasSupport
            }
        }
    }
}
