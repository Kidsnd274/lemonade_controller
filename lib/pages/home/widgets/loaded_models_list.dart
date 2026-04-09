import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/models/loaded_model.dart';
import 'package:lemonade_controller/pages/models_list/widgets/model_card.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

class LoadedModelsList extends ConsumerWidget {
  const LoadedModelsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadedModels = ref.watch(loadedModelsProvider);
    final modelsAsync = ref.watch(modelsProvider);

    return modelsAsync.when(
      data: (models) => ListView.builder(
        itemCount: loadedModels.length,
        itemBuilder: (ctx, i) {
          LoadedModel currLoadedModel = loadedModels.elementAt(i);
          LemonadeModel currModel = models.firstWhere(
            (m) => m.id == currLoadedModel.modelName,
          );
          return ModelCard(model: currModel);
        },
      ),
      error: (err, _) => Center(child: Text('Error $err')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
