import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';

class ThemeScreen extends ConsumerStatefulWidget {
  const ThemeScreen({super.key});

  @override
  ConsumerState<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends ConsumerState<ThemeScreen> {
  final List<Color> _classicColors = [
    const Color(0xFFFF6B5A),
    const Color(0xFFFF9E5A),
    const Color(0xFFFFD15A),
    const Color(0xFF9E775A),
    const Color(0xFFD1E02A),
    const Color(0xFF96E02A),
    const Color(0xFF2AE08E),
    const Color(0xFF2AE0D1),
    const Color(0xFF2A96E0),
    const Color(0xFF5A89FF),
    const Color(0xFF5A5AFF),
    const Color(0xFF9E5AFF),
    const Color(0xFFD95AFF),
    const Color(0xFFFF5A9E),
    const Color(0xFFFF5A6B),
    const Color(0xFFF2F2F2),
  ];

  final List<List<Color>> _splitColors = [
    [const Color(0xFFFF6B5A), const Color(0xFF1E1E2C)],
    [const Color(0xFFFF9E5A), const Color(0xFF1E1E2C)],
    [const Color(0xFFFFD15A), const Color(0xFF1E1E2C)],
    [const Color(0xFF9E775A), const Color(0xFF1E1E2C)],
    [const Color(0xFFD1E02A), const Color(0xFF1E1E2C)],
    [const Color(0xFF96E02A), const Color(0xFF1E1E2C)],
    [const Color(0xFF2AC4E0), const Color(0xFF1E1E2C)],
    [const Color(0xFF2A83E0), const Color(0xFF1E1E2C)],
    [const Color(0xFF3F51B5), const Color(0xFF1E1E2C)],
    [const Color(0xFF9C27B0), const Color(0xFF1E1E2C)],
    [const Color(0xFFE91E63), const Color(0xFF1E1E2C)],
    [const Color(0xFFFF5A9E), const Color(0xFF1E1E2C)],
  ];

  void _updateThemeMode(ThemeMode mode) {
    ref.read(themeProvider.notifier).setThemeMode(mode);
  }

  void _updateAccentColor(Color color) {
    ref.read(themeProvider.notifier).setAccentColor(color);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'App Theme',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Theme Modes
            _buildThemeModes(appTheme),
            const SizedBox(height: 24),

            // Classic Themes
            const Text(
              'Classic Themes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildClassicGrid(appTheme),
            const SizedBox(height: 32),

            // Other Themes
            const Text(
              'Other Themes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildOtherThemesGrid(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeModes(AppThemeData appTheme) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildThemeModeItem(
            'Adaptive',
            const Color(0xFFBBDEFB),
            icon: Icons.brightness_auto,
            isSelected: appTheme.themeMode == ThemeMode.system,
            onTap: () => _updateThemeMode(ThemeMode.system),
          ),
          _buildThemeModeItem(
            'Light Theme',
            const Color(0xFFE3F2FD),
            isUsing: appTheme.themeMode == ThemeMode.light,
            isSelected: appTheme.themeMode == ThemeMode.light,
            icon: Icons.wb_sunny,
            onTap: () => _updateThemeMode(ThemeMode.light),
          ),
          _buildThemeModeItem(
            'Dark Theme',
            const Color(0xFF303F9F),
            textColor: Colors.white,
            icon: Icons.nightlight_round,
            isSelected: appTheme.themeMode == ThemeMode.dark,
            onTap: () => _updateThemeMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeItem(
    String title,
    Color color, {
    bool isUsing = false,
    bool isSelected = false,
    Color textColor = Colors.black87,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if (icon != null)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(
                        icon,
                        color: textColor.withOpacity(0.3),
                        size: 40,
                      ),
                    ),
                ],
              ),
            ),
            if (isUsing)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Using',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
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

  Widget _buildClassicGrid(AppThemeData appTheme) {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: _classicColors.length,
          itemBuilder: (context, index) {
            final color = _classicColors[index];
            final isSelected = appTheme.accentColor.value == color.value;
            return InkWell(
              onTap: () => _updateAccentColor(color),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: Colors.black, width: 2)
                      : null,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: _splitColors.length,
          itemBuilder: (context, index) {
            final colors = _splitColors[index];
            return InkWell(
              onTap: () => _updateAccentColor(colors[0]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  children: [
                    Expanded(child: Container(color: colors[0])),
                    Expanded(child: Container(color: colors[1])),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOtherThemesGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.8,
      children: [
        _buildThematicItem('Zodiac Aries', 'Light Theme', 'zodiac_aries_theme'),
        _buildThematicItem('Zodiac Aries', 'Dark Theme', 'zodiac_aries_theme'),
        _buildThematicItem(
          'Zodiac Pisces',
          'Light Theme',
          'zodiac_pisces_theme',
        ),
        _buildThematicItem(
          'Zodiac Pisces',
          'Dark Theme',
          'zodiac_pisces_theme',
        ),
      ],
    );
  }

  Widget _buildThematicItem(String name, String mode, String imageName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
              image: const DecorationImage(
                image: NetworkImage('https://via.placeholder.com/300x400'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.3), Colors.transparent],
                ),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            mode,
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ),
      ],
    );
  }
}
