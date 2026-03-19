import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

final refreshAllProvider = Provider((ref) {
  return () async {
    await Future.wait([ref.read(loadedModelsProvider.notifier).updateState()]);
    ref.invalidate(modelsProvider);
  };
});
