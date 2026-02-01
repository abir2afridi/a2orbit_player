import 'package:flutter/material.dart';
import 'dart:io';
import '../../../core/utils/app_utils.dart';
import '../../player/presentation/video_player_widget.dart';

class VideoListScreen extends StatefulWidget {
  final String folderPath;
  final List<File> videos;
  final String folderName;

  const VideoListScreen({
    super.key,
    required this.folderPath,
    required this.videos,
    required this.folderName,
  });

  @override
  State<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen> {
  bool _isGridView = false;
  String _searchQuery = '';
  List<File> _filteredVideos = [];

  @override
  void initState() {
    super.initState();
    _filteredVideos = widget.videos;
  }

  void _filterVideos(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredVideos = widget.videos;
      } else {
        _filteredVideos = widget.videos.where((video) {
          final fileName = AppUtils.getFileName(video.path).toLowerCase();
          return fileName.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.folderName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            tooltip: _isGridView ? 'List View' : 'Grid View',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search ${widget.videos.length} videos...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
              onChanged: _filterVideos,
            ),
          ),

          // Video count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  '${_filteredVideos.length} video${_filteredVideos.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  const Spacer(),
                  TextButton(
                    onPressed: () => _filterVideos(''),
                    child: const Text('Clear'),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Video list/grid
          Expanded(
            child: _filteredVideos.isEmpty
                ? _buildEmptyState()
                : _isGridView
                ? _buildVideoGrid()
                : _buildVideoList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No videos found matching "$_searchQuery"'
                : 'No videos found',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredVideos.length,
      itemBuilder: (context, index) {
        final video = _filteredVideos[index];
        return _buildVideoListItem(video, index);
      },
    );
  }

  Widget _buildVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredVideos.length,
      itemBuilder: (context, index) {
        final video = _filteredVideos[index];
        return _buildVideoGridItem(video, index);
      },
    );
  }

  Widget _buildVideoListItem(File video, int index) {
    final fileName = AppUtils.getFileName(video.path);
    final fileSize = AppUtils.formatFileSize(video.lengthSync());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.play_circle_fill,
            color: Colors.blue[700],
            size: 28,
          ),
        ),
        title: Text(
          fileName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              fileSize,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
          onSelected: (value) {
            switch (value) {
              case 'play':
                _playVideo(video);
                break;
              case 'info':
                _showVideoInfo(video);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'play',
              child: Row(
                children: [
                  Icon(Icons.play_arrow),
                  SizedBox(width: 8),
                  Text('Play'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text('Info'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _playVideo(video),
      ),
    );
  }

  Widget _buildVideoGridItem(File video, int index) {
    final fileName = AppUtils.getFileName(video.path);
    final fileSize = AppUtils.formatFileSize(video.lengthSync());

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _playVideo(video),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video thumbnail placeholder
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.blue[700],
                  size: 48,
                ),
              ),
            ),
            // Video info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      fileSize,
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playVideo(File video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VideoPlayerWidget(videoPath: video.path, autoPlay: true),
      ),
    );
  }

  void _showVideoInfo(File video) {
    final fileName = AppUtils.getFileName(video.path);
    final fileSize = AppUtils.formatFileSize(video.lengthSync());
    final lastModified = AppUtils.formatDate(video.lastModifiedSync());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', fileName),
            _buildInfoRow('Size', fileSize),
            _buildInfoRow('Modified', lastModified),
            _buildInfoRow('Path', video.path),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _playVideo(video);
            },
            child: const Text('Play'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
