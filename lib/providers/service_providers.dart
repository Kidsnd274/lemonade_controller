import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:lemonade_controller/services/api_client.dart';
import 'package:lemonade_controller/services/settings_service.dart';

final apiClientProvider = Provider<LemonadeApiClient>(
  (ref) => LemonadeApiClient(),
);
final settingServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SettingsService _settings;

  ThemeModeNotifier(this._settings) : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    state = await _settings.getThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _settings.setThemeMode(mode);
    state = mode;
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final settings = ref.watch(settingServiceProvider);
  return ThemeModeNotifier(settings);
});
