import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:lemonade_controller/models/health_info.dart';
import 'package:lemonade_controller/models/lemonade_load_options.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/models/lemonade_unload_options.dart';
import 'package:lemonade_controller/models/loaded_model.dart';
import 'package:lemonade_controller/models/model_load_preset.dart';
import 'package:lemonade_controller/models/pull_progress_event.dart';
import 'package:lemonade_controller/models/pull_request_options.dart';
import 'package:lemonade_controller/models/system_info.dart';
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

  Future<bool> loadModel(
    String modelId, {
    LemonadeLoadOptionsModel? options,
  }) async {
    state = {...state, modelId};
    try {
      final opts = options ?? LemonadeLoadOptionsModel(modelName: modelId);
      final result = await _apiClient.loadModel(opts);
      if (result) {
        await _ref.read(loadedModelsProvider.notifier).updateState();
        _ref.invalidate(healthInfoProvider);
      }
      return result;
    } finally {
      state = {...state}..remove(modelId);
    }
  }

  Future<bool> unloadModel(String modelId) async {
    state = {...state, modelId};
    try {
      final options = LemonadeUnloadOptionsModel(modelName: modelId);
      final result = await _apiClient.unloadModel(options);
      if (result) {
        await _ref.read(loadedModelsProvider.notifier).updateState();
        _ref.invalidate(healthInfoProvider);
      }
      return result;
    } finally {
      state = {...state}..remove(modelId);
    }
  }

  Future<bool> deleteModel(String modelId) async {
    state = {...state, modelId};
    try {
      final result = await _apiClient.deleteModel(modelId);
      if (result) {
        await _ref.read(loadedModelsProvider.notifier).updateState();
        _ref.invalidate(modelsProvider);
        _ref.invalidate(healthInfoProvider);
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

  LoadedModelsNotifier(this._apiClient) : super({}) {
    updateState();
  }

  Future updateState() async {
    final loadedList = await _apiClient.getLoadedModels();
    state = loadedList.toSet();
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

final systemInfoProvider = FutureProvider<SystemInfo>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getSystemInfo();
  return SystemInfo.fromJson(json);
});

final healthInfoProvider = FutureProvider<HealthInfo>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.getHealth();
  return HealthInfo.fromJson(json);
});

final presetLoadingProvider =
    StateNotifierProvider<PresetLoadingNotifier, Set<String>>((ref) {
      return PresetLoadingNotifier(ref);
    });

class PresetLoadingNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;

  PresetLoadingNotifier(this._ref) : super({});

  /// Loads all models in a preset sequentially via [LoadingModelsNotifier]
  /// so each model appears in the per-model loading state.
  /// Returns the number of models that loaded successfully.
  Future<int> loadPreset(ModelLoadPreset preset) async {
    state = {...state, preset.id};
    try {
      final loader = _ref.read(loadingModelsProvider.notifier);
      final results = await Future.wait(
        preset.entries.map((entry) async {
          final opts = entry.copyWith(saveOptions: null);
          try {
            return await loader.loadModel(entry.modelName, options: opts);
          } catch (_) {
            // Continue loading other models even if one fails.
            return false;
          }
        }),
      );
      return results.where((success) => success).length;
    } finally {
      state = {...state}..remove(preset.id);
    }
  }
}

final isPresetLoadingProvider =
    Provider.family<bool, String>((ref, presetId) {
  return ref.watch(
    presetLoadingProvider.select((state) => state.contains(presetId)),
  );
});

// ---------------------------------------------------------------------------
// Pull (download) progress
// ---------------------------------------------------------------------------

final pullProgressProvider = StateNotifierProvider<PullProgressNotifier,
    Map<String, PullProgressEvent>>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PullProgressNotifier(apiClient, ref);
});

class PullProgressNotifier
    extends StateNotifier<Map<String, PullProgressEvent>> {
  final LemonadeApiClient _apiClient;
  final Ref _ref;
  final Map<String, _SpeedTracker> _speedTrackers = {};

  PullProgressNotifier(this._apiClient, this._ref) : super({});

  Future<void> startPull(PullRequestOptions options) async {
    final modelName = options.modelName;

    _speedTrackers[modelName] = _SpeedTracker();
    state = {
      ...state,
      modelName: const PullProgressEvent(
        eventType: PullEventType.progress,
        percent: 0,
      ),
    };

    try {
      await for (final event in _apiClient.pullModel(options)) {
        if (!mounted) return;

        final enriched = _enrichWithSpeed(modelName, event);
        state = {...state, modelName: enriched};

        if (event.isComplete) {
          _speedTrackers.remove(modelName);
          _ref.invalidate(modelsProvider);
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) {
            state = Map.from(state)..remove(modelName);
          }
          return;
        }

        if (event.isError) {
          _speedTrackers.remove(modelName);
          await Future.delayed(const Duration(seconds: 5));
          if (mounted) {
            state = Map.from(state)..remove(modelName);
          }
          return;
        }
      }
    } catch (_) {
      _speedTrackers.remove(modelName);
      if (mounted) {
        state = Map.from(state)..remove(modelName);
      }
    }
  }

  PullProgressEvent _enrichWithSpeed(String modelName, PullProgressEvent event) {
    final tracker = _speedTrackers[modelName];
    if (tracker == null || event.bytesDownloaded == null) return event;
    final speed = tracker.update(event.bytesDownloaded!);
    return event.withSpeed(speed);
  }
}

class _SpeedTracker {
  int _prevBytes = 0;
  DateTime _prevTime = DateTime.now();
  double _smoothedSpeed = 0;

  /// Returns smoothed speed in bytes/sec using exponential moving average.
  double? update(int currentBytes) {
    final now = DateTime.now();
    final elapsed = now.difference(_prevTime);
    if (elapsed.inMilliseconds < 200) return _smoothedSpeed > 0 ? _smoothedSpeed : null;

    final deltaBytes = currentBytes - _prevBytes;
    if (deltaBytes <= 0) return _smoothedSpeed > 0 ? _smoothedSpeed : null;

    final instantSpeed = deltaBytes / (elapsed.inMilliseconds / 1000.0);
    // Exponential moving average (alpha=0.3) for smoother display
    _smoothedSpeed = _smoothedSpeed == 0
        ? instantSpeed
        : _smoothedSpeed * 0.7 + instantSpeed * 0.3;

    _prevBytes = currentBytes;
    _prevTime = now;
    return _smoothedSpeed;
  }
}
