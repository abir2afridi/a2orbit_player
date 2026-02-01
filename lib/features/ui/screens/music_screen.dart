import 'package:flutter/material.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Music',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: Colors.black87),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.black45,
          indicatorColor: Colors.blue,
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          tabs: const [
            Tab(text: 'Tracks'),
            Tab(text: 'Playlists'),
            Tab(text: 'Albums'),
            Tab(text: 'Artists'),
            Tab(text: 'Folders'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search and Shuffle row
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const TextField(
                          decoration: InputDecoration(
                            icon: Icon(
                              Icons.search,
                              color: Colors.black45,
                              size: 20,
                            ),
                            hintText: 'Search Songs...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.black38),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.shuffle, size: 18),
                        label: const Text('Shuffle All'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.swap_vert, color: Colors.black87),
                    ),
                  ],
                ),
              ),

              // Song list (Empty state as per screenshot)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_note_outlined,
                        size: 64,
                        color: Colors.black12,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No songs found',
                        style: TextStyle(color: Colors.black38, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Mini Player
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _buildMiniPlayer(),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          // Music Icon Box
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEFE6FF),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.music_note,
              color: Color(0xFF9162FF),
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          // Title
          const Expanded(
            child: Text(
              '09-WA0002 - Unknown',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Controls
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.play_circle_filled,
              color: Colors.white,
              size: 32,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.playlist_play,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
