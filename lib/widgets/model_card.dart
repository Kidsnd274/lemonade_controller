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
          title: Text(model.id, style: Theme.of(context).textTheme.titleMedium),
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
