import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/main_page.dart';
import 'package:lemonade_controller/services/settings_service.dart';
import 'package:lemonade_controller/theme/theme_def.dart';
import 'package:logger/logger.dart';

void main() {
  Logger.level = Level.debug;
  runApp(ProviderScope(child: LemonadeController()));
}

class LemonadeController extends ConsumerWidget {
  const LemonadeController({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => MaterialApp(
        theme: lightTheme,
        darkTheme: darkTheme,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, st) => MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Failed to load settings: $e')),
        ),
      ),
      data: (settings) => MaterialApp(
        title: 'Lemonade Controller',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: settings.themeMode,
        home: const MainPage(),
      ),
    );
  }
}
