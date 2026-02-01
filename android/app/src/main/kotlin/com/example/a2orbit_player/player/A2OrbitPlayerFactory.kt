package com.example.a2orbit_player.player

import android.app.Activity
import android.content.Context
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class A2OrbitPlayerFactory(
    private val activity: Activity?,
    private val lifecycleOwner: LifecycleOwner?,
    private val manager: A2OrbitPlayerManager,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val platformView = manager.createPlatformView(context, viewId)
        val params = args as? Map<*, *>
        val source = params?.get("source") as? String
        val subtitles = (params?.get("subtitles") as? List<*>)?.mapNotNull { it as? String } ?: emptyList()
        if (!source.isNullOrBlank()) {
            platformView.controller.setDataSource(source, subtitles)
        }
        val startPosition = (params?.get("startPosition") as? Number)?.toLong()
        if (startPosition != null) {
            platformView.controller.seekTo(startPosition)
        }
        val autoPlay = params?.get("autoPlay") as? Boolean ?: false
        if (autoPlay) {
            platformView.controller.play()
        }
        return platformView
    }
}
