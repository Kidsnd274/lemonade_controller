class LemonadeModel {
  final String id;
  final String checkpoint;
  final bool downloaded;
  final List<String> labels;
  final String recipe;
  final Map<String, dynamic> recipeOptions;
  final bool suggested;
  final String ownedBy;
  final double? size;

  // Constructor
  LemonadeModel({
    required this.id,
    required this.checkpoint,
    required this.downloaded,
    required this.labels,
    required this.recipe,
    required this.recipeOptions,
    required this.suggested,
    required this.ownedBy,
    this.size,
  });

  // Factory constructor for JSON deserialization
  factory LemonadeModel.fromJson(Map<String, dynamic> json) {
    return LemonadeModel(
      id: json['id']?.toString() ?? '',
      checkpoint: json['checkpoint']?.toString() ?? '',
      downloaded: json['downloaded'] as bool? ?? false,
      labels:
          (json['labels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      recipe: json['recipe']?.toString() ?? '',
      recipeOptions:
          (json['recipe_options'] as Map?)?.cast<String, dynamic>() ?? {},
      suggested: json['suggested'] as bool? ?? false,
      ownedBy: json['ownedBy']?.toString() ?? '',
      size: (json['size'] as num?)?.toDouble(),
    );
  }

  LemonadeModel copyWith({
    String? id,
    String? checkpoint,
    bool? downloaded,
    List<String>? labels,
    String? recipe,
    Map<String, dynamic>? recipeOptions,
    bool? suggested,
    String? ownedBy,
    double? size,
  }) {
    return LemonadeModel(
      id: id ?? this.id,
      checkpoint: checkpoint ?? this.checkpoint,
      downloaded: downloaded ?? this.downloaded,
      labels: labels ?? this.labels,
      recipe: recipe ?? this.recipe,
      recipeOptions: recipeOptions ?? this.recipeOptions,
      suggested: suggested ?? this.suggested,
      ownedBy: ownedBy ?? this.ownedBy,
      size: size ?? this.size,
    );
  }

  static final _qLevelPattern = RegExp(r'Q(\d)');

  // Derived properties
  String get displayName => id.replaceFirst('user.', '');
  String get quantization =>
      checkpoint.split(":").length > 1 ? checkpoint.split(':').last : 'Unknown';
  bool get isUserModel => id.startsWith('user.');

  /// Extracts the Q-level (1–8) from quantization strings like "Q6_K" or "UD-Q5_L_XL".
  int? get quantizationLevel {
    final match = _qLevelPattern.firstMatch(quantization);
    if (match == null) return null;
    return int.parse(match.group(1)!);
  }

  @override
  String toString() => 'LemonadeModel(id: $id, checkpoint: $checkpoint)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LemonadeModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
