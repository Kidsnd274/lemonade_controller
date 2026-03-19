import 'package:flutter/material.dart';
import 'package:lemonade_controller/pages/home/widgets/loaded_models_list.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Loaded Models',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Expanded(child: LoadedModelsList()),
      ],
    );
  }
}
