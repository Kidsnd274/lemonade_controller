import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String result = "empty";
  final Dio dio = Dio();

  void _getResult() async {
    setState(() {
      result = "retrieving...";
    });

    final response = await dio.get('http://192.168.1.7:8020/api/v1/models');

    setState(() {
      result = response.toString();
    });
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
          ]
        )
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getResult,
        child: const Icon(Icons.add),
      ),
    );
  }
}