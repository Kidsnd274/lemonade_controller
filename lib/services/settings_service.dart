import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyBaseUrl = 'base_url';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyAutoRefreshEnabled = 'auto_refresh_enabled';
  static const String _keyAutoRefreshIntervalSeconds = 'auto_refresh_interval_seconds';

  static const String _defaultBaseUrl = 'http://192.168.1.7:8020/api/v1';
  static const bool _defaultAutoRefreshEnabled = false;
  static const int _defaultAutoRefreshIntervalSeconds = 60;

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyThemeMode);
    return ThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  Future<bool> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyThemeMode, mode.name);
  }

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaseUrl) ?? _defaultBaseUrl;
  }

  Future<bool> getAutoRefreshEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoRefreshEnabled) ?? _defaultAutoRefreshEnabled;
  }

  Future<int> getAutoRefreshIntervalSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAutoRefreshIntervalSeconds) ?? _defaultAutoRefreshIntervalSeconds;
  }

  // Setters
  Future<bool> setBaseUrl(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyBaseUrl, baseUrl);
  }

  Future<bool> setAutoRefreshEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(_keyAutoRefreshEnabled, enabled);
  }

  Future<bool> setAutoRefreshIntervalSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setInt(_keyAutoRefreshIntervalSeconds, seconds);
  }

  // Optional: Reset all settings
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}