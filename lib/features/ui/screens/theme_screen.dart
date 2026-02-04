import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';

class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final colors = [
      Colors.redAccent,
      Colors.orangeAccent,
      Colors.amber,
      Colors.brown,
      Colors.lime,
      Colors.lightGreen,
      Colors.green,
      Colors.teal,
      Colors.cyan,
      const Color(0xFF6B4DFF), // Custom Purple/Blue
      Colors.purpleAccent,
      Colors.pinkAccent,
      const Color(0xFFFF4081),
      Colors.grey[300]!, // Whiteish
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('App Theme'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Grid (Modes)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildModeCard(
                  context,
                  title: 'Adaptive',
                  icon: Icons.brightness_auto,
                  isSelected: themeData.themeMode == ThemeMode.system,
                  color: Colors.blue.shade200,
                  onTap: () {
                    themeNotifier.setThemeMode(ThemeMode.system);
                    themeNotifier.setUseAmoled(false);
                  },
                ),
                _buildModeCard(
                  context,
                  title: 'Dark Theme',
                  icon: Icons.nightlight_round,
                  isSelected:
                      themeData.themeMode == ThemeMode.dark &&
                      !themeData.useAmoled,
                  color: const Color(0xFF2C3E50),
                  textColor: Colors.white,
                  onTap: () {
                    themeNotifier.setThemeMode(ThemeMode.dark);
                    themeNotifier.setUseAmoled(false);
                  },
                ),
                _buildModeCard(
                  context,
                  title: 'Light Theme',
                  icon: Icons.wb_sunny_rounded,
                  isSelected: themeData.themeMode == ThemeMode.light,
                  color: const Color(0xFFF5F5F5),
                  textColor: Colors.black87,
                  onTap: () {
                    themeNotifier.setThemeMode(ThemeMode.light);
                    themeNotifier.setUseAmoled(false);
                  },
                ),
                _buildModeCard(
                  context,
                  title: 'Amoled Black',
                  subtitle: 'Using',
                  icon: Icons.landscape, // Placeholder for mountain icon
                  isSelected:
                      themeData.useAmoled &&
                      (themeData.themeMode == ThemeMode.dark ||
                          themeData.themeMode ==
                              ThemeMode.system), // Approximate check
                  color: Colors.black,
                  textColor: Colors.white,
                  onTap: () {
                    themeNotifier.setThemeMode(ThemeMode.dark);
                    themeNotifier.setUseAmoled(true);
                  },
                  isAmoled: true,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Classic Themes
            const Text(
              'Classic Themes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildColorGrid(
              colors: colors,
              selectedColor: themeData.style == ThemeStyle.normal
                  ? themeData.accentColor
                  : null,
              onColorSelected: (color) {
                themeNotifier.setThemeStyle(ThemeStyle.normal);
                themeNotifier.setAccentColor(color);
                themeNotifier.setHeaderColor(null);
                themeNotifier.setAhsColor(null);
              },
            ),

            const SizedBox(height: 24),

            // Dynamic Themes
            const Text(
              'Dynamic Theme',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTwoToneGrid(
              colors: colors,
              selectedColor: themeData.style == ThemeStyle.dynamic
                  ? themeData.headerColor
                  : null,
              baseColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              onColorSelected: (color) {
                themeNotifier.setThemeStyle(ThemeStyle.dynamic);
                themeNotifier.setHeaderColor(color);
                themeNotifier.setAhsColor(null);
                // Maybe keep existing accent? Or update it too?
                // User said "Dynamic er kaj holo only header er color change kora"
                // So we might leave accent color alone or sync it.
                // Let's assume we update accent color too for consistency in other widgets
                themeNotifier.setAccentColor(color);
              },
            ),

            const SizedBox(height: 24),

            // AHS Themes
            const Text(
              'AHS Theme',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildColorGrid(
              colors: colors,
              selectedColor: themeData.style == ThemeStyle.ahs
                  ? themeData.ahsColor
                  : null,
              onColorSelected: (color) {
                themeNotifier.setThemeStyle(ThemeStyle.ahs);
                themeNotifier.setAhsColor(color);
                themeNotifier.setHeaderColor(null);
                themeNotifier.setAccentColor(color);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required bool isSelected,
    required Color color,
    Color? textColor,
    required VoidCallback onTap,
    bool isAmoled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: Theme.of(context).primaryColor, width: 2)
              : null,
          boxShadow: [
            if (!isAmoled)
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor ?? Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Icon(
                icon,
                color: (textColor ?? Colors.black87).withOpacity(0.5),
                size: 32,
              ),
            ),
            if (isSelected && subtitle != null)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subtitle,
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
    );
  }

  Widget _buildColorGrid({
    required List<Color> colors,
    required Color? selectedColor,
    required Function(Color) onColorSelected,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: colors.length,
      itemBuilder: (context, index) {
        final color = colors[index];
        final isSelected = selectedColor?.value == color.value;

        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTwoToneGrid({
    required List<Color> colors,
    required Color? selectedColor,
    required Color baseColor,
    required Function(Color) onColorSelected,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: colors.length,
      itemBuilder: (context, index) {
        final color = colors[index];
        final isSelected = selectedColor?.value == color.value;

        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Expanded(child: Container(color: color)),
                Expanded(child: Container(color: baseColor.withOpacity(0.1))),
              ],
            ),
          ),
        );
      },
    );
  }
}
