import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/ui/screens/home_screen.dart';
import 'features/ui/screens/player_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  // final sharedPreferences = await SharedPreferences.getInstance();

  runApp(const ProviderScope(child: A2OrbitPlayer()));
}

class A2OrbitPlayer extends ConsumerWidget {
  const A2OrbitPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final themeData = ref.watch(themeProvider);

    return MaterialApp(
      title: 'A2Orbit Player',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Will be updated with provider later
      home: const HomeScreen(),
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
