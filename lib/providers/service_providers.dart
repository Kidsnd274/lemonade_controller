import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/services/api_client.dart';
import 'package:lemonade_controller/services/settings_service.dart';

final apiClientProvider = Provider<LemonadeApiClient>((ref) {
  final baseUrl =
      ref.watch(settingsProvider).value?.baseUrl ?? AppSettings.defaultBaseUrl;
  return LemonadeApiClient(baseUrl: baseUrl);
});
