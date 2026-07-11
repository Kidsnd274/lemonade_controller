import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:lemonade_controller/models/api_error.dart';
import 'package:lemonade_controller/models/download_job.dart';
import 'package:lemonade_controller/models/health_info.dart';
import 'package:lemonade_controller/models/lemonade_load_options.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/models/lemonade_unload_options.dart';
import 'package:lemonade_controller/models/loaded_model.dart';
import 'package:lemonade_controller/models/model_load_preset.dart';
import 'package:lemonade_controller/models/model_files.dart';
import 'package:lemonade_controller/models/pull_request_options.dart';
import 'package:lemonade_controller/models/request_stats.dart';
import 'package:lemonade_controller/models/server_profile.dart';
import 'package:lemonade_controller/models/system_stats.dart';
import 'package:lemonade_controller/models/system_info.dart';
import 'package:lemonade_controller/providers/service_providers.dart';
import 'package:lemonade_controller/services/api_client.dart';
import 'package:lemonade_controller/services/settings_service.dart';

final modelsProvider = FutureProvider<List<LemonadeModel>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.getModelsList();
  return response.map((json) => LemonadeModel.fromJson(json)).toList();
});

/// Session-only record of endpoints an individual server does not expose.
final endpointCapabilitiesProvider =
    StateNotifierProvider<EndpointCapabilitiesNotifier, Map<String, bool>>(
      (ref) => EndpointCapabilitiesNotifier(),
    );

class EndpointCapabilitiesNotifier extends StateNotifier<Map<String, bool>> {
  EndpointCapabilitiesNotifier() : super(const {});

  void markUnsupported(ServerProfile profile, String endpoint) {
    state = {...state, '${profile.id}:$endpoint': false};
  }

  void clearProfile(ServerProfile profile) {
    state = {
      for (final entry in state.entries)
        if (!entry.key.startsWith('${profile.id}:')) entry.key: entry.value,
    };
  }
}

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
        _ref.invalidate(modelsProvider);
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
    loadedModelsProvider.select(
      (state) => state.any((m) => m.modelName == modelId),
    ),
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

