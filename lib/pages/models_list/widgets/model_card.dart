import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/pages/model_page/model_page.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/utils/quantization_color.dart';

class ModelCard extends ConsumerWidget {
  final LemonadeModel model;

  const ModelCard({super.key, required this.model});

  Future<bool?> _showLoadConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Model'),
        content: Text('Are you sure you want to load "${model.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Load'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showUnloadConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unload Model'),
        content:
            Text('Are you sure you want to unload "${model.displayName}"?'),
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
            child: const Text('Unload'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(isModelLoadingProvider(model.id));
    final isLoaded = ref.watch(isModelLoadedProvider(model.id));
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ModelPage(model: model)),
        ),
        title: Row(
          children: [
            if (model.isUserModel) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'user.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                model.displayName,
                style: theme.textTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (model.isUserModel) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: quantizationColor(model.quantizationLevel),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  model.quantization,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: quantizationForegroundColor(
                        model.quantizationLevel),
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Checkpoint: ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: '${model.checkpoint}\n'),
              const TextSpan(
                text: 'Labels: ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: model.labels.join(', ')),
            ],
          ),
        ),
        trailing: isLoading
            ? const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : isLoaded
                ? IconButton(
                    onPressed: () async {
                      final confirmed =
                          await _showUnloadConfirmation(context);
                      if (confirmed == true && context.mounted) {
                        ref
                            .read(loadingModelsProvider.notifier)
                            .unloadModel(model.id);
                      }
                    },
                    icon: const Icon(Icons.stop_circle_outlined),
                    tooltip: 'Unload model',
                    color: theme.colorScheme.error,
                  )
                : IconButton(
                    onPressed: () async {
                      final confirmed =
                          await _showLoadConfirmation(context);
                      if (confirmed == true && context.mounted) {
                        ref
                            .read(loadingModelsProvider.notifier)
                            .loadModel(model.id);
                      }
                    },
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Load model',
                  ),
      ),
    );
  }
}
