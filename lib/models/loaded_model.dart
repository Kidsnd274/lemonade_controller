class LoadedModel {
  final String backendUrl;
  final String checkpoint;
  final String device;
  final int lastUse;
  final String modelName;
  final String recipe;
  final Map<String, dynamic> recipeOptions;
  final String type;

  LoadedModel({
    required this.backendUrl,
    required this.checkpoint,
    required this.device,
    required this.lastUse,
    required this.modelName,
    required this.recipe,
    required this.recipeOptions,
    required this.type,
  });

  factory LoadedModel.fromJson(Map<String, dynamic> json) {
    return LoadedModel(
      backendUrl: json['backend_url']?.toString() ?? '',
      checkpoint: json['checkpoint']?.toString() ?? '',
      device: json['device']?.toString() ?? '',
      lastUse: json['last_use'] != null
          ? int.parse(json['last_use'].toString())
          : 0,
      modelName: json['model_name']?.toString() ?? '',
      recipe: json['recipe']?.toString() ?? '',
      recipeOptions:
          (json['recipe_options'] as Map?)?.cast<String, dynamic>() ?? {},
      type: json['type']?.toString() ?? '',
    );
  }

  LoadedModel copyWith({
    String? backendUrl,
    String? checkpoint,
    String? device,
    int? lastUse,
    String? modelName,
    String? recipe,
    Map<String, dynamic>? recipeOptions,
    String? type,
  }) {
    return LoadedModel(
      backendUrl: backendUrl ?? this.backendUrl,
      checkpoint: checkpoint ?? this.checkpoint,
      device: device ?? this.device,
      lastUse: lastUse ?? this.lastUse,
      modelName: modelName ?? this.modelName,
      recipe: recipe ?? this.recipe,
      recipeOptions: recipeOptions ?? this.recipeOptions,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backend_url': backendUrl,
      'checkpoint': checkpoint,
      'device': device,
      'last_use': lastUse,
      'model_name': modelName,
      'recipe': recipe,
      'recipe_options': recipeOptions,
      'type': type,
    };
  }

  @override
  String toString() {
    return 'LoadedModel(backendUrl: $backendUrl, checkpoint: $checkpoint, device: $device, lastUse: $lastUse, modelName: $modelName, recipe: $recipe, recipeOptions: $recipeOptions, type: $type)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoadedModel &&
          runtimeType == other.runtimeType &&
          modelName == other.modelName;

  @override
  int get hashCode => modelName.hashCode;
}
