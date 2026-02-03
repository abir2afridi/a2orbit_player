import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../settings/presentation/settings_screen.dart';
import 'theme_screen.dart';
import 'developer_screen.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
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
              'Me',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35),
              Theme.of(context).colorScheme.background,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Main Grid Card
              _buildCard(context, [
                _buildGrid([
                  _buildGridItem(context, Icons.download_outlined, 'Downloads'),
                  _buildGridItem(
                    context,
                    Icons.swap_horizontal_circle_outlined,
                    'File Transfer',
                  ),
                  _buildGridItem(
                    context,
                    Icons.lock_person_outlined,
                    'Private Folder',
                  ),
                  _buildGridItem(
                    context,
                    Icons.playlist_play_outlined,
                    'Video Playlists',
                  ),
                  _buildGridItem(
                    context,
                    Icons.folder_open_outlined,
                    'Media Manager',
                  ),
                  _buildGridItem(
                    context,
                    Icons.computer_outlined,
                    'Local Network',
                  ),
                  _buildGridItem(
                    context,
                    Icons.language_outlined,
                    'Network Stream',
                  ),
                  _buildGridItem(
                    context,
                    Icons.cloud_queue_outlined,
                    'Cloud Drive',
                  ),
                  _buildGridItem(
                    context,
                    Icons.delete_outline_outlined,
                    'Recycle Bin',
                  ),
                ]),
              ]),
              const SizedBox(height: 16),

              // WhatsApp Status Saver Card
              _buildCard(context, [
                _buildListTile(
                  context,
                  Icons.chat,
                  'WhatsApp Status Saver',
                  iconColor: Colors.green,
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 16),

              // Settings Group Card
              _buildCard(context, [
                _buildListTile(
                  context,
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
                  context,
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
                  context,
                  Icons.picture_in_picture_alt_outlined,
                  'Custom Pop-up Play',
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 16),

              // Legal & Help Group Card
              _buildCard(context, [
                _buildListTile(
                  context,
                  Icons.gavel_outlined,
                  'Legal',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56),
                _buildListTile(context, Icons.help_outline, 'Help'),
              ]),
              const SizedBox(height: 24),
              // Developer Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      'Developer Information',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                  _buildCard(context, [
                    _buildListTile(
                      context,
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
      ),
    );
  }

  Widget _buildCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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

  Widget _buildGridItem(BuildContext context, IconData icon, String label) {
    return InkWell(
      onTap: () {},
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context,
    IconData icon,
    String title, {
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color:
            iconColor ??
            Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: Theme.of(context).colorScheme.onSurface,
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
