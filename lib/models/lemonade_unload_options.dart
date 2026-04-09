class LemonadeUnloadOptionsModel {
  final String modelName;

  LemonadeUnloadOptionsModel({
    required this.modelName,
  });

  LemonadeUnloadOptionsModel copyWith({
    String? modelName,
  }) {
    return LemonadeUnloadOptionsModel(
      modelName: modelName ?? this.modelName,
    );
  }

  // Factory constructor for JSON deserialization
  factory LemonadeUnloadOptionsModel.fromJson(Map<String, dynamic> json) {
    return LemonadeUnloadOptionsModel(
      modelName: json['model_name']?.toString() ?? '',
    );
  }

  // Converts model to JSON map
  Map<String, dynamic> toJson() {
    return {
      'model_name': modelName,
    };
  }

  @override
  String toString() {
    return 'LemonadeUnloadOptionsModel(modelName: $modelName)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LemonadeUnloadOptionsModel &&
          runtimeType == other.runtimeType &&
          modelName == other.modelName;

  @override
  int get hashCode => modelName.hashCode;
}
