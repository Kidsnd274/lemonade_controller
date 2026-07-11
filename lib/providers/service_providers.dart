import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:lemonade_controller/models/server_profile.dart';
import 'package:lemonade_controller/services/api_client.dart';
import 'package:lemonade_controller/services/settings_service.dart';

final apiClientProvider = Provider<LemonadeApiClient>((ref) {
  final profile = ref.watch(activeServerProfileProvider);
  return LemonadeApiClient.forProfile(profile);
});

final activeServerProfileProvider = Provider<ServerProfile>((ref) {
  final settings = ref.watch(settingsProvider).value;
  if (settings == null) return ServerProfile.createDefault();
  return settings.activeProfile;
});

/// Process-local app lifecycle state used to stop polling in the background.
final appForegroundProvider = StateProvider<bool>((ref) => true);
