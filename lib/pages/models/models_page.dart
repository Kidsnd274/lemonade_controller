import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/services/api_client.dart';
import 'package:lemonade_controller/pages/models/widgets/model_card.dart';

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
      loading: () => Center(child: CircularProgressIndicator()),
    );
  }
}

// class ModelsPage extends StatefulWidget {
//   const ModelsPage({super.key});

//   @override
//   State<ModelsPage> createState() => _ModelsPageState();
// }

// class _ModelsPageState extends State<ModelsPage> {
//   final LemonadeApiClient apiClient = LemonadeApiClient();

//   List<LemonadeModel> modelList = [];

//   @override
//   Widget build(BuildContext context) {
//     return Consumer(
//       builder: (context, ref, child) {
//         final modelsAsync = ref.watch(modelsProvider);

//         return modelsAsync.when(
//           data: (models) => ListView.builder(
//             itemCount: models.length,
//             itemBuilder: (ctx, i) => ModelCard(model: models[i]),
//           ),
//           error: (err, _) => Center(child: Text('Error $err')),
//           loading: () => Center(child: CircularProgressIndicator()),
//         );
//       },
//     );
//   }
// }
