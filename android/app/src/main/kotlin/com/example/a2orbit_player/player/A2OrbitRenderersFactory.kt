package com.example.a2orbit_player.player

import android.content.Context
import android.os.Handler
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.Renderer
import androidx.media3.exoplayer.audio.DefaultAudioSink
import androidx.media3.exoplayer.text.TextRenderer
import androidx.media3.exoplayer.video.MediaCodecVideoRenderer
import androidx.media3.exoplayer.video.VideoRendererEventListener
import androidx.media3.exoplayer.video.spherical.SphericalGLSurfaceView
import androidx.media3.common.util.Clock
import androidx.media3.common.util.Assertions
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.video.spherical.CameraMotionListener
import androidx.media3.exoplayer.audio.AudioRendererEventListener
import androidx.media3.exoplayer.drm.DrmSessionEventListener
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector

@OptIn(UnstableApi::class)
class A2OrbitRenderersFactory(
    context: Context,
) : DefaultRenderersFactory(context.applicationContext) {

    private var decoderPreference: String = PlayerConstants.Decoder.HARDWARE

    init {
        setEnableDecoderFallback(true)
        setExtensionRendererMode(EXTENSION_RENDERER_MODE_OFF)
    }

    fun updateDecoderPreference(decoder: String) {
        decoderPreference = decoder
        if (decoderPreference == PlayerConstants.Decoder.SOFTWARE) {
            setExtensionRendererMode(EXTENSION_RENDERER_MODE_PREFER)
        } else {
            setExtensionRendererMode(EXTENSION_RENDERER_MODE_OFF)
        }
    }

    fun getDecoderPreference(): String = decoderPreference

    override fun buildVideoRenderers(
        context: Context,
        extensionRendererMode: Int,
        mediaCodecSelector: MediaCodecSelector,
        enableDecoderFallback: Boolean,
        eventHandler: Handler,
        eventListener: VideoRendererEventListener,
        allowedVideoJoiningTimeMs: Long,
        out: ArrayList<Renderer>,
    ) {
        super.buildVideoRenderers(
            context,
            extensionRendererMode,
            mediaCodecSelector,
            enableDecoderFallback,
            eventHandler,
            eventListener,
            allowedVideoJoiningTimeMs,
            out,
        )

        if (decoderPreference == PlayerConstants.Decoder.SOFTWARE) {
            // Remove hardware MediaCodec video renderers to force software rendering.
            out.removeAll { renderer -> renderer is MediaCodecVideoRenderer }
            // Note: FFmpeg renderer not available without extension
        }
    }

    override fun buildAudioRenderers(
        context: Context,
        extensionRendererMode: Int,
        mediaCodecSelector: MediaCodecSelector,
        enableDecoderFallback: Boolean,
        audioSink: AudioSink,
        eventHandler: Handler,
        eventListener: AudioRendererEventListener,
        out: ArrayList<Renderer>,
    ) {
        super.buildAudioRenderers(
            context,
            extensionRendererMode,
            mediaCodecSelector,
            enableDecoderFallback,
            audioSink,
            eventHandler,
            eventListener,
            out,
        )

        if (decoderPreference == PlayerConstants.Decoder.SOFTWARE) {
            // Note: FFmpeg audio renderer not available without extension
        }
    }
}
