import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/server_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const defaultBaseUrl = 'http://localhost:8020/api/v1';
  static const defaultAutoRefreshIntervalSeconds = 60;

  final ThemeMode themeMode;
  final bool autoRefreshEnabled;
  final int autoRefreshIntervalSeconds;
  final List<ServerProfile> serverProfiles;
  final String activeProfileId;
  final Set<String> favouriteModelIds;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.autoRefreshEnabled = false,
    this.autoRefreshIntervalSeconds = defaultAutoRefreshIntervalSeconds,
    this.serverProfiles = const [],
    this.activeProfileId = 'default',
    this.favouriteModelIds = const {},
  });

  ServerProfile get activeProfile {
    if (serverProfiles.isEmpty) return ServerProfile.createDefault();
    return serverProfiles.firstWhere(
      (p) => p.id == activeProfileId,
      orElse: () => serverProfiles.first,
    );
  }

  String get baseUrl => activeProfile.baseUrl;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? autoRefreshEnabled,
    int? autoRefreshIntervalSeconds,
    List<ServerProfile>? serverProfiles,
    String? activeProfileId,
    Set<String>? favouriteModelIds,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      autoRefreshEnabled: autoRefreshEnabled ?? this.autoRefreshEnabled,
      autoRefreshIntervalSeconds:
          autoRefreshIntervalSeconds ?? this.autoRefreshIntervalSeconds,
      serverProfiles: serverProfiles ?? this.serverProfiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      favouriteModelIds: favouriteModelIds ?? this.favouriteModelIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          themeMode == other.themeMode &&
          autoRefreshEnabled == other.autoRefreshEnabled &&
          autoRefreshIntervalSeconds == other.autoRefreshIntervalSeconds &&
          activeProfileId == other.activeProfileId &&
          _profileListEquals(serverProfiles, other.serverProfiles) &&
          _setEquals(favouriteModelIds, other.favouriteModelIds);

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

  @override
  int get hashCode => Object.hash(
        themeMode,
        autoRefreshEnabled,
        autoRefreshIntervalSeconds,
        activeProfileId,
        Object.hashAll(serverProfiles),
        Object.hashAll(favouriteModelIds),
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

  // Legacy key for migration
  static const _keyBaseUrl = 'base_url';

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

    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == prefs.getString(_keyThemeMode),
        orElse: () => ThemeMode.system,
      ),
      autoRefreshEnabled: prefs.getBool(_keyAutoRefreshEnabled) ?? false,
      autoRefreshIntervalSeconds:
          prefs.getInt(_keyAutoRefreshIntervalSeconds) ??
              AppSettings.defaultAutoRefreshIntervalSeconds,
      serverProfiles: profiles,
      activeProfileId: activeId,
      favouriteModelIds: favouriteIds,
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

  Future<void> toggleFavourite(String modelId) async {
    await modify((s) {
      final updated = Set<String>.of(s.favouriteModelIds);
      if (!updated.remove(modelId)) updated.add(modelId);
      return s.copyWith(favouriteModelIds: updated);
    });
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final defaults = AppSettings(
      serverProfiles: [ServerProfile.createDefault()],
    );
    await Future.wait([
      prefs.setString(
        _keyServerProfiles,
        ServerProfile.encodeList(defaults.serverProfiles),
      ),
      prefs.setString(_keyActiveProfileId, defaults.activeProfileId),
    ]);
    state = AsyncData(defaults);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
