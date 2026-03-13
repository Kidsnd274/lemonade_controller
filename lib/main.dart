import 'package:flutter/material.dart';
import 'package:lemonade_controller/pages/main_page.dart';
import 'package:lemonade_controller/services/settings_service.dart';
import 'package:logger/logger.dart';

void main() {
  // setupLogging();

  // Set the desired log level
  Logger.level = Level.debug;

  runApp(LemonadeController());
}

class LemonadeController extends StatelessWidget {
  final SettingsService settings;

  LemonadeController({super.key}) : settings = SettingsService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lemonade Controller',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.blue)),
      home: MainPage(settings: settings),
    );
  }
}
