import 'package:flutter/material.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/services/api_client.dart';
import 'package:lemonade_controller/pages/models/widgets/model_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String result = "empty";
  final LemonadeApiClient apiClient = LemonadeApiClient();

  List<LemonadeModel> modelList = [];

  void _getResult() async {
    setState(() {
      result = "retrieving...";
    });

    try {
      final dynamic response = await apiClient.getModelsList();

      if (response is! List) {
        throw Exception("Expected a list of models");
      }

      modelList = response.map((json) => LemonadeModel.fromJson(json)).toList();

      setState(() {
        result = "Loaded ${modelList.length} models";
      });
    } catch (e) {
      setState(() {
        result = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: ListView(
          children: [
            if (modelList.isEmpty)
              Text(result, style: Theme.of(context).textTheme.headlineMedium)
            else
              for (int i = 0; i < modelList.length; i++)
                ModelCard(model: modelList[i]),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getResult,
        child: const Icon(Icons.add),
      ),
    );
  }
}
