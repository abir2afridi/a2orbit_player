import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/constants/app_strings.dart';

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
  List<FileSystemEntity> _files = [];
  List<FileSystemEntity> _filteredFiles = [];
  String _currentPath = '';
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndLoadFiles();
  }

  @override
  void didUpdateWidget(covariant FileBrowserScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _filterFiles(widget.searchQuery);
    }
  }

  Future<void> _requestPermissionsAndLoadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // For Android 13+ (API 33+), we need media permissions
      // For Android 12 and below, we need storage permissions

      List<Permission> permissions = [];

      // Check Android version and request appropriate permissions
      if (Platform.isAndroid) {
        // Try media permissions first (Android 13+)
        permissions.add(Permission.photos);
        permissions.add(Permission.videos);
        permissions.add(Permission.audio);

        // Also request storage permissions for older Android versions
        permissions.add(Permission.storage);
      }

      // Request all permissions
      final requestResults = await permissions.request();

      // Check if any permission was granted
      bool hasPermission = false;
      for (var permission in permissions) {
        if (requestResults[permission] == PermissionStatus.granted) {
          hasPermission = true;
          break;
        }
      }

      if (hasPermission) {
        await _loadFiles();
      } else {
        // Show a more detailed permission dialog
        _showPermissionDialog();
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      _showErrorDialog(
        'Failed to request permissions. Please check your app settings.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFiles([String? path]) async {
    try {
      final directory = Directory(path ?? '/storage/emulated/0');

      if (!await directory.exists()) {
        final alternativePaths = [
          '/sdcard',
          '/storage/self/primary',
          Directory.current.path,
        ];

        for (final altPath in alternativePaths) {
          final altDir = Directory(altPath);
          if (await altDir.exists()) {
            _currentPath = altPath;
            break;
          }
        }
      } else {
        _currentPath = directory.path;
      }

      final files = await directory.list().toList();

      files.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;

        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _files = files;
          _filteredFiles = files;
        });
      }
    } catch (e) {
      debugPrint('Error loading files: $e');
      _showErrorDialog('Failed to load files');
    }
  }

  void _filterFiles(String query) {
    if (mounted) {
      setState(() {
        _searchQuery = query;
        if (query.isEmpty) {
          _filteredFiles = _files;
        } else {
          _filteredFiles = _files.where((file) {
            final fileName = AppUtils.getFileName(file.path).toLowerCase();
            return fileName.contains(query.toLowerCase());
          }).toList();
        }
      });
    }
  }

  void _navigateToPlayer(String filePath) {
    Navigator.pushNamed(context, '/player', arguments: filePath);
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
              _requestPermissionsAndLoadFiles();
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
        title: const Text(AppStrings.errorOccurred),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.ok),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(FileSystemEntity file) {
    final isDirectory = file is Directory;
    final fileName = AppUtils.getFileName(file.path);
    final isVideoFile = !isDirectory && AppUtils.isVideoFile(file.path);

    if (!isDirectory && !isVideoFile) {
      return const SizedBox.shrink();
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isDirectory ? Colors.grey[100] : Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isDirectory ? Icons.folder_rounded : Icons.play_circle_fill,
          color: isDirectory ? Colors.grey[400] : Colors.blue,
          size: 32,
        ),
      ),
      title: Text(
        fileName,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          color: Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          isDirectory
              ? 'Folder'
              : AppUtils.formatFileSize(File(file.path).lengthSync()),
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert, color: Colors.black45),
        onPressed: () {
          _showFileMenu(file);
        },
      ),
      onTap: () {
        if (isDirectory) {
          _loadFiles(file.path);
        } else {
          _navigateToPlayer(file.path);
        }
      },
    );
  }

  void _showFileMenu(FileSystemEntity file) {
    final isDirectory = file is Directory;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Play'),
            onTap: () {
              Navigator.pop(context);
              if (!isDirectory) _navigateToPlayer(file.path);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Info'),
            onTap: () {
              Navigator.pop(context);
              _showFileInfo(file.path);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              // Handle delete
            },
          ),
        ],
      ),
    );
  }

  void _showFileInfo(String filePath) {
    final file = File(filePath);
    final fileSize = AppUtils.formatFileSize(file.lengthSync());
    final lastModified = file.lastModifiedSync();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppUtils.getFileName(filePath)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Size: $fileSize'),
            Text('Modified: ${AppUtils.formatDate(lastModified)}'),
            Text('Path: $filePath'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        if (_currentPath != '/storage/emulated/0' && _currentPath.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.keyboard_backspace),
            title: Text(
              _currentPath,
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            ),
            onTap: () {
              final parent = Directory(_currentPath).parent;
              _loadFiles(parent.path);
            },
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No files found matching "$_searchQuery"'
                            : AppStrings.noVideosFound,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_searchQuery.isEmpty)
                        ElevatedButton.icon(
                          onPressed: _requestPermissionsAndLoadFiles,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry Permission'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: _filteredFiles.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    indent: 80,
                    color: Colors.black12,
                  ),
                  itemBuilder: (context, index) {
                    return _buildFileItem(_filteredFiles[index]);
                  },
                ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.folders),
        backgroundColor: Colors.white,
      ),
      body: content,
    );
  }
}
