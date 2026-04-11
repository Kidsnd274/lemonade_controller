import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/pages/model_page/configure_load_dialog.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/utils/quantization_color.dart';
import 'package:lemonade_controller/utils/vram_estimator.dart';

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
            _VramEstimateCard(model: model),
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
        extractParamsBillions(model.id) ??
        extractParamsBillions(model.checkpoint.split(':').first);

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
            if (model.size != null)
              _DetailRow(
                label: 'File Size',
                value: formatFileSize(model.size!),
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
// VRAM estimate card
// ---------------------------------------------------------------------------

class _VramEstimateCard extends StatelessWidget {
  final LemonadeModel model;

  const _VramEstimateCard({required this.model});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final paramsBillions =
        extractParamsBillions(model.id) ??
        extractParamsBillions(model.checkpoint.split(':').first);

    if (paramsBillions == null) return const SizedBox.shrink();

    final ctxSize = (model.recipeOptions['ctx_size'] as num?)?.toInt();

    final vram = estimateVram(
      paramsBillions: paramsBillions,
      quantization: model.quantization,
      ctxSize: ctxSize,
    );

    if (vram == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Estimated VRAM Usage',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _VramTotalRow(totalGb: vram.totalGb, theme: theme),
            const SizedBox(height: 16),
            _VramBreakdownBar(vram: vram, theme: theme),
            const SizedBox(height: 16),
            _VramBreakdownLegend(vram: vram, theme: theme),
            const SizedBox(height: 8),
            Text(
              'Estimated at ${vram.ctxSize} token context window',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VramTotalRow extends StatelessWidget {
  final double totalGb;
  final ThemeData theme;

  const _VramTotalRow({required this.totalGb, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '~${totalGb.toStringAsFixed(1)}',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'GB',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _VramBreakdownBar extends StatelessWidget {
  final VramEstimate vram;
  final ThemeData theme;

  const _VramBreakdownBar({required this.vram, required this.theme});

  @override
  Widget build(BuildContext context) {
    final total = vram.totalGb;
    if (total <= 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            Flexible(
              flex: (vram.weightMemoryGb / total * 1000).round(),
              child: Container(color: theme.colorScheme.primary),
            ),
            Flexible(
              flex: (vram.kvCacheGb / total * 1000).round(),
              child: Container(color: theme.colorScheme.tertiary),
            ),
            Flexible(
              flex: (vram.overheadGb / total * 1000).round(),
              child: Container(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VramBreakdownLegend extends StatelessWidget {
  final VramEstimate vram;
  final ThemeData theme;

  const _VramBreakdownLegend({required this.vram, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendItem(
          color: theme.colorScheme.primary,
          label: 'Weights',
          value: '${vram.weightMemoryGb.toStringAsFixed(1)} GB',
          theme: theme,
        ),
        const SizedBox(width: 16),
        _LegendItem(
          color: theme.colorScheme.tertiary,
          label: 'KV Cache',
          value: '${vram.kvCacheGb.toStringAsFixed(2)} GB',
          theme: theme,
        ),
        const SizedBox(width: 16),
        _LegendItem(
          color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
          label: 'Overhead',
          value: '${vram.overheadGb.toStringAsFixed(2)} GB',
          theme: theme,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final ThemeData theme;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
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
