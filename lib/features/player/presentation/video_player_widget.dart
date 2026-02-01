import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoPath;
  final bool autoPlay;
  final bool looping;
  final VoidCallback? onVideoEnd;

  const VideoPlayerWidget({
    super.key,
    required this.videoPath,
    this.autoPlay = true,
    this.looping = false,
    this.onVideoEnd,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;
  bool _isFullscreen = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _hideControlsTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _controller = VideoPlayerController.file(File(widget.videoPath));

      await _controller!.initialize();

      _controller!.addListener(_videoListener);

      if (widget.autoPlay) {
        await _controller!.play();
      }

      if (widget.looping) {
        _controller!.setLooping(true);
      }

      setState(() {
        _isInitialized = true;
        _duration = _controller!.value.duration;
        _isPlaying = _controller!.value.isPlaying;
      });
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      // Show error dialog or snackbar
    }
  }

  void _videoListener() {
    if (_controller == null) return;

    final position = _controller!.value.position;
    final isPlaying = _controller!.value.isPlaying;
    final isEnded = position >= _duration && _duration > Duration.zero;

    setState(() {
      _position = position;
      _isPlaying = isPlaying;
    });

    if (isEnded && widget.onVideoEnd != null) {
      widget.onVideoEnd!();
    }
  }

  void _togglePlayPause() async {
    if (_controller == null) return;

    if (_isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
    _resetHideControlsTimer();
  }

  void _seekTo(Duration position) async {
    if (_controller == null) return;
    await _controller!.seekTo(position);
    _resetHideControlsTimer();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _resetHideControlsTimer();
    }
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _changeVolume(double volume) async {
    if (_controller == null) return;
    await _controller!.setVolume(volume);
    setState(() {
      _volume = volume;
    });
  }

  void _changePlaybackSpeed(double speed) async {
    if (_controller == null) return;
    await _controller!.setPlaybackSpeed(speed);
    setState(() {
      _playbackSpeed = speed;
    });
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    // In real implementation, this would handle orientation and fullscreen mode
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Player
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),

            // Controls Overlay
            if (_showControls) _buildControlsOverlay(),

            // Loading indicator
            if (_controller!.value.isBuffering)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      color: Colors.black26,
      child: Stack(
        children: [
          // Top controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        widget.videoPath.split('/').last,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.cast,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _changeVolume(_volume > 0 ? 0.0 : 1.0);
                      },
                      icon: Icon(
                        _volume > 0 ? Icons.music_note : Icons.volume_off,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.playlist_play,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.tune,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating Action Icons (below top bar)
          Positioned(
            top: 100,
            left: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    double nextSpeed = _playbackSpeed + 0.5;
                    if (nextSpeed > 2.0) nextSpeed = 0.5;
                    _changePlaybackSpeed(nextSpeed);
                  },
                  child: _buildFloatingIcon(
                    Icons.slow_motion_video,
                    "${_playbackSpeed}x",
                  ),
                ),
                _buildFloatingIcon(Icons.subtitles_outlined, ""),
                _buildFloatingIcon(Icons.screen_rotation_outlined, ""),
                _buildFloatingIcon(Icons.headphones_outlined, ""),
                _buildFloatingIcon(Icons.keyboard_arrow_right, ""),
              ],
            ),
          ),

          // Resolution Badges
          Positioned(
            right: 16,
            top: 150,
            child: Column(
              children: [
                _buildResolutionBadge("8K", const Color(0xFFFFD700)),
                const SizedBox(height: 8),
                _buildResolutionBadge("4K", const Color(0xFFFFC107)),
                const SizedBox(height: 8),
                _buildResolutionBadge("FHD", const Color(0xFFFFB300)),
              ],
            ),
          ),

          // Center Controls
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.skip_previous,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(width: 32),
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.skip_next,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ],
            ),
          ),

          // Lock Button (Left)
          Positioned(
            left: 16,
            bottom: 80,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),

          // Bottom Controls (Progress Bar)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            activeTrackColor: Colors.blue,
                            inactiveTrackColor: Colors.white30,
                            thumbColor: Colors.blue,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayColor: Colors.blue.withAlpha(32),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                          ),
                          child: Slider(
                            value: _position.inMilliseconds.toDouble(),
                            max: _duration.inMilliseconds.toDouble(),
                            onChanged: (value) {
                              _seekTo(Duration(milliseconds: value.toInt()));
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _toggleFullscreen,
                        icon: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingIcon(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResolutionBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white30, width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          const Text(
            "ULTRA HD",
            style: TextStyle(
              color: Colors.black,
              fontSize: 5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
