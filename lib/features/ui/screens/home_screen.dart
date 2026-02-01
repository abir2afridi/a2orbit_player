import 'package:flutter/material.dart';
import '../../storage/presentation/file_browser_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1; // Default to Folders
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
            : const Text(
                'Folders',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.cast, color: Colors.black54),
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
              color: Colors.black54,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.grid_view, color: Colors.black54),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.person_outline, color: Colors.black54),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Action Chips
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
                const Center(child: Text('Local Videos')),
                FileBrowserScreen(isEmbedded: true, searchQuery: _searchQuery),
                const Center(child: Text('Music Screen')),
                const Center(child: Text('Settings Screen')),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        elevation: 10,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            label: 'Local',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_open),
            label: 'Folders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note_outlined),
            label: 'Music',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Me'),
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
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
