import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/services/api_client.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String result = "empty";
  final Dio dio = Dio();
  final LemonadeApiClient apiClient = LemonadeApiClient();

  List<LemonadeModel> modelList = [];

  void _getResult() async {
    setState(() {
      result = "retrieving...";
    });

    List<LemonadeModel> modelList = [];
    try {
      final dynamic response = await apiClient.getModelsList();

      if (response is! List) {
        throw Exception("Expected a list of models");
      }

      for (var i = 0; i < response.length; i++) {
        final item = response[i];
        // if (item == null) continue;
        // final Map<String, dynamic> json = item;
        // final LemonadeModel model = LemonadeModel.fromJson(json);
        // modelList.add(model);
        if (item is! Map<String, dynamic>) continue;
        final LemonadeModel model = LemonadeModel.fromJson(item);
        modelList.add(model);
      }

      setState(() {
        result =
            "Loaded ${modelList.length} models \n  Name: ${modelList[0].displayName}\n  Checkpoint: ${modelList[0].checkpoint}";
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
        child: Column(
          mainAxisAlignment: .center,
          children: [
            Text(result, style: Theme.of(context).textTheme.headlineMedium),
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
