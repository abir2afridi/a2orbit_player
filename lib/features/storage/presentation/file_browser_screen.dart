import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/folder_scan_service.dart';
import '../../../core/utils/permission_helper.dart';
import '../models/file_view_settings.dart';
import '../providers/file_settings_provider.dart';
import 'video_list_screen.dart';

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
  List<String> _filteredFolderPaths = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _searchQuery = '';
  bool _isPermissionDialogVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializePermissionFlow();
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

    await _loadFolders();
  }

  Future<void> _loadFolders({bool forceRefresh = false}) async {
    final cached = FolderScanService.getCachedFolders();
    final hasCachedData = cached.isNotEmpty;

    if (mounted) {
      setState(() {
        if (hasCachedData && !forceRefresh) {
          _foldersWithVideos = cached;
          _filteredFolderPaths = cached.keys.toList();
          _isLoading = false;
        } else {
          _isLoading = true;
        }
        _isRefreshing = true;
      });
    }

    try {
      final hasPermission = await PermissionHelper.checkStoragePermissions();

      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _isRefreshing = false;
            _isLoading = _foldersWithVideos.isEmpty;
          });
        }
        await _showPermissionGateDialog();
        return;
      }

      final foldersWithVideos = await FolderScanService.scanFoldersWithVideos(
        forceRefresh: forceRefresh,
      );

      if (mounted) {
        setState(() {
          _foldersWithVideos = foldersWithVideos;
          _filteredFolderPaths = foldersWithVideos.keys.toList();
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('Error scanning folders: $e');
      _showErrorDialog('Failed to scan folders. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = _foldersWithVideos.isEmpty;
          _isRefreshing = false;
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
      await _loadFolders(forceRefresh: true);
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

    final content = Column(
      children: [
        if (_isRefreshing && !_isLoading)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredFolderPaths.isEmpty
              ? _buildEmptyState()
              : isGridView
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
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
