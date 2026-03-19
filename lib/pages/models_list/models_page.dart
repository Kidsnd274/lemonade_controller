import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/pages/models_list/widgets/model_card.dart';

class ModelsPage extends ConsumerWidget {
  const ModelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(modelsProvider);

    return modelsAsync.when(
      data: (models) => ListView.builder(
        itemCount: models.length,
        itemBuilder: (ctx, i) => ModelCard(model: models[i]),
      ),
      error: (err, _) => Center(child: Text('Error $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
