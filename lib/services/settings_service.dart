import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/model_load_preset.dart';
import 'package:lemonade_controller/models/server_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const defaultBaseUrl = 'http://localhost:8020/api/v1';
  static const defaultAutoRefreshIntervalSeconds = 60;

  final ThemeMode themeMode;
  final double uiScale;
  final bool autoRefreshEnabled;
  final int autoRefreshIntervalSeconds;
  final List<ServerProfile> serverProfiles;
  final String activeProfileId;
  final Set<String> favouriteModelIds;
  final List<ModelLoadPreset> modelLoadPresets;
  final Map<String, double> modelParamOverrides;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.uiScale = 1.0,
    this.autoRefreshEnabled = false,
    this.autoRefreshIntervalSeconds = defaultAutoRefreshIntervalSeconds,
    this.serverProfiles = const [],
    this.activeProfileId = 'default',
    this.favouriteModelIds = const {},
    this.modelLoadPresets = const [],
    this.modelParamOverrides = const {},
  });

  ServerProfile get activeProfile {
    if (serverProfiles.isEmpty) return ServerProfile.createDefault();
    return serverProfiles.firstWhere(
      (p) => p.id == activeProfileId,
      orElse: () => serverProfiles.first,
    );
  }

  String get baseUrl => activeProfile.baseUrl;

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'uiScale': uiScale,
        'autoRefreshEnabled': autoRefreshEnabled,
        'autoRefreshIntervalSeconds': autoRefreshIntervalSeconds,
        'serverProfiles': serverProfiles.map((p) => p.toJson()).toList(),
        'activeProfileId': activeProfileId,
        'favouriteModelIds': favouriteModelIds.toList(),
        'modelLoadPresets': modelLoadPresets.map((p) => p.toJson()).toList(),
        'modelParamOverrides': modelParamOverrides,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      uiScale: (json['uiScale'] as num?)?.toDouble() ?? 1.0,
      autoRefreshEnabled: json['autoRefreshEnabled'] as bool? ?? false,
      autoRefreshIntervalSeconds:
          json['autoRefreshIntervalSeconds'] as int? ??
              defaultAutoRefreshIntervalSeconds,
      serverProfiles: (json['serverProfiles'] as List<dynamic>?)
              ?.map(
                (e) => ServerProfile.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      activeProfileId: json['activeProfileId'] as String? ?? 'default',
      favouriteModelIds: (json['favouriteModelIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          {},
      modelLoadPresets: (json['modelLoadPresets'] as List<dynamic>?)
              ?.map(
                (e) => ModelLoadPreset.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      modelParamOverrides:
          (json['modelParamOverrides'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, (v as num).toDouble()),
              ) ??
              {},
    );
  }

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? uiScale,
    bool? autoRefreshEnabled,
    int? autoRefreshIntervalSeconds,
    List<ServerProfile>? serverProfiles,
    String? activeProfileId,
    Set<String>? favouriteModelIds,
    List<ModelLoadPreset>? modelLoadPresets,
    Map<String, double>? modelParamOverrides,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      uiScale: uiScale ?? this.uiScale,
      autoRefreshEnabled: autoRefreshEnabled ?? this.autoRefreshEnabled,
      autoRefreshIntervalSeconds:
          autoRefreshIntervalSeconds ?? this.autoRefreshIntervalSeconds,
      serverProfiles: serverProfiles ?? this.serverProfiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      favouriteModelIds: favouriteModelIds ?? this.favouriteModelIds,
      modelLoadPresets: modelLoadPresets ?? this.modelLoadPresets,
      modelParamOverrides: modelParamOverrides ?? this.modelParamOverrides,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          themeMode == other.themeMode &&
          uiScale == other.uiScale &&
          autoRefreshEnabled == other.autoRefreshEnabled &&
          autoRefreshIntervalSeconds == other.autoRefreshIntervalSeconds &&
          activeProfileId == other.activeProfileId &&
          _profileListEquals(serverProfiles, other.serverProfiles) &&
          _setEquals(favouriteModelIds, other.favouriteModelIds) &&
          _presetListEquals(modelLoadPresets, other.modelLoadPresets) &&
          _doubleMapEquals(modelParamOverrides, other.modelParamOverrides);

  static bool _profileListEquals(
    List<ServerProfile> a,
    List<ServerProfile> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  static bool _presetListEquals(
    List<ModelLoadPreset> a,
    List<ModelLoadPreset> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _doubleMapEquals(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        themeMode,
        uiScale,
        autoRefreshEnabled,
        autoRefreshIntervalSeconds,
        activeProfileId,
        Object.hashAll(serverProfiles),
        Object.hashAll(favouriteModelIds),
        Object.hashAll(modelLoadPresets),
        Object.hashAll(
          modelParamOverrides.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  static const _keyThemeMode = 'theme_mode';
  static const _keyAutoRefreshEnabled = 'auto_refresh_enabled';
  static const _keyAutoRefreshIntervalSeconds =
      'auto_refresh_interval_seconds';
  static const _keyServerProfiles = 'server_profiles';
  static const _keyActiveProfileId = 'active_profile_id';
  static const _keyFavouriteModelIds = 'favourite_model_ids';
  static const _keyModelLoadPresets = 'model_load_presets';
  static const _keyUiScale = 'ui_scale';
  static const _keyModelParamOverrides = 'model_param_overrides';

  // Legacy key for migration
  static const _keyBaseUrl = 'base_url';

  /// Loads default model parameter overrides from the bundled asset.
  static Future<Map<String, double>> loadDefaultModelParamOverrides() async {
    try {
      final json = await rootBundle.loadString('assets/model_params.json');
      final map = jsonDecode(json) as Map<String, dynamic>;
      final result = <String, double>{};
      for (final entry in map.entries) {
        if (entry.key.startsWith('_')) continue;
        final value = entry.value;
        if (value is num) {
          result[entry.key] = value.toDouble();
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();

    List<ServerProfile> profiles;
    String activeId;

    final profilesJson = prefs.getString(_keyServerProfiles);
    if (profilesJson != null) {
      profiles = ServerProfile.decodeList(profilesJson);
      activeId = prefs.getString(_keyActiveProfileId) ?? 'default';
    } else {
      // Migrate from legacy single baseUrl
      final legacyUrl =
          prefs.getString(_keyBaseUrl) ?? AppSettings.defaultBaseUrl;
      profiles = [ServerProfile.createDefault(baseUrl: legacyUrl)];
      activeId = 'default';
      // Persist the migration
      await prefs.setString(
        _keyServerProfiles,
        ServerProfile.encodeList(profiles),
      );
      await prefs.setString(_keyActiveProfileId, activeId);
      await prefs.remove(_keyBaseUrl);
    }

    final favouriteIds =
        prefs.getStringList(_keyFavouriteModelIds)?.toSet() ?? {};

    final presetsJson = prefs.getString(_keyModelLoadPresets);
    final presets =
        presetsJson != null ? ModelLoadPreset.decodeList(presetsJson) : <ModelLoadPreset>[];

    Map<String, double> modelParamOverrides;
    final overridesJson = prefs.getString(_keyModelParamOverrides);
    if (overridesJson != null) {
      final decoded = jsonDecode(overridesJson) as Map<String, dynamic>;
      modelParamOverrides = decoded.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      );
    } else {
      modelParamOverrides = await loadDefaultModelParamOverrides();
      await prefs.setString(
        _keyModelParamOverrides,
        jsonEncode(modelParamOverrides),
      );
    }

    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == prefs.getString(_keyThemeMode),
        orElse: () => ThemeMode.system,
      ),
      uiScale: prefs.getDouble(_keyUiScale) ?? 1.0,
      autoRefreshEnabled: prefs.getBool(_keyAutoRefreshEnabled) ?? false,
      autoRefreshIntervalSeconds:
          prefs.getInt(_keyAutoRefreshIntervalSeconds) ??
              AppSettings.defaultAutoRefreshIntervalSeconds,
      serverProfiles: profiles,
      activeProfileId: activeId,
      favouriteModelIds: favouriteIds,
      modelLoadPresets: presets,
      modelParamOverrides: modelParamOverrides,
    );
  }

  Future<void> modify(
    AppSettings Function(AppSettings current) updater,
  ) async {
    final current = state.requireValue;
    final next = updater(current);
    if (next == current) return;

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyThemeMode, next.themeMode.name),
      prefs.setDouble(_keyUiScale, next.uiScale),
      prefs.setBool(_keyAutoRefreshEnabled, next.autoRefreshEnabled),
      prefs.setInt(
        _keyAutoRefreshIntervalSeconds,
        next.autoRefreshIntervalSeconds,
      ),
      prefs.setString(
        _keyServerProfiles,
        ServerProfile.encodeList(next.serverProfiles),
      ),
      prefs.setString(_keyActiveProfileId, next.activeProfileId),
      prefs.setStringList(
        _keyFavouriteModelIds,
        next.favouriteModelIds.toList(),
      ),
      prefs.setString(
        _keyModelLoadPresets,
        ModelLoadPreset.encodeList(next.modelLoadPresets),
      ),
      prefs.setString(
        _keyModelParamOverrides,
        jsonEncode(next.modelParamOverrides),
      ),
    ]);
    state = AsyncData(next);
  }

  Future<void> setActiveProfile(String profileId) async {
    await modify((s) => s.copyWith(activeProfileId: profileId));
  }

  Future<void> addProfile(ServerProfile profile) async {
    await modify(
      (s) => s.copyWith(serverProfiles: [...s.serverProfiles, profile]),
    );
  }

  Future<void> updateProfile(ServerProfile updated) async {
    await modify((s) => s.copyWith(
          serverProfiles:
              s.serverProfiles.map((p) => p.id == updated.id ? updated : p).toList(),
        ));
  }

  Future<void> removeProfile(String profileId) async {
    await modify((s) {
      final remaining = s.serverProfiles.where((p) => p.id != profileId).toList();
      if (remaining.isEmpty) return s;
      final newActiveId =
          s.activeProfileId == profileId ? remaining.first.id : s.activeProfileId;
      return s.copyWith(serverProfiles: remaining, activeProfileId: newActiveId);
    });
  }

  Future<void> addPreset(ModelLoadPreset preset) async {
    await modify(
      (s) => s.copyWith(modelLoadPresets: [...s.modelLoadPresets, preset]),
    );
  }

  Future<void> updatePreset(ModelLoadPreset updated) async {
    await modify((s) => s.copyWith(
          modelLoadPresets: s.modelLoadPresets
              .map((p) => p.id == updated.id ? updated : p)
              .toList(),
        ));
  }

  Future<void> removePreset(String presetId) async {
    await modify((s) => s.copyWith(
          modelLoadPresets:
              s.modelLoadPresets.where((p) => p.id != presetId).toList(),
        ));
  }

  Future<void> toggleFavourite(String modelId) async {
    await modify((s) {
      final updated = Set<String>.of(s.favouriteModelIds);
      if (!updated.remove(modelId)) updated.add(modelId);
      return s.copyWith(favouriteModelIds: updated);
    });
  }

  String exportSettings() {
    final current = state.requireValue;
    return const JsonEncoder.withIndent('  ').convert(current.toJson());
  }

  Future<void> importSettings(String jsonString) async {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    final imported = AppSettings.fromJson(map);

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyThemeMode, imported.themeMode.name),
      prefs.setDouble(_keyUiScale, imported.uiScale),
      prefs.setBool(_keyAutoRefreshEnabled, imported.autoRefreshEnabled),
      prefs.setInt(
        _keyAutoRefreshIntervalSeconds,
        imported.autoRefreshIntervalSeconds,
      ),
      prefs.setString(
        _keyServerProfiles,
        ServerProfile.encodeList(imported.serverProfiles),
      ),
      prefs.setString(_keyActiveProfileId, imported.activeProfileId),
      prefs.setStringList(
        _keyFavouriteModelIds,
        imported.favouriteModelIds.toList(),
      ),
      prefs.setString(
        _keyModelLoadPresets,
        ModelLoadPreset.encodeList(imported.modelLoadPresets),
      ),
      prefs.setString(
        _keyModelParamOverrides,
        jsonEncode(imported.modelParamOverrides),
      ),
    ]);
    state = AsyncData(imported);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final defaultOverrides = await loadDefaultModelParamOverrides();
    final defaults = AppSettings(
      serverProfiles: [ServerProfile.createDefault()],
      modelParamOverrides: defaultOverrides,
    );
    await Future.wait([
      prefs.setString(
        _keyServerProfiles,
        ServerProfile.encodeList(defaults.serverProfiles),
      ),
      prefs.setString(_keyActiveProfileId, defaults.activeProfileId),
      prefs.setString(
        _keyModelParamOverrides,
        jsonEncode(defaults.modelParamOverrides),
      ),
    ]);
    state = AsyncData(defaults);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
