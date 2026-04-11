import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';

/// Lazily loaded parameter overrides from assets/model_params.json.
/// Maps lowercase model name substrings to parameter counts in billions.
Map<String, double>? _paramOverrides;
bool _paramOverridesLoaded = false;

/// Loads the model parameter overrides from the bundled JSON asset.
/// Safe to call multiple times; only loads once.
Future<void> loadParamOverrides() async {
  if (_paramOverridesLoaded) return;
  _paramOverridesLoaded = true;
  try {
    final json = await rootBundle.loadString('assets/model_params.json');
    final map = jsonDecode(json) as Map<String, dynamic>;
    _paramOverrides = {};
    for (final entry in map.entries) {
      if (entry.key.startsWith('_')) continue;
      final value = entry.value;
      if (value is num) {
        _paramOverrides![entry.key.toLowerCase()] = value.toDouble();
      }
    }
  } catch (_) {
    _paramOverrides = null;
  }
}

/// Looks up parameter count from the overrides file.
/// Returns the value in billions if the model name contains a known key.
double? _lookupParamOverride(String text) {
  final overrides = _paramOverrides;
  if (overrides == null) return null;
  final lower = text.toLowerCase();
  for (final entry in overrides.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return null;
}

/// Approximate bits-per-weight for common GGUF quantization formats.
///
/// UD (Uneven Distribution) variants use variable bpw across layers, keeping
/// important layers at higher precision. The _XL suffix indicates an even
/// larger spread. Average bpw is slightly above the base quant level.
const quantizationBitsPerWeight = <String, double>{
  'F32': 32.0,
  'F16': 16.0,
  'BF16': 16.0,
  'Q8_0': 8.5,
  'Q8_K_XL': 8.5,
  'UD-Q8_K_XL': 8.5,
  'Q6_K': 6.56,
  'Q6_K_XL': 6.56,
  'UD-Q6_K_XL': 6.56,
  'Q5_K_M': 5.69,
  'Q5_K_S': 5.54,
  'Q5_K_XL': 5.69,
  'UD-Q5_K_XL': 5.69,
  'Q5_0': 5.54,
  'Q4_K_M': 4.85,
  'Q4_K_S': 4.59,
  'Q4_K_XL': 4.85,
  'UD-Q4_K_XL': 4.85,
  'Q4_0': 4.55,
  'Q3_K_L': 3.91,
  'Q3_K_M': 3.91,
  'Q3_K_S': 3.50,
  'Q2_K': 3.35,
  'IQ4_XS': 4.25,
  'IQ3_XXS': 3.06,
  'IQ2_XXS': 2.06,
};

/// Tries to extract a parameter count (in billions) from a model name or
/// checkpoint string. First checks the overrides file, then looks for
/// patterns like "7b", "0.5B", "72b", etc.
double? extractParamsBillions(String text) {
  final override = _lookupParamOverride(text);
  if (override != null) return override;

  final match = RegExp(
    r'(?:^|[-_./])(\d+(?:\.\d+)?)[bB](?:[-_.]|$)',
  ).firstMatch(text);
  return match != null ? double.tryParse(match.group(1)!) : null;
}

/// Human-readable file size string from a byte count.
String formatFileSize(double bytes) {
  if (bytes < 1024) return '${bytes.toInt()} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

const _gib = 1024.0 * 1024.0 * 1024.0;

/// Default context size used when none is specified.
const defaultCtxSize = 2048;

/// ~65 MB of KV cache per billion parameters per 1 K tokens of context
/// (FP16 KV). Derived from typical transformer layer/head ratios.
/// Converted to GB: 0.065 MB = 0.065 / 1024 GB
const _kvGbPerBillionPer1k = 0.065 / 1024;

/// Fixed overhead for CUDA/Vulkan context, activations and scratch buffers.
const _fixedOverheadGb = 1.0;

/// Proportional overhead on top of model weights (buffers, compute graphs).
const _proportionalOverhead = 0.15;

/// Breakdown of a VRAM estimate.
class VramEstimate {
  /// Memory consumed by the quantized model weights.
  final double weightMemoryGb;

  /// Memory consumed by the KV cache at the given context size.
  final double kvCacheGb;

  /// Runtime overhead (fixed + proportional).
  final double overheadGb;

  /// The context size this estimate was computed for.
  final int ctxSize;

  const VramEstimate({
    required this.weightMemoryGb,
    required this.kvCacheGb,
    required this.overheadGb,
    required this.ctxSize,
  });

  double get totalGb => weightMemoryGb + kvCacheGb + overheadGb;
}

/// Estimates VRAM usage for a model given its parameter count, quantization
/// format and (optionally) the context window size.
///
/// Returns `null` if the quantization string is not recognized.
VramEstimate? estimateVram({
  required double paramsBillions,
  required String quantization,
  int? ctxSize,
}) {
  final bpw = quantizationBitsPerWeight[quantization.toUpperCase()];
  if (bpw == null) return null;

  final ctx = ctxSize ?? defaultCtxSize;

  final weightMemoryGb = paramsBillions * 1e9 * bpw / 8 / _gib;

  // KV cache: ~65 MB per billion params per 1 K tokens (FP16 keys+values).
  final kvCacheGb = (ctx / 1024.0) * paramsBillions * _kvGbPerBillionPer1k;

  final overheadGb = _fixedOverheadGb + weightMemoryGb * _proportionalOverhead;

  return VramEstimate(
    weightMemoryGb: weightMemoryGb,
    kvCacheGb: kvCacheGb,
    overheadGb: overheadGb,
    ctxSize: ctx,
  );
}

/// Tries to extract quantization from a checkpoint string (after the last ':').
String extractQuantization(String checkpoint) {
  final parts = checkpoint.split(':');
  return parts.length > 1 ? parts.last : 'Unknown';
}

/// Attempts to estimate VRAM for a model identified only by its name/checkpoint
/// string and an optional context size.
///
/// Tries to parse the parameter count and quantization from the string.
/// Returns `null` if either cannot be determined.
VramEstimate? estimateVramFromModelName(String modelName, {int? ctxSize}) {
  final params =
      extractParamsBillions(modelName) ??
      extractParamsBillions(modelName.split(':').first);
  if (params == null) return null;

  final quant = extractQuantization(modelName);
  if (quant == 'Unknown') return null;

  return estimateVram(
    paramsBillions: params,
    quantization: quant,
    ctxSize: ctxSize,
  );
}

/// Estimates VRAM for a [LemonadeModel], using its checkpoint for quantization
/// and its ID / checkpoint for parameter extraction. Optionally override
/// the context size (otherwise uses the model's recipe_options ctx_size or the
/// default).
VramEstimate? estimateVramForModel(LemonadeModel model, {int? ctxSize}) {
  final paramsBillions =
      extractParamsBillions(model.id) ??
      extractParamsBillions(model.checkpoint.split(':').first);
  if (paramsBillions == null) return null;

  final ctx =
      ctxSize ?? (model.recipeOptions['ctx_size'] as num?)?.toInt();

  return estimateVram(
    paramsBillions: paramsBillions,
    quantization: model.quantization,
    ctxSize: ctx,
  );
}
