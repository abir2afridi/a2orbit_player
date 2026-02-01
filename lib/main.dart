import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/privacy/presentation/app_lock_gate.dart';
import 'features/ui/screens/home_screen.dart';
import 'features/ui/screens/player_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const A2OrbitPlayer(),
    ),
  );
}

class A2OrbitPlayer extends ConsumerWidget {
  const A2OrbitPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = ref.watch(themeProvider);

    return MaterialApp(
      title: 'A2Orbit Player',
      theme: AppTheme.light(themeData),
      darkTheme: themeData.useAmoled
          ? AppTheme.amoled(themeData)
          : AppTheme.dark(themeData),
      themeMode: themeData.themeMode,
      home: const AppLockGate(child: HomeScreen()),
      routes: {
        '/player': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is String) {
            return PlayerScreen(videoPath: args);
          }
          return const Scaffold(
            body: Center(child: Text('Invalid video path')),
          );
        },
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
