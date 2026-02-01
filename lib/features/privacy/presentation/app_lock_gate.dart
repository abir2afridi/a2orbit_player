import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';

class AppLockGate extends ConsumerWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLockState = ref.watch(appLockProvider);

    if (appLockState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!appLockState.isEnabled || appLockState.isUnlocked) {
      return child;
    }

    return const _AppLockPrompt();
  }
}

class _AppLockPrompt extends ConsumerStatefulWidget {
  const _AppLockPrompt();

  @override
  ConsumerState<_AppLockPrompt> createState() => _AppLockPromptState();
}

class _AppLockPromptState extends ConsumerState<_AppLockPrompt> {
  final TextEditingController _pinController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _unlockWithPin() async {
    if (_pinController.text.isEmpty) return;
    setState(() => _isSubmitting = true);
    final success = await ref
        .read(appLockProvider.notifier)
        .unlockWithPin(_pinController.text.trim());
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (!success) {
      _pinController.clear();
    }
  }

  Future<void> _unlockWithBiometrics() async {
    setState(() => _isSubmitting = true);
    await ref.read(appLockProvider.notifier).unlockWithBiometric();
    if (!mounted) return;
    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appLockState = ref.watch(appLockProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Icon(Icons.lock_outline,
                        size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'App Locked',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your PIN to continue using A2Orbit Player.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      obscureText: true,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'PIN',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _unlockWithPin(),
                    ),
                    const SizedBox(height: 16),
                    if (appLockState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          appLockState.errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    FilledButton(
                      onPressed:
                          _isSubmitting ? null : () => _unlockWithPin(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Unlock'),
                    ),
                    if (appLockState.biometricEnabled) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => _unlockWithBiometrics(),
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Use Biometrics'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'For security, App Lock must be disabled from settings after authentication.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
