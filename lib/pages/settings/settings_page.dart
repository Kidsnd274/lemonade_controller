import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/server_profile.dart';
import 'package:lemonade_controller/services/settings_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading settings: $e')),
      data: (settings) => _SettingsContent(settings: settings),
    );
  }
}

class _SettingsContent extends ConsumerWidget {
  final AppSettings settings;
  const _SettingsContent({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _SectionHeader(title: 'Appearance'),
        ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: const Text('Theme'),
          subtitle: Text(
            settings.themeMode.name[0].toUpperCase() +
                settings.themeMode.name.substring(1),
          ),
          trailing: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_suggest_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (selected) {
              ref
                  .read(settingsProvider.notifier)
                  .modify((s) => s.copyWith(themeMode: selected.first));
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.zoom_in_outlined),
          title: const Text('UI Scale'),
          subtitle: Text('${(settings.uiScale * 100).round()}%'),
          trailing: SizedBox(
            width: 200,
            child: Slider(
              value: settings.uiScale,
              min: 0.75,
              max: 1.25,
              divisions: 10,
              label: '${(settings.uiScale * 100).round()}%',
              onChanged: (value) {
                ref
                    .read(settingsProvider.notifier)
                    .modify((s) => s.copyWith(uiScale: value));
              },
            ),
          ),
        ),
        const Divider(),
        _SectionHeader(title: 'Server Profiles'),
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: const Text('Active Server'),
          subtitle: Text(
            '${settings.activeProfile.name} — ${settings.activeProfile.displayAddress}',
          ),
        ),
        for (final profile in settings.serverProfiles)
          _ServerProfileTile(
            profile: profile,
            isActive: profile.id == settings.activeProfileId,
            isOnly: settings.serverProfiles.length == 1,
            onEdit: () => _editProfile(context, ref, profile),
            onDelete: () => _deleteProfile(context, ref, profile),
            onSetActive: () => ref
                .read(settingsProvider.notifier)
                .setActiveProfile(profile.id),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OutlinedButton.icon(
            onPressed: () => _addProfile(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Server'),
          ),
        ),
        const Divider(),
        _SectionHeader(title: 'Auto Refresh'),
        SwitchListTile(
          secondary: const Icon(Icons.sync_outlined),
          title: const Text('Auto Refresh Models'),
          subtitle: Text(settings.autoRefreshEnabled ? 'Enabled' : 'Disabled'),
          value: settings.autoRefreshEnabled,
          onChanged: (value) {
            ref
                .read(settingsProvider.notifier)
                .modify((s) => s.copyWith(autoRefreshEnabled: value));
          },
        ),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: const Text('Refresh Interval'),
          subtitle: Text('${settings.autoRefreshIntervalSeconds} seconds'),
          enabled: settings.autoRefreshEnabled,
          onTap: settings.autoRefreshEnabled
              ? () => _editAutoRefreshInterval(
                  context,
                  ref,
                  settings.autoRefreshIntervalSeconds,
                )
              : null,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          onTap: () => _showAboutPopup(context),
        ),
        const Divider(),
        _SectionHeader(title: 'Danger Zone'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OutlinedButton.icon(
            onPressed: () => _resetSettings(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            icon: const Icon(Icons.restore),
            label: const Text('Reset All Settings'),
          ),
        ),
      ],
    );
  }

  Future<void> _resetSettings(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'This will reset all settings to their defaults, including server '
          'profiles and favourites. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(settingsProvider.notifier).reset();
    }
  }

  Future<void> _showAboutPopup(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    final dartVersion = Platform.version.split(' ').first;
    final versionFull = Platform.version;
    final arch =
        RegExp(r'on "(.+)"').firstMatch(versionFull)?.group(1) ??
        Platform.operatingSystem;

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final labelStyle = theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );
        final valueStyle = theme.textTheme.bodyMedium;

        return AlertDialog(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 80,
                    height: 80,
                  ),
                ),
                const SizedBox(height: 16),
                Text(info.appName, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'v${info.version}+${info.buildNumber}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _AboutInfoRow(
                        icon: Icons.inventory_2_outlined,
                        label: 'Package',
                        value: info.packageName,
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      ),
                      const SizedBox(height: 10),
                      _AboutInfoRow(
                        icon: Icons.desktop_windows_outlined,
                        label: 'Platform',
                        value:
                            '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      ),
                      const SizedBox(height: 10),
                      _AboutInfoRow(
                        icon: Icons.memory_outlined,
                        label: 'Architecture',
                        value: arch,
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      ),
                      const SizedBox(height: 10),
                      _AboutInfoRow(
                        icon: Icons.developer_board_outlined,
                        label: 'Processors',
                        value: '${Platform.numberOfProcessors}',
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      ),
                      const SizedBox(height: 10),
                      _AboutInfoRow(
                        icon: Icons.code_outlined,
                        label: 'Dart SDK',
                        value: dartVersion,
                        labelStyle: labelStyle,
                        valueStyle: valueStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addProfile(BuildContext context, WidgetRef ref) async {
    final result = await _showProfileDialog(context);
    if (result != null) {
      final profile = ServerProfile(
        id: ServerProfile.generateId(),
        name: result.name,
        baseUrl: result.url,
      );
      await ref.read(settingsProvider.notifier).addProfile(profile);
    }
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    ServerProfile profile,
  ) async {
    final result = await _showProfileDialog(
      context,
      initialName: profile.name,
      initialUrl: profile.baseUrl,
      title: 'Edit Server',
    );
    if (result != null) {
      await ref
          .read(settingsProvider.notifier)
          .updateProfile(
            profile.copyWith(name: result.name, baseUrl: result.url),
          );
    }
  }

  Future<void> _deleteProfile(
    BuildContext context,
    WidgetRef ref,
    ServerProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Server'),
        content: Text('Remove "${profile.name}" from server profiles?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            autofocus: true,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(settingsProvider.notifier).removeProfile(profile.id);
    }
  }

  Future<_ProfileDialogResult?> _showProfileDialog(
    BuildContext context, {
    String? initialName,
    String? initialUrl,
    String title = 'Add Server',
  }) async {
    final nameController = TextEditingController(text: initialName ?? '');
    final urlController = TextEditingController(
      text: initialUrl ?? 'http://localhost:8020/api/v1',
    );
    void submitProfile(BuildContext dialogContext) {
      if (nameController.text.trim().isEmpty) return;
      Navigator.pop(
        dialogContext,
        _ProfileDialogResult(
          name: nameController.text.trim(),
          url: urlController.text.trim(),
        ),
      );
    }

    return showDialog<_ProfileDialogResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Production Server',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (_) => submitProfile(context),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'API Base URL',
                hintText: 'http://host:port/api/v1',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => submitProfile(context),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => submitProfile(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editAutoRefreshInterval(
    BuildContext context,
    WidgetRef ref,
    int currentInterval,
  ) async {
    final controller = TextEditingController(text: currentInterval.toString());
    final newInterval = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refresh Interval'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            suffixText: 'seconds',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onSubmitted: (value) {
            final parsed = int.tryParse(value);
            if (parsed != null) Navigator.pop(context, parsed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text);
              if (parsed != null) Navigator.pop(context, parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newInterval != null) {
      ref
          .read(settingsProvider.notifier)
          .modify((s) => s.copyWith(autoRefreshIntervalSeconds: newInterval));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ServerProfileTile extends StatelessWidget {
  final ServerProfile profile;
  final bool isActive;
  final bool isOnly;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetActive;

  const _ServerProfileTile({
    required this.profile,
    required this.isActive,
    required this.isOnly,
    required this.onEdit,
    required this.onDelete,
    required this.onSetActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Icon(
        isActive ? Icons.check_circle : Icons.circle_outlined,
        color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
      title: Text(
        profile.name,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isActive ? FontWeight.w600 : null,
        ),
      ),
      subtitle: Text(profile.displayAddress),
      onTap: isActive ? null : onSetActive,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          if (!isOnly)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: colorScheme.error,
              ),
              onPressed: onDelete,
              tooltip: 'Remove',
            ),
        ],
      ),
    );
  }
}

class _ProfileDialogResult {
  final String name;
  final String url;
  const _ProfileDialogResult({required this.name, required this.url});
}

class _AboutInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _AboutInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: labelStyle?.color),
        const SizedBox(width: 8),
        SizedBox(width: 90, child: Text(label, style: labelStyle)),
        Expanded(
          child: Text(
            value,
            style: valueStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
