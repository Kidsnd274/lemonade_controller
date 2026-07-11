class PullVariant {
  final String name;
  final String primaryFile;
  final List<String> files;
  final bool sharded;
  final int sizeBytes;

  const PullVariant({
    required this.name,
    required this.primaryFile,
    required this.files,
    required this.sharded,
    required this.sizeBytes,
  });

  factory PullVariant.fromJson(Map<String, dynamic> json) {
    return PullVariant(
      name: json['name']?.toString() ?? '',
      primaryFile: json['primary_file']?.toString() ?? '',
      files: (json['files'] as List?)?.map((e) => e.toString()).toList() ?? [],
      sharded: json['sharded'] as bool? ?? false,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Detects the quantization bit-width from the variant name.
  /// Returns null when the name does not match a known pattern.
  ///
  /// Handles every variant emitted by llama.cpp / unsloth in the wild:
  /// - `Q2_K`, `Q3_K_S`, `Q4_0`, `Q4_K_M`, `Q5_K_M`, `Q6_K`, `Q8_0` …
  /// - `IQ1_S`, `IQ2_XXS`, `IQ3_M`, `IQ4_NL`, `IQ4_XS` (i-quants)
  /// - `TQ1_0`, `TQ2_0` (ternary)
  /// - `UD-Q4_K_XL`, `UD-IQ2_M` (Unsloth Dynamic prefix stripped)
  /// - `BF16`, `F16`, `FP16` → 16
  /// - `F32`, `FP32` → 32
  int? get quantBits {
    var upper = name.toUpperCase();
    if (upper.startsWith('UD-')) upper = upper.substring(3);

    // Matches Q<n>, IQ<n>, TQ<n> with any trailing variant suffix.
    final match = RegExp(r'^[IT]?Q(\d+)').firstMatch(upper);
    if (match != null) return int.tryParse(match.group(1)!);

    if (upper == 'BF16' || upper == 'F16' || upper == 'FP16') return 16;
    if (upper == 'F32' || upper == 'FP32') return 32;
    return null;
  }
}

class PullVariants {
  final String checkpoint;
  final String recipe;
  final String suggestedName;
  final List<String> suggestedLabels;
  final List<String> mmprojFiles;
  final List<PullVariant> variants;

  const PullVariants({
    required this.checkpoint,
    required this.recipe,
    required this.suggestedName,
    required this.suggestedLabels,
    required this.mmprojFiles,
    required this.variants,
  });

  factory PullVariants.fromJson(Map<String, dynamic> json) {
    return PullVariants(
      checkpoint: json['checkpoint']?.toString() ?? '',
      recipe: json['recipe']?.toString() ?? '',
      suggestedName: json['suggested_name']?.toString() ?? '',
      suggestedLabels:
          (json['suggested_labels'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      mmprojFiles:
          (json['mmproj_files'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      variants:
          (json['variants'] as List?)
              ?.map(
                (e) => PullVariant.fromJson((e as Map).cast<String, dynamic>()),
              )
              .toList() ??
          [],
    );
  }
}
