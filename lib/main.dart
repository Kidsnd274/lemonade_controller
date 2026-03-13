import 'package:flutter/material.dart';
import 'package:lemonade_controller/screens/home/home_page.dart';
import 'package:logging/logging.dart';

void main() {
  setupLogging();

  // Set the desired log level
  Logger.root.level = Level.FINE;

  runApp(const LemonadeController());
}

void setupLogging() {
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      print('Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      print('Stack Trace: ${record.stackTrace}');
    }
  });
}

class LemonadeController extends StatelessWidget {
  const LemonadeController({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lemonade Controller',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.blue)),
      home: const HomePage(title: 'Home'),
    );
  }
}
