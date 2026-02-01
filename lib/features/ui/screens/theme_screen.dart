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

  void _toggleAmoled(bool value) {
    ref.read(themeProvider.notifier).setUseAmoled(value);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'App Theme',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Preview Section
            _buildThemePreview(colorScheme),
            const SizedBox(height: 32),

            // Top Theme Modes
            _buildThemeModes(appTheme, colorScheme),
            const SizedBox(height: 24),

            // AMOLED Toggle for Dark Mode
            if (appTheme.themeMode == ThemeMode.dark ||
                (appTheme.themeMode == ThemeMode.system &&
                    theme.brightness == Brightness.dark))
              _buildAmoledToggle(appTheme, colorScheme),

            const SizedBox(height: 32),

            // Classic Themes
            Text(
              'Classic Themes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildClassicGrid(appTheme, colorScheme),
            const SizedBox(height: 32),

            // Other Themes (Thematic)
            Text(
              'Other Themes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildOtherThemesGrid(colorScheme),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAmoledToggle(AppThemeData appTheme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.dark_mode_outlined, color: colorScheme.primary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pure Black (AMOLED)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Save battery on OLED screens',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: appTheme.useAmoled,
            onChanged: _toggleAmoled,
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModes(AppThemeData appTheme, ColorScheme colorScheme) {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildThemeModeItem(
            'Adaptive',
            const Color(0xFFBBDEFB),
            icon: Icons.brightness_auto,
            isSelected: appTheme.themeMode == ThemeMode.system,
            onTap: () => _updateThemeMode(ThemeMode.system),
            colorScheme: colorScheme,
          ),
          _buildThemeModeItem(
            'Light Theme',
            const Color(0xFFE3F2FD),
            isSelected: appTheme.themeMode == ThemeMode.light,
            icon: Icons.wb_sunny,
            onTap: () => _updateThemeMode(ThemeMode.light),
            colorScheme: colorScheme,
          ),
          _buildThemeModeItem(
            'Dark Theme',
            const Color(0xFF1A237E),
            textColor: Colors.white,
            isSelected: appTheme.themeMode == ThemeMode.dark,
            icon: Icons.nightlight_round,
            onTap: () => _updateThemeMode(ThemeMode.dark),
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeItem(
    String title,
    Color color, {
    bool isSelected = false,
    Color textColor = Colors.black87,
    IconData? icon,
    VoidCallback? onTap,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 130,
            margin: const EdgeInsets.only(right: 12, top: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: colorScheme.primary, width: 2.5)
                  : null,
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (icon != null)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(
                        icon,
                        color: textColor.withOpacity(0.2),
                        size: 44,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 0,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.surface, width: 2),
                ),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassicGrid(AppThemeData appTheme, ColorScheme colorScheme) {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: _classicColors.length,
          itemBuilder: (context, index) {
            final color = _classicColors[index];
            final isSelected = appTheme.accentColor.value == color.value;
            return GestureDetector(
              onTap: () => _updateAccentColor(color),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Center(
                      child: Icon(Icons.check, color: Colors.white, size: 18),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: _splitColors.length,
          itemBuilder: (context, index) {
            final colors = _splitColors[index];
            final isSelected = appTheme.accentColor.value == colors[0].value;
            return GestureDetector(
              onTap: () => _updateAccentColor(colors[0]),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      children: [
                        Expanded(child: Container(color: colors[0])),
                        Expanded(child: Container(color: colors[1])),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.check, color: Colors.white, size: 18),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOtherThemesGrid(ColorScheme colorScheme) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: [
        _buildThematicItem(
          'Zodiac Aries',
          'Light Theme',
          'zodiac_aries_theme',
          colorScheme,
        ),
        _buildThematicItem(
          'Zodiac Aries',
          'Dark Theme',
          'zodiac_aries_theme',
          colorScheme,
        ),
        _buildThematicItem(
          'Zodiac Pisces',
          'Light Theme',
          'zodiac_pisces_theme',
          colorScheme,
        ),
        _buildThematicItem(
          'Zodiac Pisces',
          'Dark Theme',
          'zodiac_pisces_theme',
          colorScheme,
        ),
      ],
    );
  }

  Widget _buildThematicItem(
    String name,
    String mode,
    String imageName,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                color: colorScheme.surfaceVariant,
                image: const DecorationImage(
                  image: NetworkImage('https://via.placeholder.com/300x400'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Text(
                mode,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePreview(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 8,
                      width: 80,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: true,
                onChanged: (_) {},
                activeColor: colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMiniChip(colorScheme, 'Video', true),
              const SizedBox(width: 8),
              _buildMiniChip(colorScheme, 'Music', false),
              const SizedBox(width: 8),
              _buildMiniChip(colorScheme, 'Folders', false),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.6,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(ColorScheme colorScheme, String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? colorScheme.primary : colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : colorScheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
