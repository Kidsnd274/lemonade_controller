import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/pages/model_page/model_page.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/providers/service_providers.dart';
import 'package:lemonade_controller/utils/quantization_color.dart';

class ModelCard extends ConsumerWidget {
  final LemonadeModel model;
  final bool isFavourite;
  final VoidCallback? onToggleFavourite;

  const ModelCard({
    super.key,
    required this.model,
    this.isFavourite = false,
    this.onToggleFavourite,
  });

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
            autofocus: true,
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
        content: Text(
          'Are you sure you want to unload "${model.displayName}"?',
        ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(isModelLoadingProvider(model.id));
    final isLoaded = ref.watch(isModelLoadedProvider(model.id));
    final health = ref.watch(healthInfoProvider).value;
    final loaded = ref
        .watch(loadedModelsProvider)
        .where((item) => item.modelName == model.id);
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: onToggleFavourite != null
            ? IconButton(
                onPressed: onToggleFavourite,
                icon: Icon(
                  isFavourite ? Icons.favorite : Icons.favorite_border,
                  color: isFavourite ? theme.colorScheme.error : null,
                ),
                tooltip: isFavourite
                    ? 'Remove from favourites'
                    : 'Add to favourites',
                visualDensity: VisualDensity.compact,
              )
            : null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ModelPage(model: model)),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                model.displayName,
                style: theme.textTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (model.quantization != 'Unknown') ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: quantizationColor(model.quantizationLevel),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  model.quantization,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: quantizationForegroundColor(model.quantizationLevel),
                  ),
                ),
              ),
            ],
            if (loaded.isNotEmpty && loaded.first.pinned) ...[
              const SizedBox(width: 4),
              const Tooltip(
                message: 'Pinned in memory',
                child: Icon(Icons.push_pin, size: 16),
              ),
            ],
            if (model.updateAvailable &&
                (health?.updateCheckDone ?? false)) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: 'Update available',
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    try {
                      await ref.read(apiClientProvider).resumePull(model.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Model update started.'),
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.system_update_alt, size: 16),
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
                  FocusScope.of(context).unfocus();
                  final confirmed = await _showUnloadConfirmation(context);
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
                  FocusScope.of(context).unfocus();
                  final confirmed = await _showLoadConfirmation(context);
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