final modelFilesProvider = FutureProvider.autoDispose
    .family<ModelFiles, String>((ref, modelId) async {
      try {
        return await ref.watch(apiClientProvider).getModelFiles(modelId);
      } on LemonadeApiException catch (error) {
        if (error.isUnsupported) {
          ref
              .read(endpointCapabilitiesProvider.notifier)
              .markUnsupported(
                ref.read(activeServerProfileProvider),
                'model-files',
              );
        }
        rethrow;
      }
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

final isPresetLoadingProvider = Provider.family<bool, String>((ref, presetId) {
  return ref.watch(
    presetLoadingProvider.select((state) => state.contains(presetId)),
  );
});

class DownloadsState {
  final List<DownloadJob> jobs;
  final bool loading;
  final String? error;
  final bool unsupported;

  const DownloadsState({
    this.jobs = const [],
    this.loading = false,
    this.error,
    this.unsupported = false,
  });

  DownloadsState copyWith({
    List<DownloadJob>? jobs,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? unsupported,
  }) => DownloadsState(
    jobs: jobs ?? this.jobs,
    loading: loading ?? this.loading,
    error: clearError ? null : error ?? this.error,
    unsupported: unsupported ?? this.unsupported,
  );
}

final downloadsProvider =
    StateNotifierProvider.autoDispose<DownloadsNotifier, DownloadsState>((ref) {
      return DownloadsNotifier(
        ref.watch(apiClientProvider),
        ref,
        enabled: ref.watch(appForegroundProvider),
      );
    });

class DownloadsNotifier extends StateNotifier<DownloadsState> {
  final LemonadeApiClient _api;
  final Ref _ref;
  final Map<String, ({int bytes, DateTime time, double speed})> _speeds = {};
  Timer? _timer;
  bool _fetching = false;

  DownloadsNotifier(this._api, this._ref, {required bool enabled})
    : super(const DownloadsState(loading: true)) {
    if (enabled) refresh();
  }

  Future<void> refresh() async {
    if (_fetching || state.unsupported) return;
    _fetching = true;
    try {
      final raw = await _api.getDownloads();
      if (!mounted) return;
      final jobs = raw.map(_withSpeed).toList();
      final completedBefore = state.jobs
          .where((job) => job.complete)
          .map((job) => job.id)
          .toSet();
      state = state.copyWith(jobs: jobs, loading: false, clearError: true);
      if (jobs.any(
        (job) => job.complete && !completedBefore.contains(job.id),
      )) {
        _ref.invalidate(modelsProvider);
      }
    } on LemonadeApiException catch (error) {
      if (!mounted) return;
      if (error.isUnsupported) {
        _ref
            .read(endpointCapabilitiesProvider.notifier)
            .markUnsupported(
              _ref.read(activeServerProfileProvider),
              'downloads',
            );
      }
      state = state.copyWith(
        loading: false,
        error: error.message,
        unsupported: error.isUnsupported,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(loading: false, error: error.toString());
    } finally {
      _fetching = false;
      // Always re-arm polling (unless disposed or the endpoint is genuinely
      // unsupported) so a transient error doesn't permanently halt refresh.
      if (mounted && !state.unsupported) _schedule();
    }
  }

  DownloadJob _withSpeed(DownloadJob job) {
    final now = DateTime.now();
    final previous = _speeds[job.id];
    var speed = previous?.speed ?? 0;
    if (previous != null) {
      final seconds = now.difference(previous.time).inMilliseconds / 1000;
      final delta = job.cumulativeBytesDownloaded - previous.bytes;
      if (seconds > 0 && delta > 0) {
        final instant = delta / seconds;
        speed = speed == 0 ? instant : speed * .7 + instant * .3;
      }
    }
    _speeds[job.id] = (
      bytes: job.cumulativeBytesDownloaded,
      time: now,
      speed: speed,
    );
    return job.copyWith(speedBytesPerSecond: speed > 0 ? speed : null);
  }

  void _schedule() {
    _timer?.cancel();
    final delay = state.jobs.any((job) => job.running)
        ? const Duration(seconds: 2)
        : const Duration(seconds: 10);
    _timer = Timer(delay, refresh);
  }

  Future<void> startPull(PullRequestOptions options) async {
    final job = await _api.startPull(options);
    state = state.copyWith(
      jobs: [job, ...state.jobs.where((existing) => existing.id != job.id)],
    );
    _schedule();
  }

  Future<void> updateModel(String modelName) async {
    final job = await _api.resumePull(modelName);
    state = state.copyWith(
      jobs: [job, ...state.jobs.where((existing) => existing.id != job.id)],
    );
    _schedule();
  }

  Future<void> control(DownloadJob job, String action) async {
    await _api.controlDownload(job.id, action);
    await refresh();
  }

  Future<void> resume(DownloadJob job) async {
    await _api.resumePull(job.modelName);
    await refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class PerformanceState {
  final List<SystemStatsSample> samples;
  final RequestStats? requestStats;
  final String? systemError;
  final String? requestError;
  final bool systemUnsupported;
  final bool requestUnsupported;
  final bool loading;

  const PerformanceState({
    this.samples = const [],
    this.requestStats,
    this.systemError,
    this.requestError,
    this.systemUnsupported = false,
    this.requestUnsupported = false,
    this.loading = true,
  });

  SystemStats? get latest => samples.isEmpty ? null : samples.last.stats;
}

final performanceProvider =
    StateNotifierProvider.autoDispose<PerformanceNotifier, PerformanceState>((
      ref,
    ) {
      final seconds =
          ref.watch(settingsProvider).value?.performanceSampleIntervalSeconds ??
          AppSettings.defaultPerformanceSampleIntervalSeconds;
      return PerformanceNotifier(
        ref.watch(apiClientProvider),
        seconds,
        ref,
        enabled: ref.watch(appForegroundProvider),
      );
    });

class PerformanceNotifier extends StateNotifier<PerformanceState> {
  final LemonadeApiClient _api;
  final int intervalSeconds;
  final Ref _ref;
  Timer? _timer;
  bool _fetching = false;

  PerformanceNotifier(
    this._api,
    this.intervalSeconds,
    this._ref, {
    required bool enabled,
  }) : super(const PerformanceState()) {
    if (enabled) refresh();
  }

  Future<void> refresh() async {
    if (_fetching) return;
    _fetching = true;
    var systemError = state.systemError;
    var requestError = state.requestError;
    var systemUnsupported = state.systemUnsupported;
    var requestUnsupported = state.requestUnsupported;
    var samples = state.samples;
    var requestStats = state.requestStats;
    if (!systemUnsupported) {
      try {
        final stats = await _api.getSystemStats();
        final now = DateTime.now();
        samples = [...samples, SystemStatsSample(timestamp: now, stats: stats)]
            .where(
              (sample) =>
                  now.difference(sample.timestamp) < performanceHistoryDuration,
            )
            .toList();
        systemError = null;
      } on LemonadeApiException catch (error) {
        systemError = error.message;
        systemUnsupported = error.isUnsupported;
        if (error.isUnsupported) {
          _ref
              .read(endpointCapabilitiesProvider.notifier)
              .markUnsupported(
                _ref.read(activeServerProfileProvider),
                'system-stats',
              );
        }
      } catch (error) {
        systemError = error.toString();
      }
    }
    if (!requestUnsupported) {
      try {
        requestStats = await _api.getRequestStats();
        requestError = null;
      } on LemonadeApiException catch (error) {
        requestError = error.message;
        requestUnsupported = error.isUnsupported;
        if (error.isUnsupported) {
          _ref
              .read(endpointCapabilitiesProvider.notifier)
              .markUnsupported(
                _ref.read(activeServerProfileProvider),
                'request-stats',
              );
        }
      } catch (error) {
        requestError = error.toString();
      }
    }
    _fetching = false;
    // Bail if the notifier was disposed while awaiting, otherwise assigning
    // state throws a use-after-dispose error and leaks a rescheduled timer.
    if (!mounted) return;
    state = PerformanceState(
      samples: samples,
      requestStats: requestStats,
      systemError: systemError,
      requestError: requestError,
      systemUnsupported: systemUnsupported,
      requestUnsupported: requestUnsupported,
      loading: false,
    );
    _timer?.cancel();
    _timer = Timer(
      Duration(seconds: intervalSeconds.clamp(2, 3600).toInt()),
      refresh,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
