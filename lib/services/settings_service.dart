import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const defaultBaseUrl = 'http://localhost:8020/api/v1';
  static const defaultAutoRefreshIntervalSeconds = 60;

  final ThemeMode themeMode;
  final String baseUrl;
  final bool autoRefreshEnabled;
  final int autoRefreshIntervalSeconds;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.baseUrl = defaultBaseUrl,
    this.autoRefreshEnabled = false,
    this.autoRefreshIntervalSeconds = defaultAutoRefreshIntervalSeconds,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? baseUrl,
    bool? autoRefreshEnabled,
    int? autoRefreshIntervalSeconds,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      baseUrl: baseUrl ?? this.baseUrl,
      autoRefreshEnabled: autoRefreshEnabled ?? this.autoRefreshEnabled,
      autoRefreshIntervalSeconds:
          autoRefreshIntervalSeconds ?? this.autoRefreshIntervalSeconds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          themeMode == other.themeMode &&
          baseUrl == other.baseUrl &&
          autoRefreshEnabled == other.autoRefreshEnabled &&
          autoRefreshIntervalSeconds == other.autoRefreshIntervalSeconds;

  @override
  int get hashCode => Object.hash(
        themeMode,
        baseUrl,
        autoRefreshEnabled,
        autoRefreshIntervalSeconds,
      );
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  static const _keyBaseUrl = 'base_url';
  static const _keyThemeMode = 'theme_mode';
  static const _keyAutoRefreshEnabled = 'auto_refresh_enabled';
  static const _keyAutoRefreshIntervalSeconds =
      'auto_refresh_interval_seconds';

  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == prefs.getString(_keyThemeMode),
        orElse: () => ThemeMode.system,
      ),
      baseUrl: prefs.getString(_keyBaseUrl) ?? AppSettings.defaultBaseUrl,
      autoRefreshEnabled: prefs.getBool(_keyAutoRefreshEnabled) ?? false,
      autoRefreshIntervalSeconds:
          prefs.getInt(_keyAutoRefreshIntervalSeconds) ??
              AppSettings.defaultAutoRefreshIntervalSeconds,
    );
  }

  Future<void> modify(AppSettings Function(AppSettings current) updater) async {
    final current = state.requireValue;
    final next = updater(current);
    if (next == current) return;

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyThemeMode, next.themeMode.name),
      prefs.setString(_keyBaseUrl, next.baseUrl),
      prefs.setBool(_keyAutoRefreshEnabled, next.autoRefreshEnabled),
      prefs.setInt(
        _keyAutoRefreshIntervalSeconds,
        next.autoRefreshIntervalSeconds,
      ),
    ]);
    state = AsyncData(next);  // Swap old AppSetting with new one
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const AsyncData(AppSettings());
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
