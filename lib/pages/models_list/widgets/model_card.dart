import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/pages/model_page/model_page.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

class ModelCard extends ConsumerWidget {
  final LemonadeModel model;

  const ModelCard({super.key, required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(isModelLoadingProvider(model.id));
    final isLoaded = ref.watch(isModelLoadedProvider(model.id));
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ModelPage(model: model)),
        ),
        title: Row(
          children: [
            if (model.isUserModel) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
            Text(model.displayName, style: theme.textTheme.labelLarge),
            if (model.isUserModel) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  model.quantization,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          'Checkpoint: ${model.checkpoint}\n'
          'Labels: ${model.labels.join(", ")}',
        ),
        trailing: isLoaded
            ? Icon(Icons.check_circle, color: Colors.green)
            : IconButton(
                onPressed: isLoading
                    ? null
                    : () => ref
                          .read(loadingModelsProvider.notifier)
                          .loadModel(model.id),
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                tooltip: isLoading ? 'Loading...' : 'Load model',
              ),
      ),
    );
  }
}
