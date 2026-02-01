import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/folder_scan_service.dart';
import 'video_list_screen.dart';

class FileBrowserScreen extends StatefulWidget {
  final bool isEmbedded;
  final String searchQuery;
  const FileBrowserScreen({
    super.key,
    this.isEmbedded = false,
    this.searchQuery = '',
  });

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  Map<String, List<File>> _foldersWithVideos = {};
  List<String> _filteredFolderPaths = [];
  bool _isLoading = true;
  bool _isGridView = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndScanFolders();
  }

  @override
  void didUpdateWidget(covariant FileBrowserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _filterFolders(widget.searchQuery);
    }
  }

  Future<void> _requestPermissionsAndScanFolders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Request permissions first
      final hasPermission = await FolderScanService.requestPermissions();

      if (!hasPermission) {
        _showPermissionDialog();
        return;
      }

      // Scan folders with videos
      final foldersWithVideos = await FolderScanService.scanFoldersWithVideos();

      if (mounted) {
        setState(() {
          _foldersWithVideos = foldersWithVideos;
          _filteredFolderPaths = foldersWithVideos.keys.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error scanning folders: $e');
      _showErrorDialog('Failed to scan folders. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterFolders(String query) {
    if (mounted) {
      setState(() {
        _searchQuery = query;
        if (query.isEmpty) {
          _filteredFolderPaths = _foldersWithVideos.keys.toList();
        } else {
          _filteredFolderPaths = _foldersWithVideos.keys.where((folderPath) {
            final folderName = FolderScanService.getFolderName(
              folderPath,
            ).toLowerCase();
            return folderName.contains(query.toLowerCase());
          }).toList();
        }
      });
    }
  }

  void _navigateToVideoList(String folderPath) {
    final videos = _foldersWithVideos[folderPath] ?? [];
    final folderName = FolderScanService.getFolderName(folderPath);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoListScreen(
          folderPath: folderPath,
          videos: videos,
          folderName: folderName,
        ),
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A2Orbit Player needs storage permission to browse and play your video files.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Without this permission, the app cannot:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            SizedBox(height: 8),
            Text(
              '• Browse your device storage',
              style: TextStyle(fontSize: 12),
            ),
            Text('• Access video files', style: TextStyle(fontSize: 12)),
            Text('• Play media content', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Try requesting permissions again
              _requestPermissionsAndScanFolders();
            },
            child: const Text('Grant Permission'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Open app settings
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredFolderPaths.isEmpty
              ? _buildEmptyState()
              : _isGridView
              ? _buildFolderGrid()
              : _buildFolderList(),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Folders (${_filteredFolderPaths.length})',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
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
      body: content,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No folders found matching "$_searchQuery"'
                : 'No folders with videos found',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Only folders containing video files will be shown',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: _requestPermissionsAndScanFolders,
              icon: const Icon(Icons.refresh),
              label: const Text('Rescan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFolderList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filteredFolderPaths.length,
      itemBuilder: (context, index) {
        final folderPath = _filteredFolderPaths[index];
        return _buildFolderListItem(folderPath);
      },
    );
  }

  Widget _buildFolderGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredFolderPaths.length,
      itemBuilder: (context, index) {
        final folderPath = _filteredFolderPaths[index];
        return _buildFolderGridItem(folderPath);
      },
    );
  }

  Widget _buildFolderListItem(String folderPath) {
    final folderName = FolderScanService.getFolderName(folderPath);
    final videoCount = FolderScanService.getVideoCount(
      _foldersWithVideos,
      folderPath,
    );
    final firstVideo = FolderScanService.getFirstVideo(
      _foldersWithVideos,
      folderPath,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.folder_rounded,
                  color: Colors.blue[700],
                  size: 32,
                ),
              ),
              if (firstVideo != null)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          folderName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$videoCount video${videoCount != 1 ? 's' : ''}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _getShortPath(folderPath),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: () => _navigateToVideoList(folderPath),
      ),
    );
  }

  Widget _buildFolderGridItem(String folderPath) {
    final folderName = FolderScanService.getFolderName(folderPath);
    final videoCount = FolderScanService.getVideoCount(
      _foldersWithVideos,
      folderPath,
    );
    final firstVideo = FolderScanService.getFirstVideo(
      _foldersWithVideos,
      folderPath,
    );

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToVideoList(folderPath),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Folder icon with video indicator
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.folder_rounded,
                        color: Colors.blue[700],
                        size: 48,
                      ),
                    ),
                    if (firstVideo != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$videoCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Folder info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folderName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      '$videoCount video${videoCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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

  String _getShortPath(String fullPath) {
    final parts = fullPath.split('/');
    if (parts.length <= 3) return fullPath;

    // Show last 3 parts: .../parent/folder
    return '.../${parts.sublist(parts.length - 2).join('/')}';
  }
}
