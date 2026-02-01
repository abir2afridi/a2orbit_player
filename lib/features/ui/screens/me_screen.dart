import 'package:flutter/material.dart';
import '../../settings/presentation/settings_screen.dart';
import 'theme_screen.dart';
import 'developer_screen.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3F2FD), Color(0xFFF5F7FA)],
          stops: [0.0, 0.3],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 20),
              child: Text(
                'Me',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            // Main Grid Card
            _buildCard([
              _buildGrid([
                _buildGridItem(Icons.download_outlined, 'Downloads'),
                _buildGridItem(
                  Icons.swap_horizontal_circle_outlined,
                  'File Transfer',
                ),
                _buildGridItem(Icons.lock_person_outlined, 'Private Folder'),
                _buildGridItem(Icons.playlist_play_outlined, 'Video Playlists'),
                _buildGridItem(Icons.folder_open_outlined, 'Media Manager'),
                _buildGridItem(Icons.computer_outlined, 'Local Network'),
                _buildGridItem(Icons.language_outlined, 'Network Stream'),
                _buildGridItem(Icons.cloud_queue_outlined, 'Cloud Drive'),
                _buildGridItem(Icons.delete_outline_outlined, 'Recycle Bin'),
              ]),
            ]),
            const SizedBox(height: 16),

            // WhatsApp Status Saver Card
            _buildCard([
              _buildListTile(
                Icons.chat,
                'WhatsApp Status Saver',
                iconColor: Colors.green,
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 16),

            // Settings Group Card
            _buildCard([
              _buildListTile(
                Icons.checkroom_outlined,
                'App Theme',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ThemeScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              _buildListTile(
                Icons.settings_outlined,
                'Settings',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              _buildListTile(
                Icons.picture_in_picture_alt_outlined,
                'Custom Pop-up Play',
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 16),

            // Legal & Help Group Card
            _buildCard([
              _buildListTile(Icons.gavel_outlined, 'Legal', onTap: () {}),
              const Divider(height: 1, indent: 56),
              _buildListTile(Icons.help_outline, 'Help'),
            ]),
            const SizedBox(height: 24), // Changed from 16 to 24
            // Developer Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    'Developer Information',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ),
                _buildCard([
                  _buildListTile(
                    Icons.person_outline,
                    'About Developer',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DeveloperScreen(),
                        ),
                      );
                    },
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildGrid(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
        children: children,
      ),
    );
  }

  Widget _buildGridItem(IconData icon, String label) {
    return InkWell(
      onTap: () {},
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: const Color(0xFF2196F3)),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    IconData icon,
    String title, {
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.black54),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
        color: Colors.black26,
      ),
      onTap: onTap,
    );
  }
}
