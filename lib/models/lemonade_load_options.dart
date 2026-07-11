class LemonadeLoadOptionsModel {
  final String modelName;
  final bool? saveOptions;
  final int? ctxSize;
  final String? llamacppBackend;
  final String? llamacppArgs;
  final String? whispercppBackend;
  final String? whispercppArgs;
  final int? steps;
  final int? width;
  final int? height;
  final double? cfgScale;
  final bool? pinned;
  final bool? mergeArgs;
  final bool? autoEvict;
  final int? downsizeIdleTimeout;
  final int? evictIdleTimeout;
  final double? evictWeightFactor;

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
    this.cfgScale,
    this.pinned,
    this.mergeArgs,
    this.autoEvict,
    this.downsizeIdleTimeout,
    this.evictIdleTimeout,
    this.evictWeightFactor,
  });

  LemonadeLoadOptionsModel copyWith({
    String? modelName,
    bool? saveOptions,
    int? ctxSize,
    String? llamacppBackend,
    String? llamacppArgs,
    String? whispercppBackend,
    String? whispercppArgs,
    int? steps,
    int? width,
    int? height,
    double? cfgScale,
    bool? pinned,
    bool? mergeArgs,
    bool? autoEvict,
    int? downsizeIdleTimeout,
    int? evictIdleTimeout,
    double? evictWeightFactor,
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
      cfgScale: cfgScale ?? this.cfgScale,
      pinned: pinned ?? this.pinned,
      mergeArgs: mergeArgs ?? this.mergeArgs,
      autoEvict: autoEvict ?? this.autoEvict,
      downsizeIdleTimeout: downsizeIdleTimeout ?? this.downsizeIdleTimeout,
      evictIdleTimeout: evictIdleTimeout ?? this.evictIdleTimeout,
      evictWeightFactor: evictWeightFactor ?? this.evictWeightFactor,
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
      steps:
          (json['steps'] as num?)?.toInt() ??
          int.tryParse(json['steps']?.toString() ?? ''),
      width:
          (json['width'] as num?)?.toInt() ??
          int.tryParse(json['width']?.toString() ?? ''),
      height:
          (json['height'] as num?)?.toInt() ??
          int.tryParse(json['height']?.toString() ?? ''),
      cfgScale: (json['cfg_scale'] as num?)?.toDouble(),
      pinned: json['pinned'] as bool?,
      mergeArgs: json['merge_args'] as bool?,
      autoEvict: json['auto_evict'] as bool?,
      downsizeIdleTimeout: (json['downsize_idle_timeout'] as num?)?.toInt(),
      evictIdleTimeout: (json['evict_idle_timeout'] as num?)?.toInt(),
      evictWeightFactor: (json['evict_weight_factor'] as num?)?.toDouble(),
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
      if (cfgScale != null) 'cfg_scale': cfgScale,
      if (pinned != null) 'pinned': pinned,
      if (mergeArgs != null) 'merge_args': mergeArgs,
      if (autoEvict != null) 'auto_evict': autoEvict,
      if (downsizeIdleTimeout != null)
        'downsize_idle_timeout': downsizeIdleTimeout,
      if (evictIdleTimeout != null) 'evict_idle_timeout': evictIdleTimeout,
      if (evictWeightFactor != null) 'evict_weight_factor': evictWeightFactor,
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
