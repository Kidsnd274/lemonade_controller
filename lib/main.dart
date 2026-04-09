import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/main_page.dart';
import 'package:lemonade_controller/providers/service_providers.dart';
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
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Lemonade Controller',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: const MainPage(),
    );
  }
}
