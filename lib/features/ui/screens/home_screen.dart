import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../storage/models/file_view_settings.dart';
import '../../storage/presentation/file_browser_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../storage/presentation/widgets/file_view_settings_bottom_sheet.dart';
import '../../storage/providers/file_settings_provider.dart';
import 'me_screen.dart';
import 'music_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0; // Default to Local/Folders
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  void _showFileSettings() async {
    final settings = ref.read(fileSettingsProvider);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FileViewSettingsBottomSheet(
        initialViewMode: settings.viewMode,
        initialLayout: settings.layout,
        initialSortOption: settings.sortOption,
        isAscending: settings.isAscending,
      ),
    );

    if (result != null) {
      ref
          .read(fileSettingsProvider.notifier)
          .updateAll(
            viewMode: result['viewMode'],
            layout: result['layout'],
            sortOption: result['sortOption'],
            isAscending: result['isAscending'],
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide default AppBar for Music (index 1) and Me (index 3)
    final bool hideDefaultAppBar = _currentIndex == 1 || _currentIndex == 3;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: hideDefaultAppBar
          ? null
          : AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search videos...',
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'A2Orbit Player',
                          style: GoogleFonts.raleway(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          _currentIndex == 0 ? 'Local' : 'Transfer',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.cast,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchQuery = '';
                        _searchController.clear();
                      }
                    });
                  },
                  icon: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                IconButton(
                  onPressed: _showFileSettings,
                  icon: Icon(
                    ref.watch(fileSettingsProvider).layout == FileLayout.grid
                        ? Icons.grid_view
                        : Icons.list,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  tooltip: 'View Settings',
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.person_outline,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Action Chips (hidden on Music and Me tabs)
          if (!hideDefaultAppBar)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildQuickChip(Icons.music_note, 'Music'),
                  _buildQuickChip(Icons.lock_outline, 'Privacy'),
                  _buildQuickChip(Icons.share_outlined, 'Share'),
                  _buildQuickChip(
                    Icons.download_for_offline_outlined,
                    'Downloads',
                  ),
                ],
              ),
            ),

          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                FileBrowserScreen(isEmbedded: true, searchQuery: _searchQuery),
                const MusicScreen(),
                const Center(child: Text('Transfer Screen')),
                const MeScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 10,
        backgroundColor: Theme.of(context).colorScheme.surface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(
          context,
        ).colorScheme.onSurface.withOpacity(0.6),
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _isSearching = false;
            _searchQuery = '';
            _searchController.clear();
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_open),
            label: 'Local',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note_outlined),
            label: 'Music',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: 'Transfer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Me',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
