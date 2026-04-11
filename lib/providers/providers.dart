import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/services/settings_service.dart';

final refreshAllProvider = Provider((ref) {
  return () async {
    await Future.wait([ref.read(loadedModelsProvider.notifier).updateState()]);
    ref.invalidate(modelsProvider);
    ref.invalidate(systemInfoProvider);
    ref.invalidate(healthInfoProvider);
  };
});

final autoRefreshProvider = Provider<void>((ref) {
  Timer? timer;

  void cancelTimer() {
    timer?.cancel();
    timer = null;
  }

  final settings = ref.watch(settingsProvider).value;
  if (settings == null || !settings.autoRefreshEnabled) {
    cancelTimer();
    return;
  }

  final interval = Duration(seconds: settings.autoRefreshIntervalSeconds);
  final refreshAll = ref.read(refreshAllProvider);

  timer = Timer.periodic(interval, (_) => refreshAll());

  ref.onDispose(cancelTimer);
});
