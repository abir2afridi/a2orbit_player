import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  AppSettings get _settings => ref.watch(settingsProvider);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.raleway(
            color: Theme.of(context).appBarTheme.foregroundColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSettingItem(
            context: context,
            icon: Icons.list,
            title: 'List',
            onTap: () => _navigateToSubSettings('List'),
          ),
          _buildSettingItem(
            context: context,
            icon: Icons.play_arrow,
            title: 'Player',
            onTap: () => _navigateToSubSettings('Player'),
          ),
          _buildSettingItem(
            context: context,
            icon: Icons.settings,
            title: 'Decoder',
            onTap: () => _navigateToSubSettings('Decoder'),
          ),
          _buildSettingItem(
            context: context,
            icon: Icons.music_note,
            title: 'Audio',
            onTap: () => _navigateToSubSettings('Audio'),
          ),
          _buildSettingItem(
            context: context,
            icon: Icons.subtitles,
            title: 'Subtitle',
            onTap: () => _navigateToSubSettings('Subtitle'),
          ),
          _buildSettingItem(
            context: context,
            icon: Icons.check_box,
            title: 'General',
            onTap: () => _navigateToSubSettings('General'),
          ),
          _buildSettingItem(
            context: context,
            icon: Icons.code,
            title: 'Development',
            onTap: () => _navigateToSubSettings('Development'),
          ),
          _buildSettingItem(
            context: context,
            icon: Icons.language,
            title: 'App Language',
            onTap: () => _navigateToSubSettings('App Language'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }

  void _navigateToSubSettings(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _DetailedSettingsScreen(
          category: category,
          settings: _settings,
          onUpdate: (key, value) => _updateSetting(key, value),
        ),
      ),
    );
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    await ref.read(settingsProvider.notifier).updateSetting(key, value);
  }
}

class _DetailedSettingsScreen extends ConsumerStatefulWidget {
  final String category;
  final AppSettings settings;
  final Function(String, dynamic) onUpdate;

  const _DetailedSettingsScreen({
    required this.category,
    required this.settings,
    required this.onUpdate,
  });

  @override
  ConsumerState<_DetailedSettingsScreen> createState() =>
      _DetailedSettingsScreenState();
}

