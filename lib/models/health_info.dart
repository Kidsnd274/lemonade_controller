import 'package:lemonade_controller/models/loaded_model.dart';

class HealthInfo {
  final String status;
  final String version;
  final int websocketPort;
  final String? activeModel;
  final Map<String, int> maxModels;
  final List<LoadedModel> allModelsLoaded;
  final Map<String, int> pinnedModels;
  final bool updateCheckDone;

  const HealthInfo({
    required this.status,
    required this.version,
    required this.websocketPort,
    this.activeModel,
    this.maxModels = const {},
    this.allModelsLoaded = const [],
    this.pinnedModels = const {},
    this.updateCheckDone = false,
  });

  factory HealthInfo.fromJson(Map<String, dynamic> json) {
    final maxModelsJson =
        (json['max_models'] as Map?)?.cast<String, dynamic>() ?? {};
    final modelsList = json['all_models_loaded'] as List? ?? [];
    final pinnedJson =
        (json['pinned_models'] as Map?)?.cast<String, dynamic>() ?? {};

    return HealthInfo(
      status: json['status']?.toString() ?? 'unknown',
      version: json['version']?.toString() ?? '',
      websocketPort: (json['websocket_port'] as num?)?.toInt() ?? 0,
      activeModel: json['model_loaded']?.toString(),
      maxModels: maxModelsJson.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      allModelsLoaded: modelsList
          .map((e) => LoadedModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      pinnedModels: pinnedJson.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      updateCheckDone: json['update_check_done'] as bool? ?? false,
    );
  }

  bool get isHealthy => status == 'ok';

  bool get isOlderThanRecommended {
    final values = version.split('.').take(2).map(int.tryParse).toList();
    if (values.length < 2 || values.any((value) => value == null)) return false;
    final major = values[0]!;
    final minor = values[1]!;
    return major < 10 || (major == 10 && minor < 10);
  }

  /// Count loaded models by type.
  Map<String, int> get loadedCountByType {
    final counts = <String, int>{};
    for (final model in allModelsLoaded) {
      counts[model.type] = (counts[model.type] ?? 0) + 1;
    }
    return counts;
  }
}
