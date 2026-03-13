import 'package:flutter/material.dart';
import 'package:lemonade_controller/screens/home/home_page.dart';

void main() {
  runApp(const LemonadeController());
}

class LemonadeController extends StatelessWidget {
  const LemonadeController({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lemonade Controller',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.blue)
      ),
      home: const HomePage(title: 'Home'),
    );
  }
}