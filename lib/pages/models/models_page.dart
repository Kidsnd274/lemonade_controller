import 'package:flutter/material.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/services/api_client.dart';
import 'package:lemonade_controller/pages/models/widgets/model_card.dart';

class ModelsPage extends StatefulWidget {
  const ModelsPage({super.key});

  @override
  State<ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends State<ModelsPage> {
  String result = "empty";
  final LemonadeApiClient apiClient = LemonadeApiClient();

  List<LemonadeModel> modelList = [];

  void loadModels() async {
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
    return Stack(
      children: [
        Center(
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
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: loadModels,
            child: const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }
}