class _DetailedSettingsScreenState
    extends ConsumerState<_DetailedSettingsScreen> {
  AppSettings get _settings => ref.watch(settingsProvider);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.category,
          style: GoogleFonts.raleway(
            color: Theme.of(context).appBarTheme.foregroundColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _buildCategorySettings(),
      ),
    );
  }

  List<Widget> _buildCategorySettings() {
    switch (widget.category) {
      case 'List':
        return _buildListSettings();
      case 'Player':
        return _buildPlayerSettings();
      case 'Decoder':
        return _buildDecoderSettings();
      case 'Audio':
        return _buildAudioSettings();
      case 'Subtitle':
        return _buildSubtitleSettings();
      case 'General':
        return _buildGeneralSettings();
      case 'Development':
        return _buildDevelopmentSettings();
      case 'App Language':
        return _buildLanguageSettings();
      default:
        return [];
    }
  }

  List<Widget> _buildListSettings() {
    return [
      _buildSection('File View', [
        _buildSwitchTile(
          title: 'Show Hidden Files',
          subtitle: 'Display hidden files and folders',
          value: false,
          onChanged: (value) {},
        ),
        _buildSwitchTile(
          title: 'Show File Extensions',
          subtitle: 'Display file extensions in list',
          value: true,
          onChanged: (value) {},
        ),
      ]),
    ];
  }

  List<Widget> _buildPlayerSettings() {
    return [
      _buildSection(AppStrings.playerSettings, [
        _buildBackgroundPlayOptions(),
        const Divider(height: 1),
        _buildSwitchTile(
          title: 'Screen Off Playback',
          subtitle: 'Continue playback when screen is off',
          value: _settings.enableScreenOffPlayback,
          onChanged: (value) => widget.onUpdate('screen_off_playback', value),
        ),
        _buildSwitchTile(
          title: 'Auto-enter PiP',
          subtitle: 'Automatically enter PiP on home button',
          value: _settings.autoEnterPip,
          onChanged: (value) => widget.onUpdate('auto_enter_pip', value),
        ),
        _buildSwitchTile(
          title: 'Audio Only Mode',
          subtitle: 'Play only audio from videos',
          value: _settings.audioOnly,
          onChanged: (value) => widget.onUpdate('audio_only', value),
        ),
        _buildSwitchTile(
          title: 'Volume Boost',
          subtitle: 'Increase volume beyond 100%',
          value: _settings.volumeBoost,
          onChanged: (value) => widget.onUpdate('volume_boost', value),
        ),
        _buildSliderTile(
          title: 'Default Playback Speed',
          subtitle: '${_settings.playbackSpeed.toStringAsFixed(1)}x',
          value: _settings.playbackSpeed,
          min: 0.25,
          max: 3.0,
          divisions: 11,
          onChanged: (value) => widget.onUpdate('playback_speed', value),
        ),
        _buildSliderTile(
          title: 'Seek Duration',
          subtitle: '${(_settings.seekDuration / 1000).round()} seconds',
          value: (_settings.seekDuration / 1000).clamp(5.0, 60.0).toDouble(),
          min: 5,
          max: 60,
          divisions: 11,
          onChanged: (value) =>
              widget.onUpdate('seek_duration', (value * 1000).round()),
        ),
        _buildSwitchTile(
          title: 'A-B Repeat',
          subtitle: 'Enable looping between two points',
          value: _settings.enableABRepeat,
          onChanged: (value) => widget.onUpdate('enable_ab_repeat', value),
        ),
      ]),
      const SizedBox(height: 24),
      _buildSection('Timeline Preview', [
        _buildSwitchTile(
          title: 'Frame Preview Thumbnail',
          subtitle: 'Show floating video preview while scrubbing',
          value: _settings.enableTimelinePreviewThumbnail,
          onChanged: (value) =>
              widget.onUpdate('timeline_preview_enabled', value),
        ),
        _buildSwitchTile(
          title: 'Rounded Thumbnail',
          subtitle: 'Apply rounded corners and soft shadow',
          value: _settings.timelineRoundedThumbnail,
          onChanged: (value) =>
              widget.onUpdate('timeline_preview_rounded', value),
          enabled: _settings.enableTimelinePreviewThumbnail,
        ),
        _buildSwitchTile(
          title: 'Show Timestamp',
          subtitle: 'Display time overlay on the preview bubble',
          value: _settings.timelineShowTimestamp,
          onChanged: (value) =>
              widget.onUpdate('timeline_preview_timestamp', value),
          enabled: _settings.enableTimelinePreviewThumbnail,
        ),
        _buildSwitchTile(
          title: 'Smooth Animation',
          subtitle: 'Fade the preview in and out smoothly',
          value: _settings.timelineSmoothAnimation,
          onChanged: (value) =>
              widget.onUpdate('timeline_preview_animation', value),
          enabled: _settings.enableTimelinePreviewThumbnail,
        ),
        _buildSwitchTile(
          title: 'Fast Scrub Optimization',
          subtitle: 'Skip intermediate frames when dragging quickly',
          value: _settings.timelineFastScrubOptimization,
          onChanged: (value) =>
              widget.onUpdate('timeline_preview_fast_scrub', value),
          enabled: _settings.enableTimelinePreviewThumbnail,
        ),
      ]),
      const SizedBox(height: 24),
      _buildSection(AppStrings.gestureSettings, [
        _buildSwitchTile(
          title: 'Show Gesture Hints',
          subtitle: 'Display gesture controls overlay',
          value: _settings.showGesturesHints,
          onChanged: (value) => widget.onUpdate('show_gestures_hints', value),
        ),
        _buildSwitchTile(
          title: 'Always Rotate Video',
          subtitle: 'Follow device orientation during playback',
          value: _settings.autoRotateVideo,
          onChanged: (value) => widget.onUpdate('auto_rotate_video', value),
        ),
        _buildSwitchTile(
          title: 'Seek Gestures',
          subtitle: 'Swipe left/right to seek',
          value: _settings.enableGestureSeek,
          onChanged: (value) => widget.onUpdate('gesture_seek', value),
        ),
        _buildSwitchTile(
          title: 'Brightness Gestures',
          subtitle: 'Swipe up/down (left) to adjust brightness',
          value: _settings.enableGestureBrightness,
          onChanged: (value) => widget.onUpdate('gesture_brightness', value),
        ),
        _buildSwitchTile(
          title: 'Volume Gestures',
          subtitle: 'Swipe up/down (right) to adjust volume',
          value: _settings.enableGestureVolume,
          onChanged: (value) => widget.onUpdate('gesture_volume', value),
        ),
      ]),
    ];
  }

  List<Widget> _buildDecoderSettings() {
    return [
      _buildSection('Hardware Acceleration', [
        _buildSwitchTile(
          title: 'Hardware Acceleration',
          subtitle: 'Use hardware for video decoding',
          value: _settings.enableHardwareAcceleration,
          onChanged: (value) => widget.onUpdate('hardware_acceleration', value),
        ),
      ]),
    ];
  }

  List<Widget> _buildAudioSettings() {
    return [
      _buildSection(AppStrings.audioSettings, [
        _buildDropdownTile(
          title: 'Default Audio Language',
          value: _settings.defaultAudioLanguage,
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'es', child: Text('Spanish')),
            DropdownMenuItem(value: 'fr', child: Text('French')),
            DropdownMenuItem(value: 'de', child: Text('German')),
            DropdownMenuItem(value: 'ja', child: Text('Japanese')),
            DropdownMenuItem(value: 'zh', child: Text('Chinese')),
          ],
          onChanged: (value) =>
              widget.onUpdate('default_audio_language', value ?? 'en'),
        ),
      ]),
    ];
  }

  List<Widget> _buildSubtitleSettings() {
    return [
      _buildSection(AppStrings.subtitleSettings, [
        _buildDropdownTile(
          title: 'Default Subtitle Language',
          value: _settings.defaultSubtitleLanguage,
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'es', child: Text('Spanish')),
            DropdownMenuItem(value: 'fr', child: Text('French')),
            DropdownMenuItem(value: 'de', child: Text('German')),
            DropdownMenuItem(value: 'ja', child: Text('Japanese')),
            DropdownMenuItem(value: 'zh', child: Text('Chinese')),
            DropdownMenuItem(value: 'off', child: Text('Off')),
          ],
          onChanged: (value) =>
              widget.onUpdate('default_subtitle_language', value ?? 'en'),
        ),
        _buildSliderTile(
          title: 'Subtitle Font Size',
          subtitle: '${_settings.subtitleFontSize.toStringAsFixed(0)} pt',
          value: _settings.subtitleFontSize,
          min: 10,
          max: 40,
          divisions: 30,
          onChanged: (value) => widget.onUpdate('subtitle_font_size', value),
        ),
        _buildSliderTile(
          title: 'Subtitle Background Opacity',
          subtitle: '${(_settings.subtitleBackgroundOpacity * 100).round()}%',
          value: _settings.subtitleBackgroundOpacity,
          min: 0,
          max: 1,
          divisions: 10,
          onChanged: (value) =>
              widget.onUpdate('subtitle_background_opacity', value),
        ),
      ]),
    ];
  }

  List<Widget> _buildGeneralSettings() {
    final appLockState = ref.watch(appLockProvider);
    final privacyService = ref.watch(privacyServiceProvider);
    final hiddenCount = privacyService.getHiddenVideos().length;
    final privateFolderPath = privacyService.getPrivateFolderPath();

    return [
      _buildSection('App Theme', [
        _buildDropdownTile(
          title: 'Theme',
          value: _settings.themeMode,
          items: const [
            DropdownMenuItem(value: 'system', child: Text('System')),
            DropdownMenuItem(value: 'light', child: Text('Light')),
            DropdownMenuItem(value: 'dark', child: Text('Dark')),
            DropdownMenuItem(value: 'amoled', child: Text('AMOLED Black')),
          ],
          onChanged: (value) =>
              widget.onUpdate('theme_mode', value ?? 'system'),
        ),
      ]),
      const SizedBox(height: 24),
      _buildSection('System', [
        _buildSwitchTile(
          title: 'Keep Screen On',
          subtitle: 'Prevent screen from turning off during playback',
          value: _settings.keepScreenOn,
          onChanged: (value) => widget.onUpdate('keep_screen_on', value),
        ),
        _buildSwitchTile(
          title: 'Resume Playback',
          subtitle: 'Continue from last position next time',
          value: _settings.resumePlayback,
          onChanged: (value) => widget.onUpdate('resume_playback', value),
        ),
      ]),
      const SizedBox(height: 24),
      _buildSection(
        AppStrings.privacySettings,
        _buildPrivacyTiles(appLockState, hiddenCount, privateFolderPath),
      ),
    ];
  }

  List<Widget> _buildDevelopmentSettings() {
    return [
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
    ];
  }

  List<Widget> _buildLanguageSettings() {
    return [
      _buildSection('Language', [
        _buildDropdownTile(
          title: 'App Language',
          value: 'en',
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
            DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
            DropdownMenuItem(value: 'es', child: Text('Español')),
          ],
          onChanged: (value) {},
        ),
      ]),
    ];
  }

  Widget _buildBackgroundPlayOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Background Play',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ...BackgroundPlayOption.values.map(
          (option) => RadioListTile<BackgroundPlayOption>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(switch (option) {
              BackgroundPlayOption.stop => 'Stop when app is backgrounded',
              BackgroundPlayOption.backgroundAudio =>
                'Play audio/video in background',
              BackgroundPlayOption.pictureInPicture =>
                'Enter Picture-in-Picture mode',
            }),
            value: option,
            groupValue: _settings.backgroundPlayOption,
            onChanged: (value) {
              if (value != null) {
                widget.onUpdate('background_play_option', value);
              }
            },
          ),
        ),
      ],
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
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final inactiveColor = theme.colorScheme.onSurface.withOpacity(0.4);

    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(color: enabled ? null : inactiveColor),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: enabled ? theme.textTheme.bodySmall?.color : inactiveColor,
        ),
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeColor: theme.colorScheme.primary,
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
          activeColor: Theme.of(context).colorScheme.primary,
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

  List<Widget> _buildPrivacyTiles(
    AppLockState appLockState,
    int hiddenCount,
    String? privateFolderPath,
  ) {
    return [
      SwitchListTile(
        title: const Text('App Lock'),
        subtitle: Text(
          appLockState.isEnabled
              ? 'Enabled · Requires PIN on launch'
              : appLockState.hasPin
              ? 'Disabled · PIN saved'
              : 'Protect the app with a PIN',
        ),
        value: appLockState.isEnabled,
        onChanged: (value) => _handleAppLockToggle(value, appLockState),
      ),
      ListTile(
        leading: const Icon(Icons.pin),
        title: Text(appLockState.hasPin ? 'Change PIN' : 'Set PIN'),
        subtitle: Text(
          appLockState.hasPin
              ? 'Update your existing PIN'
              : 'Create a 4-6 digit PIN',
        ),
        onTap: () => _showSetPinDialog(isUpdate: appLockState.hasPin),
        trailing: const Icon(Icons.chevron_right),
      ),
      if (appLockState.hasPin)
        ListTile(
          leading: const Icon(Icons.lock_open),
          title: const Text('Disable App Lock'),
          subtitle: const Text('Turn off PIN protection'),
          onTap: _confirmDisableAppLock,
          trailing: const Icon(Icons.chevron_right),
        ),
      if (appLockState.biometricAvailable)
        SwitchListTile(
          title: const Text('Biometric Unlock'),
          subtitle: Text(
            appLockState.biometricEnabled
                ? 'Fingerprint / face unlock enabled'
                : 'Use device biometrics after unlocking',
          ),
          value: appLockState.biometricEnabled,
          onChanged: appLockState.isEnabled
              ? (value) => ref
                    .read(appLockProvider.notifier)
                    .setBiometricEnabled(value)
              : null,
        ),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.folder_special_outlined),
        title: const Text('Private Folder'),
        subtitle: Text(
          privateFolderPath ?? 'Tap to create private folder',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: _ensurePrivateFolder,
        trailing: TextButton(
          onPressed: privateFolderPath == null
              ? null
              : () => _copyPath(privateFolderPath),
          child: const Text('COPY'),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.visibility_off_outlined),
        title: const Text('Hidden Videos'),
        subtitle: Text(
          hiddenCount == 0
              ? 'No hidden videos'
              : '$hiddenCount hidden video${hiddenCount == 1 ? '' : 's'}',
        ),
        trailing: TextButton(
          onPressed: hiddenCount == 0 ? null : _clearHiddenVideos,
          child: const Text('UNHIDE ALL'),
        ),
      ),
    ];
  }

  Future<void> _handleAppLockToggle(
    bool enable,
    AppLockState appLockState,
  ) async {
    final notifier = ref.read(appLockProvider.notifier);
    if (enable) {
      if (!appLockState.hasPin) {
        final success = await _showSetPinDialog();
        if (!success) {
          notifier.refresh();
        }
      } else {
        await notifier.setEnabled(true);
        _showSnack('App Lock enabled');
      }
    } else {
      await notifier.setEnabled(false);
      _showSnack('App Lock disabled');
    }
  }

  Future<bool> _showSetPinDialog({bool isUpdate = false}) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;
    bool saving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> submit() async {
              final pin = pinController.text.trim();
              final confirm = confirmController.text.trim();
              final validPin = RegExp(r'^\d{4,6}$');
              if (!validPin.hasMatch(pin)) {
                setStateDialog(() {
                  errorText = 'PIN must be 4-6 digits';
                });
                return;
              }
              if (pin != confirm) {
                setStateDialog(() {
                  errorText = 'PINs do not match';
                });
                return;
              }
              setStateDialog(() {
                saving = true;
                errorText = null;
              });
              await ref.read(appLockProvider.notifier).setPin(pin);
              if (context.mounted) Navigator.of(context).pop(true);
            }

            return AlertDialog(
              title: Text(isUpdate ? 'Change PIN' : 'Set PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'New PIN',
                      counterText: '',
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => submit(),
                  ),
                  TextField(
                    controller: confirmController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Confirm PIN',
                      counterText: '',
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => submit(),
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isUpdate ? 'Update' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      _showSnack(isUpdate ? 'PIN updated' : 'PIN set');
      await ref.read(appLockProvider.notifier).refresh();
      return true;
    }
    return false;
  }

  Future<void> _confirmDisableAppLock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable App Lock'),
        content: const Text(
          'This will keep your PIN but stop enforcing App Lock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(appLockProvider.notifier).setEnabled(false);
      _showSnack('App Lock disabled');
    }
  }

  Future<void> _ensurePrivateFolder() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await ref.read(privacyServiceProvider).ensurePrivateFolder();
      if (!navigator.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Private folder ready: $path')),
      );
      setState(() {});
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to prepare private folder: $e')),
      );
    }
  }

  void _copyPath(String path) {
    Clipboard.setData(ClipboardData(text: path));
    _showSnack('Path copied to clipboard');
  }

  Future<void> _clearHiddenVideos() async {
    await ref.read(privacyServiceProvider).clearHiddenVideos();
    setState(() {});
    _showSnack('All hidden videos restored');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
