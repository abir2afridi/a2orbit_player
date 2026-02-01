package com.example.a2orbit_player.player

import android.app.Activity
import android.content.Context
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Factory for creating RobustPlayerPlatformView instances
 */
class RobustPlayerFactory(
    private val activity: Activity?,
    private val lifecycleOwner: LifecycleOwner?,
    private val manager: RobustPlayerManager,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return RobustPlayerPlatformView(
            activity = activity,
            context = context,
            viewId = viewId,
            lifecycleOwner = lifecycleOwner,
            manager = manager,
        )
    }
}
