import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';

class LoadedModelCard extends StatelessWidget {
  final LemonadeModel model;

  const LoadedModelCard({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
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
        trailing: IconButton(
          onPressed: null,
          icon: const Icon(Icons.play_arrow),
          tooltip: 'Unload Model',
        ),
      ),
    );
  }
}
