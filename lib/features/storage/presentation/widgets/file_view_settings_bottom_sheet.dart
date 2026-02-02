import 'package:flutter/material.dart';
import '../../models/file_view_settings.dart';

class FileViewSettingsBottomSheet extends StatefulWidget {
  final FileViewMode initialViewMode;
  final FileLayout initialLayout;
  final FileSortOption initialSortOption;
  final bool isAscending;

  const FileViewSettingsBottomSheet({
    super.key,
    required this.initialViewMode,
    required this.initialLayout,
    required this.initialSortOption,
    required this.isAscending,
  });

  @override
  State<FileViewSettingsBottomSheet> createState() =>
      _FileViewSettingsBottomSheetState();
}

class _FileViewSettingsBottomSheetState
    extends State<FileViewSettingsBottomSheet> {
  late FileViewMode _viewMode;
  late FileLayout _layout;
  late FileSortOption _sortOption;
  late bool _isAscending;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;
    _layout = widget.initialLayout;
    _sortOption = widget.initialSortOption;
    _isAscending = widget.isAscending;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildViewModeAndLayout(),
          const SizedBox(height: 24),
          const Text(
            'Sort',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSortGrid(),
          const SizedBox(height: 24),
          _buildOrderToggle(),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.withOpacity(0.2)),
          _buildCollapsibleSection('Fields'),
          Divider(color: Colors.grey.withOpacity(0.2)),
          _buildCollapsibleSection('Advanced'),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildViewModeAndLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'View Mode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildIconOption(
                    icon: Icons.folder_copy_outlined,
                    label: 'All folders',
                    isSelected: _viewMode == FileViewMode.allFolders,
                    onTap: () =>
                        setState(() => _viewMode = FileViewMode.allFolders),
                  ),
                  _buildIconOption(
                    icon: Icons.description_outlined,
                    label: 'Files',
                    isSelected: _viewMode == FileViewMode.files,
                    onTap: () => setState(() => _viewMode = FileViewMode.files),
                  ),
                  _buildIconOption(
                    icon: Icons.folder_outlined,
                    label: 'Folders',
                    isSelected: _viewMode == FileViewMode.folders,
                    onTap: () =>
                        setState(() => _viewMode = FileViewMode.folders),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Layout',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildIconOption(
                    icon: Icons.view_headline,
                    label: 'List',
                    isSelected: _layout == FileLayout.list,
                    onTap: () => setState(() => _layout = FileLayout.list),
                  ),
                  _buildIconOption(
                    icon: Icons.grid_view_rounded,
                    label: 'Grid',
                    isSelected: _layout == FileLayout.grid,
                    onTap: () => setState(() => _layout = FileLayout.grid),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSortGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: [
        _buildSortItem(
          icon: Icons.sort_by_alpha,
          label: 'Title',
          option: FileSortOption.title,
        ),
        _buildSortItem(
          icon: Icons.calendar_month_outlined,
          label: 'Date',
          option: FileSortOption.date,
        ),
        _buildSortItem(
          icon: Icons.history,
          label: 'Played time',
          option: FileSortOption.playedTime,
        ),
        _buildSortItem(
          icon: Icons.play_circle_outline,
          label: 'Status',
          option: FileSortOption.status,
        ),
        _buildSortItem(
          icon: Icons.movie_outlined,
          label: 'Length',
          option: FileSortOption.length,
        ),
        _buildSortItem(
          icon: Icons.save_outlined,
          label: 'Size',
          option: FileSortOption.size,
        ),
        _buildSortItem(
          icon: Icons.hd_outlined,
          label: 'Resolution',
          option: FileSortOption.resolution,
        ),
        _buildSortItem(
          icon: Icons.location_on_outlined,
          label: 'Path',
          option: FileSortOption.path,
        ),
        _buildSortItem(
          icon: Icons.speed,
          label: 'Frame rate',
          option: FileSortOption.frameRate,
        ),
        _buildSortItem(
          icon: Icons.file_present_outlined,
          label: 'Type',
          option: FileSortOption.type,
        ),
      ],
    );
  }

  Widget _buildSortItem({
    required IconData icon,
    required String label,
    required FileSortOption option,
  }) {
    final isSelected = _sortOption == option;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () => setState(() => _sortOption = option),
      child: SizedBox(
        width: (MediaQuery.of(context).size.width - 80) / 5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : Colors.grey.withOpacity(0.8),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? primaryColor : Colors.grey.withOpacity(0.8),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? primaryColor : Colors.grey.withOpacity(0.8),
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? primaryColor : Colors.grey.withOpacity(0.8),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderToggle() {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: primaryColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isAscending = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isAscending
                      ? primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(7),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      size: 16,
                      color: _isAscending ? primaryColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Oldest',
                      style: TextStyle(
                        color: _isAscending ? primaryColor : Colors.grey,
                        fontWeight: _isAscending
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 40, color: primaryColor.withOpacity(0.3)),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isAscending = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isAscending
                      ? primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(7),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_downward,
                      size: 16,
                      color: !_isAscending ? primaryColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Newest',
                      style: TextStyle(
                        color: !_isAscending ? primaryColor : Colors.grey,
                        fontWeight: !_isAscending
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection(String title) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 20),
        TextButton(
          onPressed: () {
            Navigator.pop(context, {
              'viewMode': _viewMode,
              'layout': _layout,
              'sortOption': _sortOption,
              'isAscending': _isAscending,
            });
          },
          child: const Text(
            'Done',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
