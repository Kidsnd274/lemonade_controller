import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/main_page.dart';
import 'package:lemonade_controller/services/settings_service.dart';
import 'package:logger/logger.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  // setupLogging();

  // Set the desired log level
  Logger.level = Level.debug;

  runApp(ProviderScope(child: LemonadeController()));
}

class LemonadeController extends StatelessWidget {
  final SettingsService settings;

  LemonadeController({super.key}) : settings = SettingsService();

  @override
  Widget build(BuildContext context) {
    return ShadApp.custom(
      themeMode: ThemeMode.dark,
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadSlateColorScheme.dark(),
      ),
      appBuilder: (context) {
        return MaterialApp(
          title: 'Lemonade Controller',
          theme: Theme.of(context),
          builder: (context, child) {
            return ShadAppBuilder(child: child!);
          },
          home: MainPage(settings: settings),
        );
      },
    );
    // return MaterialApp(
    //   title: 'Lemonade Controller',
    //   theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.blue)),
    //   home: MainPage(settings: settings),
    // );
  }
}
