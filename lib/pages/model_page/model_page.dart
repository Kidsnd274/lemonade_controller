import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/pages/model_page/configure_load_dialog.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/utils/quantization_color.dart';

/// Approximate bits-per-weight for common GGUF quantization formats.
const _quantizationBitsPerWeight = <String, double>{
  'F32': 32.0,
  'F16': 16.0,
  'BF16': 16.0,
  'Q8_0': 8.5,
  'Q6_K': 6.56,
  'Q5_K_M': 5.69,
  'Q5_K_S': 5.54,
  'Q5_0': 5.54,
  'Q4_K_M': 4.85,
  'Q4_K_S': 4.59,
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
/// checkpoint string. Looks for patterns like "7b", "0.5B", "72b", etc.
double? _extractParamsBillions(String text) {
  final match = RegExp(
    r'(?:^|[-_./])(\d+(?:\.\d+)?)[bB](?:[-_.]|$)',
  ).firstMatch(text);
  return match != null ? double.tryParse(match.group(1)!) : null;
}

/// Rough VRAM estimate in GB based on parameter count and quantization.
/// Adds ~15 % overhead for KV cache, computation buffers, etc.
double? _estimateVramGb(double paramsBillions, String quantization) {
  final bpw = _quantizationBitsPerWeight[quantization.toUpperCase()];
  if (bpw == null) return null;
  final weightBytes = paramsBillions * 1e9 * bpw / 8;
  return weightBytes * 1.15 / (1024 * 1024 * 1024);
}

String _formatFileSize(double bytes) {
  if (bytes < 1024) return '${bytes.toInt()} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class ModelPage extends ConsumerWidget {
  final LemonadeModel model;

  const ModelPage({super.key, required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoaded = ref.watch(isModelLoadedProvider(model.id));
    final isLoading = ref.watch(isModelLoadingProvider(model.id));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: theme.colorScheme.inversePrimary,
        title: const Text('Model Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(model: model, isLoaded: isLoaded),
            const SizedBox(height: 28),
            _ActionButtons(
              model: model,
              isLoaded: isLoaded,
              isLoading: isLoading,
            ),
            const SizedBox(height: 32),
            _ModelDetailsCard(model: model),
            const SizedBox(height: 20),
            _RecipeOptionsCard(model: model),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final LemonadeModel model;
  final bool isLoaded;

  const _Header({required this.model, required this.isLoaded});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (model.isUserModel)
                    _Badge(
                      label: 'user',
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  Text(
                    model.displayName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (model.isUserModel)
                    _Badge(
                      label: model.quantization,
                      backgroundColor: quantizationColor(
                        model.quantizationLevel,
                      ),
                      foregroundColor: quantizationForegroundColor(
                        model.quantizationLevel,
                      ),
                    ),
                ],
              ),
              if (model.labels.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: model.labels
                      .map(
                        (l) => Chip(
                          label: Text(l),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        _StatusIndicator(isLoaded: isLoaded),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _Badge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final bool isLoaded;

  const _StatusIndicator({required this.isLoaded});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isLoaded ? Colors.green : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isLoaded
            ? Colors.green.withAlpha(30)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLoaded ? Colors.green : theme.colorScheme.outline,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLoaded ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            isLoaded ? 'Loaded' : 'Not Loaded',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action buttons
// ---------------------------------------------------------------------------

class _ActionButtons extends ConsumerWidget {
  final LemonadeModel model;
  final bool isLoaded;
  final bool isLoading;

  const _ActionButtons({
    required this.model,
    required this.isLoaded,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Load / Unload
        isLoaded
            ? FilledButton.icon(
                onPressed: isLoading
                    ? null
                    : () => _confirmUnload(context, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                ),
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.stop),
                label: Text(isLoading ? 'Unloading…' : 'Unload'),
              )
            : FilledButton.icon(
                onPressed: isLoading ? null : () => _confirmLoad(context, ref),
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(isLoading ? 'Loading…' : 'Load'),
              ),

        // Configure & Load
        OutlinedButton.icon(
          onPressed: isLoading ? null : () => _configureAndLoad(context, ref),
          icon: const Icon(Icons.tune),
          label: const Text('Configure & Load'),
        ),

        // Delete
        OutlinedButton.icon(
          onPressed: () => _confirmDelete(context),
          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          label: Text(
            'Delete',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: theme.colorScheme.error.withAlpha(120)),
          ),
        ),
      ],
    );
  }

  void _configureAndLoad(BuildContext context, WidgetRef ref) async {
    final options = await showConfigureLoadDialog(context, model);
    if (options == null || !context.mounted) return;
    ref
        .read(loadingModelsProvider.notifier)
        .loadModel(model.id, options: options);
  }

  void _confirmLoad(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Model'),
        content: Text('Are you sure you want to load "${model.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(loadingModelsProvider.notifier).loadModel(model.id);
            },
            child: const Text('Load'),
          ),
        ],
      ),
    );
  }

  void _confirmUnload(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unload Model'),
        content: Text(
          'Are you sure you want to unload "${model.displayName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(loadingModelsProvider.notifier).unloadModel(model.id);
            },
            child: const Text('Unload'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          size: 48,
          color: Colors.red,
        ),
        title: const Text('Delete Model?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to delete "${model.displayName}"?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeleteFinal(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFinal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.dangerous, size: 48, color: Colors.red),
        title: const Text('Final Confirmation'),
        content: Text(
          'This will permanently delete "${model.displayName}" and all its '
          'configuration. Are you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete not yet implemented')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model details card
// ---------------------------------------------------------------------------

class _ModelDetailsCard extends StatelessWidget {
  final LemonadeModel model;

  const _ModelDetailsCard({required this.model});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paramsBillions =
        _extractParamsBillions(model.id) ??
        _extractParamsBillions(model.checkpoint.split(':').first);
    final vramEstimate = paramsBillions != null
        ? _estimateVramGb(paramsBillions, model.quantization)
        : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Model Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _DetailRow(label: 'Checkpoint', value: model.checkpoint),
            _DetailRow(label: 'Recipe', value: model.recipe),
            _DetailRow(label: 'Quantization', value: model.quantization),
            if (paramsBillions != null)
              _DetailRow(label: 'Parameters', value: '${paramsBillions}B'),
            if (vramEstimate != null)
              _DetailRow(
                label: 'VRAM Estimate',
                value: '~${vramEstimate.toStringAsFixed(1)} GB',
              ),
            if (model.size != null)
              _DetailRow(
                label: 'File Size',
                value: _formatFileSize(model.size!),
              ),
            _DetailRow(
              label: 'Downloaded',
              value: model.downloaded ? 'Yes' : 'No',
            ),
            if (model.ownedBy.isNotEmpty)
              _DetailRow(label: 'Owner', value: model.ownedBy),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recipe options card
// ---------------------------------------------------------------------------

class _RecipeOptionsCard extends StatelessWidget {
  final LemonadeModel model;

  const _RecipeOptionsCard({required this.model});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = model.recipeOptions;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_suggest,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recipe Options',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (options.isEmpty)
              Text(
                'No options configured',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...options.entries.map(
                (e) => _DetailRow(label: e.key, value: e.value.toString()),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared detail row
// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
