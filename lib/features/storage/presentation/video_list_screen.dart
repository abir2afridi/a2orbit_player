import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/app_utils.dart';
import '../../player/presentation/robust_video_player_widget.dart';

class VideoListScreen extends ConsumerStatefulWidget {
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
  ConsumerState<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends ConsumerState<VideoListScreen> {
  bool _isGridView = false;
  String _searchQuery = '';
  List<File> _filteredVideos = [];
  late List<File> _allVideos;
  bool _hasModified = false;

  @override
  void initState() {
    super.initState();
    _allVideos = List<File>.from(widget.videos);
    _filteredVideos = _computeVisibleVideos('');
  }

  void _filterVideos(String query) {
    _rebuildFilteredVideos(query: query);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_hasModified);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_hasModified),
          ),
          title: Text(
            widget.folderName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search ${_allVideos.length} videos...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                onChanged: _filterVideos,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    '${_filteredVideos.length} video${_filteredVideos.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            Expanded(
              child: _filteredVideos.isEmpty
                  ? _buildEmptyState()
                  : _isGridView
                  ? _buildVideoGrid()
                  : _buildVideoList(),
            ),
          ],
        ),
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
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.play_circle_fill,
            color: Theme.of(context).colorScheme.primary,
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
          onSelected: (value) => _handleVideoAction(value, video),
          itemBuilder: (context) => [
            _buildPopupMenuItem('play', Icons.play_arrow, 'Play'),
            _buildPopupMenuItem('info', Icons.info_outline, 'Info'),
            const PopupMenuDivider(),
            _buildPopupMenuItem('hide', Icons.visibility_off_outlined, 'Hide'),
            _buildPopupMenuItem(
              'move_private',
              Icons.folder_special_outlined,
              'Move to Private',
            ),
            _buildPopupMenuItem(
              'rename',
              Icons.drive_file_rename_outline,
              'Rename',
            ),
            _buildPopupMenuItem('delete', Icons.delete_outline, 'Delete'),
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
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Icon(
                  Icons.play_circle_fill,
                  color: Theme.of(context).colorScheme.primary,
                  size: 48,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fileSize,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (value) =>
                              _handleVideoAction(value, video),
                          itemBuilder: (context) => [
                            _buildPopupMenuItem(
                              'play',
                              Icons.play_arrow,
                              'Play',
                            ),
                            _buildPopupMenuItem(
                              'info',
                              Icons.info_outline,
                              'Info',
                            ),
                            const PopupMenuDivider(),
                            _buildPopupMenuItem(
                              'hide',
                              Icons.visibility_off_outlined,
                              'Hide',
                            ),
                            _buildPopupMenuItem(
                              'move_private',
                              Icons.folder_special_outlined,
                              'Move to Private',
                            ),
                            _buildPopupMenuItem(
                              'rename',
                              Icons.drive_file_rename_outline,
                              'Rename',
                            ),
                            _buildPopupMenuItem(
                              'delete',
                              Icons.delete_outline,
                              'Delete',
                            ),
                          ],
                        ),
                      ],
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
        builder: (context) => RobustVideoPlayerWidget(videoPath: video.path),
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

  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  void _rebuildFilteredVideos({String? query}) {
    if (!mounted) return;
    final newQuery = query ?? _searchQuery;
    final visible = _computeVisibleVideos(newQuery);
    setState(() {
      _searchQuery = newQuery;
      _filteredVideos = visible;
    });
  }

  List<File> _computeVisibleVideos(String query) {
    final hiddenPaths = ref
        .read(privacyServiceProvider)
        .getHiddenVideos()
        .toSet();
    final lowerQuery = query.toLowerCase();
    return _allVideos.where((video) {
      if (hiddenPaths.contains(video.path)) {
        return false;
      }
      if (lowerQuery.isEmpty) {
        return true;
      }
      final fileName = AppUtils.getFileName(video.path).toLowerCase();
      return fileName.contains(lowerQuery);
    }).toList();
  }

  Future<void> _handleVideoAction(String action, File video) async {
    switch (action) {
      case 'play':
        _playVideo(video);
        break;
      case 'info':
        _showVideoInfo(video);
        break;
      case 'hide':
        await _hideVideo(video);
        break;
      case 'move_private':
        await _moveToPrivate(video);
        break;
      case 'rename':
        await _renameVideo(video);
        break;
      case 'delete':
        await _deleteVideo(video);
        break;
    }
  }

  Future<void> _hideVideo(File video) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(privacyServiceProvider).hideVideo(video.path);
      if (!mounted) return;
      _hasModified = true;
      _rebuildFilteredVideos();
      messenger.showSnackBar(
        SnackBar(content: Text('${AppUtils.getFileName(video.path)} hidden')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to hide video: $e')),
      );
    }
  }

  Future<void> _moveToPrivate(File video) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(privacyServiceProvider).moveToPrivateFolder(video);
      if (!mounted) return;
      _allVideos.removeWhere((v) => v.path == video.path);
      _hasModified = true;
      _rebuildFilteredVideos();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${AppUtils.getFileName(video.path)} moved to private folder',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to move to private folder: $e')),
      );
    }
  }

  Future<void> _renameVideo(File video) async {
    final initialName = p.basenameWithoutExtension(video.path);
    final controller = TextEditingController(text: initialName);
    String? errorText;

    final confirmed = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Rename Video'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'File name',
                      suffixText: p.extension(video.path),
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final newName = controller.text.trim();
                    if (newName.isEmpty) {
                      setStateDialog(() {
                        errorText = 'Name cannot be empty';
                      });
                      return;
                    }
                    Navigator.of(context).pop(newName);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == null || confirmed == initialName) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final directory = video.parent;
    final extension = p.extension(video.path);
    final newPath = p.join(directory.path, '$confirmed$extension');

    if (await File(newPath).exists()) {
      messenger.showSnackBar(
        SnackBar(content: Text('A file named $confirmed already exists')),
      );
      return;
    }

    try {
      final renamedFile = await video.rename(newPath);
      final index = _allVideos.indexWhere((v) => v.path == video.path);
      if (index != -1) {
        _allVideos[index] = renamedFile;
      }
      if (!mounted) return;
      _hasModified = true;
      _rebuildFilteredVideos();
      messenger.showSnackBar(
        SnackBar(content: Text('Renamed to ${p.basename(renamedFile.path)}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to rename: $e')));
    }
  }

  Future<void> _deleteVideo(File video) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: Text(
          'Delete ${AppUtils.getFileName(video.path)}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await video.delete();
      await ref.read(privacyServiceProvider).unhideVideo(video.path);
      _allVideos.removeWhere((v) => v.path == video.path);
      if (!mounted) return;
      _hasModified = true;
      _rebuildFilteredVideos();
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted ${AppUtils.getFileName(video.path)}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete video: $e')),
      );
    }
  }
}
