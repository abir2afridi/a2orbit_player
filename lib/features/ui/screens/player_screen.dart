import 'package:flutter/material.dart';
import '../../player/presentation/video_player_widget.dart';

class PlayerScreen extends StatelessWidget {
  final String videoPath;

  const PlayerScreen({super.key, required this.videoPath});

  @override
  Widget build(BuildContext context) {
    return VideoPlayerWidget(
      videoPath: videoPath,
      onVideoEnd: () {
        Navigator.pop(context);
      },
    );
  }
}
