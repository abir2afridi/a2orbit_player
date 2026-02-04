package com.example.a2orbit_player.player

data class AudioDecoderPreferences(
    val autoDetect: Boolean = true,
    val enableAc3: Boolean = true,
    val enableEac3: Boolean = true,
    val enableDts: Boolean = true,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "autoDetect" to autoDetect,
        "enableAc3" to enableAc3,
        "enableEac3" to enableEac3,
        "enableDts" to enableDts,
    )

    companion object {
        fun fromMap(map: Map<String, Any?>?): AudioDecoderPreferences {
            if (map == null) return AudioDecoderPreferences()
            return AudioDecoderPreferences(
                autoDetect = map["autoDetect"] as? Boolean ?: true,
                enableAc3 = map["enableAc3"] as? Boolean ?: true,
                enableEac3 = map["enableEac3"] as? Boolean ?: true,
                enableDts = map["enableDts"] as? Boolean ?: true,
            )
        }
    }
}
