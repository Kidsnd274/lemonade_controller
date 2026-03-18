class LemonadeLoadOptionsModel {
  final String modelName;
  final bool? saveOptions;
  final int? ctxSize;
  final String? llamacppBackend;
  final String? llamacppArgs;
  final String? whispercppBackend;
  final String? whispercppArgs;
  final String? steps;
  final String? width;
  final String? height;

  LemonadeLoadOptionsModel({
    required this.modelName,
    this.saveOptions,
    this.ctxSize,
    this.llamacppBackend,
    this.llamacppArgs,
    this.whispercppBackend,
    this.whispercppArgs,
    this.steps,
    this.width,
    this.height,
  });

  LemonadeLoadOptionsModel copyWith({
    String? modelName,
    bool? saveOptions,
    int? ctxSize,
    String? llamacppBackend,
    String? llamacppArgs,
    String? whispercppBackend,
    String? whispercppArgs,
    String? steps,
    String? width,
    String? height,
  }) {
    return LemonadeLoadOptionsModel(
      modelName: modelName ?? this.modelName,
      saveOptions: saveOptions ?? this.saveOptions,
      ctxSize: ctxSize ?? this.ctxSize,
      llamacppBackend: llamacppBackend ?? this.llamacppBackend,
      llamacppArgs: llamacppArgs ?? this.llamacppArgs,
      whispercppBackend: whispercppBackend ?? this.whispercppBackend,
      whispercppArgs: whispercppArgs ?? this.whispercppArgs,
      steps: steps ?? this.steps,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  // Factory constructor for JSON deserialization
  factory LemonadeLoadOptionsModel.fromJson(Map<String, dynamic> json) {
    return LemonadeLoadOptionsModel(
      modelName: json['model_name']?.toString() ?? '',
      saveOptions: json['save_options'] as bool?,
      ctxSize: json['ctx_size'] != null
          ? int.parse(json['ctx_size'].toString())
          : null,
      llamacppBackend: json['llamacpp_backend']?.toString(),
      llamacppArgs: json['llamacpp_args']?.toString(),
      whispercppBackend: json['whispercpp_backend']?.toString(),
      whispercppArgs: json['whispercpp_args']?.toString(),
      steps: json['steps']?.toString(),
      width: json['width']?.toString(),
      height: json['height']?.toString(),
    );
  }

  // Converts model to JSON map
  Map<String, dynamic> toJson() {
    return {
      'model_name': modelName,
      if (saveOptions != null) 'save_options': saveOptions,
      if (ctxSize != null) 'ctx_size': ctxSize,
      if (llamacppBackend != null) 'llamacpp_backend': llamacppBackend,
      if (llamacppArgs != null) 'llamacpp_args': llamacppArgs,
      if (whispercppBackend != null) 'whispercpp_backend': whispercppBackend,
      if (whispercppArgs != null) 'whispercpp_args': whispercppArgs,
      if (steps != null) 'steps': steps,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
    };
  }

  @override
  String toString() {
    return 'LemonadeLoadOptionsModel(modelName: $modelName, saveOptions: $saveOptions, ctxSize: $ctxSize, llamacppBackend: $llamacppBackend, llamacppArgs: $llamacppArgs, whispercppBackend: $whispercppBackend, whispercppArgs: $whispercppArgs, steps: $steps, width: $width, height: $height)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LemonadeLoadOptionsModel &&
          runtimeType == other.runtimeType &&
          modelName == other.modelName;

  @override
  int get hashCode => modelName.hashCode;
}
