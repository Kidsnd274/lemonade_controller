import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/services/api_client.dart';
import 'package:lemonade_controller/services/settings_service.dart';

final apiClientProvider = Provider<LemonadeApiClient>((ref) {
  final baseUrl =
      ref.watch(settingsProvider).value?.baseUrl ?? AppSettings.defaultBaseUrl;
  return LemonadeApiClient(baseUrl: baseUrl);
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).value?.themeMode ??
      ThemeMode.system;
});
