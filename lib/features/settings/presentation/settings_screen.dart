import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
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
    final appLockState = ref.watch(appLockProvider);
    final privacyService = ref.watch(privacyServiceProvider);
    final hiddenCount = privacyService.getHiddenVideos().length;
    final privateFolderPath = privacyService.getPrivateFolderPath();

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
            _buildBackgroundPlayOptions(),
            const Divider(height: 1),
            _buildSwitchTile(
              title: 'Screen Off Playback',
              subtitle: 'Continue playback when screen is off',
              value: _settings.enableScreenOffPlayback,
              onChanged: (value) =>
                  _updateSetting('screen_off_playback', value),
            ),
            _buildSwitchTile(
              title: 'Auto-enter PiP',
              subtitle: 'Automatically enter PiP on home button',
              value: _settings.autoEnterPip,
              onChanged: (value) => _updateSetting('auto_enter_pip', value),
            ),
            _buildSwitchTile(
              title: 'Audio Only Mode',
              subtitle: 'Play only audio from videos',
              value: _settings.audioOnly,
              onChanged: (value) => _updateSetting('audio_only', value),
            ),
            _buildSwitchTile(
              title: 'Volume Boost',
              subtitle: 'Increase volume beyond 100%',
              value: _settings.volumeBoost,
              onChanged: (value) => _updateSetting('volume_boost', value),
            ),
            _buildSliderTile(
              title: 'Default Playback Speed',
              subtitle: '${_settings.playbackSpeed.toStringAsFixed(1)}x',
              value: _settings.playbackSpeed,
              min: 0.25,
              max: 3.0,
              divisions: 11,
              onChanged: (value) => _updateSetting('playback_speed', value),
            ),
            _buildSliderTile(
              title: 'Seek Duration',
              subtitle: '${(_settings.seekDuration / 1000).round()} seconds',
              value: _settings.seekDuration.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              onChanged: (value) =>
                  _updateSetting('seek_duration', (value * 1000).round()),
            ),
            _buildSliderTile(
              title: 'Sleep Timer',
              subtitle: _settings.sleepTimerMinutes == 0
                  ? 'Disabled'
                  : '${_settings.sleepTimerMinutes} minutes',
              value: _settings.sleepTimerMinutes.toDouble(),
              min: 0,
              max: 120,
              divisions: 24,
              onChanged: (value) =>
                  _updateSetting('sleep_timer_minutes', value.round()),
            ),
            _buildSwitchTile(
              title: 'A-B Repeat',
              subtitle: 'Enable looping between two points',
              value: _settings.enableABRepeat,
              onChanged: (value) => _updateSetting('enable_ab_repeat', value),
            ),
            _buildSwitchTile(
              title: 'Hardware Acceleration',
              subtitle: 'Use hardware for video decoding',
              value: _settings.enableHardwareAcceleration,
              onChanged: (value) =>
                  _updateSetting('hardware_acceleration', value),
            ),
          ]),

          const SizedBox(height: 24),

          _buildSection(AppStrings.gestureSettings, [
            _buildSwitchTile(
              title: 'Show Gesture Hints',
              subtitle: 'Display gesture controls overlay',
              value: _settings.showGesturesHints,
              onChanged: (value) =>
                  _updateSetting('show_gestures_hints', value),
            ),
            _buildSwitchTile(
              title: 'Auto Rotate',
              subtitle: 'Automatically rotate on fullscreen',
              value: _settings.autoRotate,
              onChanged: (value) => _updateSetting('auto_rotate', value),
            ),
            _buildSwitchTile(
              title: 'One Hand Mode',
              subtitle: 'Shift controls for easy reach',
              value: _settings.gestureOneHandMode,
              onChanged: (value) => _updateSetting('gesture_one_hand', value),
            ),
            _buildSwitchTile(
              title: 'Seek Gestures',
              subtitle: 'Swipe left/right to seek',
              value: _settings.enableGestureSeek,
              onChanged: (value) => _updateSetting('gesture_seek', value),
            ),
            _buildSwitchTile(
              title: 'Brightness Gestures',
              subtitle: 'Swipe up/down (left) to adjust brightness',
              value: _settings.enableGestureBrightness,
              onChanged: (value) => _updateSetting('gesture_brightness', value),
            ),
            _buildSwitchTile(
              title: 'Volume Gestures',
              subtitle: 'Swipe up/down (right) to adjust volume',
              value: _settings.enableGestureVolume,
              onChanged: (value) => _updateSetting('gesture_volume', value),
            ),
          ]),

          const SizedBox(height: 24),

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
                  _updateSetting('default_audio_language', value ?? 'en'),
            ),
          ]),

          const SizedBox(height: 24),

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
                  _updateSetting('default_subtitle_language', value ?? 'en'),
            ),
            _buildSliderTile(
              title: 'Subtitle Font Size',
              subtitle: '${_settings.subtitleFontSize.toStringAsFixed(0)} pt',
              value: _settings.subtitleFontSize,
              min: 10,
              max: 40,
              divisions: 30,
              onChanged: (value) => _updateSetting('subtitle_font_size', value),
            ),
            _buildSliderTile(
              title: 'Subtitle Background Opacity',
              subtitle:
                  '${(_settings.subtitleBackgroundOpacity * 100).round()}%',
              value: _settings.subtitleBackgroundOpacity,
              min: 0,
              max: 1,
              divisions: 10,
              onChanged: (value) =>
                  _updateSetting('subtitle_background_opacity', value),
            ),
          ]),

          const SizedBox(height: 24),

          _buildSection(
            AppStrings.privacySettings,
            _buildPrivacyTiles(appLockState, hiddenCount, privateFolderPath),
          ),

          const SizedBox(height: 24),

          _buildSection('System', [
            _buildSwitchTile(
              title: 'Keep Screen On',
              subtitle: 'Prevent screen from turning off during playback',
              value: _settings.keepScreenOn,
              onChanged: (value) => _updateSetting('keep_screen_on', value),
            ),
            _buildSwitchTile(
              title: 'Resume Playback',
              subtitle: 'Continue from last position next time',
              value: _settings.resumePlayback,
              onChanged: (value) => _updateSetting('resume_playback', value),
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
              subtitle: const Text(
                'A2Orbit Player - Professional Video Player',
              ),
              onTap: () {
                showLicensePage(context: context);
              },
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    await ref.read(settingsProvider.notifier).updateSetting(key, value);
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
                _updateSetting('background_play_option', value);
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
              color: AppColors.lightPrimary,
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
