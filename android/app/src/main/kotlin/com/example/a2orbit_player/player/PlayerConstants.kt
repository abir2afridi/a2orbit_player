package com.example.a2orbit_player.player

object PlayerConstants {
    const val METHOD_CHANNEL = "com.a2orbit.player/channel"
    const val TEXTURE_ENTRY = "com.a2orbit.player/texture"

    object Methods {
        const val INITIALIZE = "initializePlayer"
        const val DISPOSE = "disposePlayer"
        const val SET_SOURCE = "setDataSource"
        const val PLAY = "play"
        const val PAUSE = "pause"
        const val SEEK = "seekTo"
        const val SET_SPEED = "setPlaybackSpeed"
        const val SET_DECODER = "setDecoder"
        const val GET_AUDIO_TRACKS = "getAvailableAudioTracks"
        const val SWITCH_AUDIO_TRACK = "switchAudioTrack"
        const val GET_SUBTITLE_TRACKS = "getSubtitleTracks"
        const val SELECT_SUBTITLE_TRACK = "selectSubtitleTrack"
        const val SET_SUBTITLE_DELAY = "setSubtitleDelay"
        const val SET_AUDIO_DELAY = "setAudioDelay"
        const val SET_ASPECT_RATIO = "setAspectRatio"
        const val ENTER_PIP = "enterPiP"
        const val TOGGLE_PIP = "togglePiP"
        const val LOCK_ROTATION = "lockRotation"
        const val GET_VIDEO_INFO = "getVideoInformation"
        const val ENABLE_GESTURES = "enableGestures"
        const val UPDATE_BRIGHTNESS = "updateBrightness"
        const val UPDATE_VOLUME = "updateVolume"
        const val UPDATE_SEEK = "updateSeek"
    }

    object Events {
        const val EVENT_CHANNEL = "com.a2orbit.player/events"
        const val BUFFERING_UPDATE = "bufferingUpdate"
        const val PLAYBACK_STATE = "playbackState"
        const val ERROR = "error"
        const val POSITION = "position"
        const val TRACK_CHANGED = "trackChanged"
        const val GESTURE = "gesture"
        const val SUBTITLE_DATA = "subtitleData"
    }

    object Decoder {
        const val HARDWARE = "hardware"
        const val SOFTWARE = "software"
    }
}
