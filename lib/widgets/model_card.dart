import 'package:flutter/material.dart';

import '../models/lemonade_model.dart';

class ModelCard extends StatelessWidget {
  final LemonadeModel model;

  const ModelCard({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: ListTile(
          title: Row(
            children: [
              if (model.isUserModel) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'user.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],

              Text(
                model.displayName,
                style: Theme.of(context).textTheme.labelLarge,
              ),

              if (model.isUserModel) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    model.quantization,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondary,
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
          trailing: model.downloaded
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.hourglass_empty, color: Colors.grey),
        ),
      ),
    );
  }
}
