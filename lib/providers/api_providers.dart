import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'dart:async';
import 'package:lemonade_controller/models/lemonade_load_options.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/models/loaded_model.dart';
import 'package:lemonade_controller/providers/service_providers.dart';
import 'package:lemonade_controller/services/api_client.dart';

final modelsProvider = FutureProvider<List<LemonadeModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.getModelsList();
  return response.map((json) => LemonadeModel.fromJson(json)).toList();
});

final loadingModelsProvider =
    StateNotifierProvider<LoadingModelsNotifier, Set<String>>((ref) {
      final apiClient = ref.watch(apiClientProvider);
      return LoadingModelsNotifier(apiClient, ref);
    });

class LoadingModelsNotifier extends StateNotifier<Set<String>> {
  final LemonadeApiClient _apiClient;
  final Ref _ref;

  LoadingModelsNotifier(this._apiClient, this._ref) : super({});

  Future<bool> loadModel(String modelId) async {
    state = {...state, modelId};
    try {
      final options = LemonadeLoadOptionsModel(modelName: modelId);
      final result = await _apiClient.loadModel(options);
      if (result) {
        await _ref.read(loadedModelsProvider.notifier).updateState();
      }
      return result;
    } finally {
      state = {...state}..remove(modelId);
    }
  }
}

final loadedModelsProvider =
    StateNotifierProvider<LoadedModelsNotifier, Set<LoadedModel>>((ref) {
      final apiClient = ref.watch(apiClientProvider);
      return LoadedModelsNotifier(apiClient);
    });

class LoadedModelsNotifier extends StateNotifier<Set<LoadedModel>> {
  final LemonadeApiClient _apiClient;
  Timer? _timer;

  LoadedModelsNotifier(this._apiClient) : super({}) {
    updateState(); // Temporary
    // _startPeriodicRefresh();
  }

  Future updateState() async {
    final loadedList = await _apiClient.getLoadedModels();
    state = loadedList.toSet();
  }

  void _startPeriodicRefresh() {
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => updateState());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final isModelLoadingProvider = Provider.family<bool, String>((ref, modelId) {
  return ref.watch(
    loadingModelsProvider.select((state) => state.contains(modelId)),
  );
});

final isModelLoadedProvider = Provider.family<bool, String>((ref, modelId) {
  return ref.watch(
    loadedModelsProvider
        .select((state) => state.any((m) => m.modelName == modelId)),
  );
});
