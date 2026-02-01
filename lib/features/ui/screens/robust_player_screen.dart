import 'package:flutter/material.dart';
import '../../player/presentation/robust_video_player_widget.dart';

class RobustPlayerScreen extends StatelessWidget {
  final String videoPath;

  const RobustPlayerScreen({super.key, required this.videoPath});

  @override
  Widget build(BuildContext context) {
    return RobustVideoPlayerWidget(videoPath: videoPath);
  }
}
