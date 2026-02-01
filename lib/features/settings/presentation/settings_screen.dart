import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _backgroundPlay = true;
  bool _pipMode = true;
  bool _audioOnly = false;
  bool _volumeBoost = false;
  bool _showGesturesHints = true;
  bool _autoRotate = true;
  bool _keepScreenOn = true;
  bool _hardwareAcceleration = true;
  double _playbackSpeed = 1.0;
  int _seekDuration = 10; // seconds
  String _defaultSubtitleLanguage = 'en';
  String _defaultAudioLanguage = 'en';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settings),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(AppStrings.playerSettings, [
            _buildSwitchTile(
              title: 'Background Play',
              subtitle: 'Continue playing when app is in background',
              value: _backgroundPlay,
              onChanged: (value) => setState(() => _backgroundPlay = value),
            ),
            _buildSwitchTile(
              title: 'Picture-in-Picture',
              subtitle: 'Show mini player when app is minimized',
              value: _pipMode,
              onChanged: (value) => setState(() => _pipMode = value),
            ),
            _buildSwitchTile(
              title: 'Audio Only Mode',
              subtitle: 'Play only audio from videos',
              value: _audioOnly,
              onChanged: (value) => setState(() => _audioOnly = value),
            ),
            _buildSwitchTile(
              title: 'Volume Boost',
              subtitle: 'Increase volume beyond 100%',
              value: _volumeBoost,
              onChanged: (value) => setState(() => _volumeBoost = value),
            ),
            _buildSliderTile(
              title: 'Default Playback Speed',
              subtitle: '${_playbackSpeed.toStringAsFixed(1)}x',
              value: _playbackSpeed,
              min: 0.25,
              max: 3.0,
              divisions: 11,
              onChanged: (value) => setState(() => _playbackSpeed = value),
            ),
            _buildSliderTile(
              title: 'Seek Duration',
              subtitle: '$_seekDuration seconds',
              value: _seekDuration.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              onChanged: (value) => setState(() => _seekDuration = value.round()),
            ),
            _buildSwitchTile(
              title: 'Hardware Acceleration',
              subtitle: 'Use hardware for video decoding',
              value: _hardwareAcceleration,
              onChanged: (value) => setState(() => _hardwareAcceleration = value),
            ),
          ]),

          const SizedBox(height: 24),

          _buildSection(AppStrings.gestureSettings, [
            _buildSwitchTile(
              title: 'Show Gesture Hints',
              subtitle: 'Display gesture controls overlay',
              value: _showGesturesHints,
              onChanged: (value) => setState(() => _showGesturesHints = value),
            ),
            _buildSwitchTile(
              title: 'Auto Rotate',
              subtitle: 'Automatically rotate on fullscreen',
              value: _autoRotate,
              onChanged: (value) => setState(() => _autoRotate = value),
            ),
          ]),

          const SizedBox(height: 24),

          _buildSection(AppStrings.audioSettings, [
            _buildDropdownTile(
              title: 'Default Audio Language',
              value: _defaultAudioLanguage,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'es', child: Text('Spanish')),
                DropdownMenuItem(value: 'fr', child: Text('French')),
                DropdownMenuItem(value: 'de', child: Text('German')),
                DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                DropdownMenuItem(value: 'zh', child: Text('Chinese')),
              ],
              onChanged: (value) => setState(() => _defaultAudioLanguage = value!),
            ),
          ]),

          const SizedBox(height: 24),

          _buildSection(AppStrings.subtitleSettings, [
            _buildDropdownTile(
              title: 'Default Subtitle Language',
              value: _defaultSubtitleLanguage,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'es', child: Text('Spanish')),
                DropdownMenuItem(value: 'fr', child: Text('French')),
                DropdownMenuItem(value: 'de', child: Text('German')),
                DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                DropdownMenuItem(value: 'off', child: Text('Off')),
              ],
              onChanged: (value) => setState(() => _defaultSubtitleLanguage = value!),
            ),
          ]),

          const SizedBox(height: 24),

          _buildSection('System', [
            _buildSwitchTile(
              title: 'Keep Screen On',
              subtitle: 'Prevent screen from turning off during playback',
              value: _keepScreenOn,
              onChanged: (value) => setState(() => _keepScreenOn = value),
            ),
          ]),

          const SizedBox(height: 24),

          _buildSection('About', [
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('App Version'),
              subtitle: const Text('1.0.0'),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('About'),
              subtitle: const Text('A2Orbit Player - Professional Video Player'),
              onTap: () {
                showLicensePage(context: context);
              },
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.lightPrimary,
            ),
          ),
        ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.lightPrimary,
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: SizedBox(
        width: 150,
        child: Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.lightPrimary,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        items: items,
        onChanged: onChanged,
        underline: Container(),
      ),
    );
  }
}
