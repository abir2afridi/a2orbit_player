import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/media_store_service.dart';
import '../../../core/utils/permission_helper.dart';
import '../models/file_view_settings.dart';
import '../providers/file_settings_provider.dart';
import 'video_list_screen.dart';
import '../../player/presentation/robust_video_player_widget.dart';

class FileBrowserScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final String searchQuery;
  const FileBrowserScreen({
    super.key,
    this.isEmbedded = false,
    this.searchQuery = '',
  });

  @override
  ConsumerState<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends ConsumerState<FileBrowserScreen> {
  Map<String, List<File>> _foldersWithVideos = {};
  List<File> _allFiles = [];
  List<String> _filteredFolderPaths = [];
  List<File> _filteredFiles = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _searchQuery = '';
  bool _isPermissionDialogVisible = false;

  @override
  void initState() {
    super.initState();

    // Show UI immediately, scan in background after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializePermissionFlow();
        // Trigger background scan after UI is shown
        _loadFoldersInBackground();
      }
    });
  }

  @override
  void didUpdateWidget(covariant FileBrowserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _filterFolders(widget.searchQuery);
    }
  }

  Future<void> _initializePermissionFlow() async {
    // Show cached data immediately if available
    final cached = MediaStoreService.getCachedFolders();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _foldersWithVideos = cached;
        _filteredFolderPaths = cached.keys.toList();
        _allFiles = cached.values.expand((e) => e).toList();
        _isLoading = false;
      });
    }

    final hasPermission = await PermissionHelper.checkStoragePermissions();

    if (!mounted) return;

    if (!hasPermission) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _foldersWithVideos = {};
        _filteredFolderPaths = [];
      });
      await _showPermissionGateDialog();
      return;
    }
  }

  Future<void> _loadFoldersInBackground() async {
    // Load folders in background without blocking UI
    try {
      final foldersWithVideos = await MediaStoreService.scanFoldersWithVideos();

      if (mounted) {
        setState(() {
          _foldersWithVideos = foldersWithVideos;
          _allFiles = foldersWithVideos.values.expand((e) => e).toList();
          _isLoading = false;
          _isRefreshing = false;
          _applySettings();
        });
      }
    } catch (e) {
      debugPrint('Error scanning folders: $e');
      if (mounted) {
        _showErrorDialog('Failed to scan folders. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = _foldersWithVideos.isEmpty;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadFolders({bool forceRefresh = false}) async {
    // For manual refresh, clear cache and reload
    if (forceRefresh) {
      MediaStoreService.clearCache();
      await _loadFoldersInBackground();
    }
  }

  void _applySettings() {
    final settings = ref.read(fileSettingsProvider);
    final query = _searchQuery.toLowerCase();

    // 1. Filter folders
    List<String> folderPaths = _foldersWithVideos.keys.where((path) {
      if (query.isEmpty) return true;
      return MediaStoreService.getFolderName(
        path,
      ).toLowerCase().contains(query);
    }).toList();

    // 2. Filter files
    List<File> files = _allFiles.where((file) {
      if (query.isEmpty) return true;
      return file.path.split('/').last.toLowerCase().contains(query);
    }).toList();

    // 3. Sort folders
    folderPaths.sort((a, b) {
      int cmp;
      switch (settings.sortOption) {
        case FileSortOption.date:
          final aDate = File(a).statSync().modified;
          final bDate = File(b).statSync().modified;
          cmp = aDate.compareTo(bDate);
          break;
        case FileSortOption.size:
          final aSize =
              _foldersWithVideos[a]?.fold<int>(
                0,
                (p, f) => p + f.lengthSync(),
              ) ??
              0;
          final bSize =
              _foldersWithVideos[b]?.fold<int>(
                0,
                (p, f) => p + f.lengthSync(),
              ) ??
              0;
          cmp = aSize.compareTo(bSize);
          break;
        case FileSortOption.path:
          cmp = a.compareTo(b);
          break;
        default: // title
          cmp = MediaStoreService.getFolderName(a).toLowerCase().compareTo(
            MediaStoreService.getFolderName(b).toLowerCase(),
          );
      }
      return settings.isAscending ? cmp : -cmp;
    });

    // 4. Sort files
    files.sort((a, b) {
      int cmp;
      switch (settings.sortOption) {
        case FileSortOption.date:
          cmp = a.lastModifiedSync().compareTo(b.lastModifiedSync());
          break;
        case FileSortOption.size:
          cmp = a.lengthSync().compareTo(b.lengthSync());
          break;
        case FileSortOption.path:
          cmp = a.path.compareTo(b.path);
          break;
        case FileSortOption.type:
          cmp = a.path.split('.').last.compareTo(b.path.split('.').last);
          break;
        default: // title
          cmp = a.path
              .split('/')
              .last
              .toLowerCase()
              .compareTo(b.path.split('/').last.toLowerCase());
      }
      return settings.isAscending ? cmp : -cmp;
    });

    setState(() {
      _filteredFolderPaths = folderPaths;
      _filteredFiles = files;
    });
  }

  void _filterFolders(String query) {
    if (mounted) {
      setState(() {
        _searchQuery = query;
        _applySettings();
      });
    }
  }

  void _navigateToVideoList(String folderPath) {
    final videos = _foldersWithVideos[folderPath] ?? [];
    final folderName = MediaStoreService.getFolderName(folderPath);

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

  Future<void> _showPermissionGateDialog() async {
    if (!mounted || _isPermissionDialogVisible) {
      return;
    }

    _isPermissionDialogVisible = true;
    final permissionDetails =
        await PermissionHelper.getPermissionStatusDetails();

    if (!mounted) {
      _isPermissionDialogVisible = false;
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Storage Permission Required'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A2Orbit Player needs access to your device storage to browse and play offline videos. Grant the following permissions to continue:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                ...permissionDetails.map(
                  (detail) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          detail.granted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: detail.granted
                              ? Theme.of(dialogContext).colorScheme.primary
                              : Theme.of(dialogContext).colorScheme.outline,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                detail.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    dialogContext,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                detail.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    dialogContext,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _handleAllowAllPressed();
                },
                child: const Text('Allow All'),
              ),
            ),
          ],
        );
      },
    ).whenComplete(() {
      _isPermissionDialogVisible = false;
    });
  }

  Future<void> _handleAllowAllPressed() async {
    final granted = await PermissionHelper.requestStoragePermissions();

    if (!mounted) return;

    if (granted) {
      // Load folders after permission is granted
      await _loadFoldersInBackground();
    } else {
      await _showPermissionGateDialog();
    }
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
    final settings = ref.watch(fileSettingsProvider);
    final isGridView = settings.layout == FileLayout.grid;
    final isFilesView = settings.viewMode == FileViewMode.files;

    // Trigger re-sort/filter when settings change
    ref.listen(fileSettingsProvider, (previous, next) {
      if (previous != next) {
        _applySettings();
      }
    });

    final currentItemCount = isFilesView
        ? _filteredFiles.length
        : _filteredFolderPaths.length;

    final content = Column(
      children: [
        if (_isRefreshing && !_isLoading)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : currentItemCount == 0
              ? _buildEmptyState()
              : isGridView
              ? (isFilesView ? _buildFileGrid() : _buildFolderGrid())
              : (isFilesView ? _buildFileList() : _buildFolderList()),
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              ref
                  .read(fileSettingsProvider.notifier)
                  .setLayout(isGridView ? FileLayout.list : FileLayout.grid);
            },
            icon: Icon(isGridView ? Icons.list : Icons.grid_view),
            tooltip: isGridView ? 'List View' : 'Grid View',
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
              onPressed: () => _loadFolders(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Rescan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
    final folderName = MediaStoreService.getFolderName(folderPath);
    final videoCount = MediaStoreService.getVideoCount(
      _foldersWithVideos,
      folderPath,
    );
    final firstVideo = MediaStoreService.getFirstVideo(
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
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  Icons.folder_rounded,
                  color: Theme.of(context).colorScheme.primary,
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
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _getShortPath(folderPath),
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontSize: 12,
              ),
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
    final folderName = MediaStoreService.getFolderName(folderPath);
    final videoCount = MediaStoreService.getVideoCount(
      _foldersWithVideos,
      folderPath,
    );
    final firstVideo = MediaStoreService.getFirstVideo(
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
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.folder_rounded,
                        color: Theme.of(context).colorScheme.primary,
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildFileList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filteredFiles.length,
      itemBuilder: (context, index) {
        final video = _filteredFiles[index];
        return _buildFileListItem(video);
      },
    );
  }

  Widget _buildFileGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredFiles.length,
      itemBuilder: (context, index) {
        final video = _filteredFiles[index];
        return _buildFileGridItem(video);
      },
    );
  }

  Widget _buildFileListItem(File video) {
    final fileName = video.path.split('/').last;
    final fileSize = _formatFileSize(video.lengthSync());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
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
        subtitle: Text(
          fileSize,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        onTap: () => _playVideo(video),
      ),
    );
  }

  Widget _buildFileGridItem(File video) {
    final fileName = video.path.split('/').last;
    final fileSize = _formatFileSize(video.lengthSync());

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

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}";
  }

  void _playVideo(File video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RobustVideoPlayerWidget(videoPath: video.path),
      ),
    );
  }

  String _getShortPath(String fullPath) {
    final parts = fullPath.split('/');
    if (parts.length <= 3) return fullPath;
    return '.../${parts.sublist(parts.length - 2).join('/')}';
  }
}
