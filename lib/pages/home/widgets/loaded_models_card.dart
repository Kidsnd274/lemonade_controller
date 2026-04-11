import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/models/loaded_model.dart';
import 'package:lemonade_controller/pages/home/widgets/dashboard_card.dart';
import 'package:lemonade_controller/pages/model_page/model_page.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/utils/quantization_color.dart';

Future<bool?> _showUnloadConfirmation(
  BuildContext context,
  String displayName,
) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Unload Model'),
      content: Text('Are you sure you want to unload "$displayName"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          autofocus: true,
          child: const Text('Unload'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Main card
// ---------------------------------------------------------------------------

class LoadedModelsCard extends ConsumerWidget {
  const LoadedModelsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(healthInfoProvider);

    return DashboardCard(
      title: 'Loaded Models',
      icon: Icons.model_training,
      contentPadding: const EdgeInsets.all(8),
      child: healthAsync.when(
        data: (health) {
          if (health.allModelsLoaded.isEmpty) {
            return const _EmptyState();
          }
          return _LoadedModelsList(models: health.allModelsLoaded);
        },
        error: (err, _) => _ErrorRow(error: err.toString()),
        loading: () => const _LoadingIndicator(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'No models currently loaded',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model list
// ---------------------------------------------------------------------------

class _LoadedModelsList extends StatelessWidget {
  final List<LoadedModel> models;

  const _LoadedModelsList({required this.models});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < models.length; i++) ...[
          if (i > 0) const Divider(height: 16),
          _LoadedModelTile(loadedModel: models[i]),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Individual model tile
// ---------------------------------------------------------------------------

class _LoadedModelTile extends ConsumerWidget {
  final LoadedModel loadedModel;

  const _LoadedModelTile({required this.loadedModel});

  static final _qLevelPattern = RegExp(r'Q(\d)');

  String get _displayName => loadedModel.modelName.replaceFirst('user.', '');

  String get _quantization => loadedModel.checkpoint.contains(':')
      ? loadedModel.checkpoint.split(':').last
      : '';

  int? get _quantizationLevel {
    final match = _qLevelPattern.firstMatch(_quantization);
    if (match == null) return null;
    return int.parse(match.group(1)!);
  }

  String get _contextSize {
    final ctx = loadedModel.recipeOptions['ctx_size'];
    if (ctx == null) return '';
    final k = (ctx as num).toInt();
    if (k >= 1024) return '${(k / 1024).round()}K ctx';
    return '$k ctx';
  }

  LemonadeModel _resolveModel(WidgetRef ref) {
    final models = ref.read(modelsProvider).value ?? [];
    return models.cast<LemonadeModel?>().firstWhere(
      (m) => m!.id == loadedModel.modelName,
      orElse: () => LemonadeModel(
        id: loadedModel.modelName,
        checkpoint: loadedModel.checkpoint,
        downloaded: true,
        labels: [],
        recipe: loadedModel.recipe,
        recipeOptions: loadedModel.recipeOptions,
        suggested: false,
        ownedBy: '',
      ),
    )!;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnloading = ref.watch(
      isModelLoadingProvider(loadedModel.modelName),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ModelPage(model: _resolveModel(ref)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _ModelInfo(
                displayName: _displayName,
                checkpoint: loadedModel.checkpoint,
                quantization: _quantization,
                quantizationLevel: _quantizationLevel,
                contextSize: _contextSize,
                recipe: loadedModel.recipe,
                device: loadedModel.device,
                type: loadedModel.type,
              ),
            ),
            const SizedBox(width: 8),
            _UnloadAction(
              isUnloading: isUnloading,
              displayName: _displayName,
              modelName: loadedModel.modelName,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model info column (name, chips, checkpoint)
// ---------------------------------------------------------------------------

class _ModelInfo extends StatelessWidget {
  final String displayName;
  final String checkpoint;
  final String quantization;
  final int? quantizationLevel;
  final String contextSize;
  final String recipe;
  final String device;
  final String type;

  const _ModelInfo({
    required this.displayName,
    required this.checkpoint,
    required this.quantization,
    required this.quantizationLevel,
    required this.contextSize,
    required this.recipe,
    required this.device,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ModelNameRow(displayName: displayName),
        const SizedBox(height: 6),
        _ChipsRow(
          quantization: quantization,
          quantizationLevel: quantizationLevel,
          contextSize: contextSize,
          recipe: recipe,
          device: device,
          type: type,
        ),
        const SizedBox(height: 4),
        Text(
          checkpoint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Model name with green dot
// ---------------------------------------------------------------------------

class _ModelNameRow extends StatelessWidget {
  final String displayName;

  const _ModelNameRow({required this.displayName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 8),
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            displayName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chips row (quantization, recipe, device, type, context size)
// ---------------------------------------------------------------------------

class _ChipsRow extends StatelessWidget {
  final String quantization;
  final int? quantizationLevel;
  final String contextSize;
  final String recipe;
  final String device;
  final String type;

  const _ChipsRow({
    required this.quantization,
    required this.quantizationLevel,
    required this.contextSize,
    required this.recipe,
    required this.device,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (quantization.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: quantizationColor(quantizationLevel),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              quantization,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: quantizationForegroundColor(quantizationLevel),
              ),
            ),
          ),
        _MiniChip(label: recipe, color: theme.colorScheme.primaryContainer),
        _MiniChip(label: device, color: theme.colorScheme.secondaryContainer),
        _MiniChip(label: type, color: theme.colorScheme.tertiaryContainer),
        if (contextSize.isNotEmpty)
          _MiniChip(
            label: contextSize,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Unload action (button or spinner)
// ---------------------------------------------------------------------------

class _UnloadAction extends ConsumerWidget {
  final bool isUnloading;
  final String displayName;
  final String modelName;

  const _UnloadAction({
    required this.isUnloading,
    required this.displayName,
    required this.modelName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (isUnloading) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: () async {
        final confirmed = await _showUnloadConfirmation(context, displayName);
        if (confirmed == true && context.mounted) {
          ref.read(loadingModelsProvider.notifier).unloadModel(modelName);
        }
      },
      icon: const Icon(Icons.stop_circle_outlined),
      tooltip: 'Unload model',
      color: theme.colorScheme.error,
      iconSize: 24,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String error;
  const _ErrorRow({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
