import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/providers/service_providers.dart';

final modelsProvider = FutureProvider<List<LemonadeModel>>((ref) async {
  List<LemonadeModel> modelList = [];
  final apiClient = ref.watch(apiClientProvider);
  final dynamic response = await apiClient.getModelsList();

  if (response is! List) {
    throw Exception("Expected a list of models");
  }

  modelList = response.map((json) => LemonadeModel.fromJson(json)).toList();
  return modelList;
});
