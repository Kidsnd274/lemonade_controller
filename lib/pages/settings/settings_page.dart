import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/services/settings_service.dart';

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
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Appearance',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
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
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Server',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: const Text('API Base URL'),
          subtitle: Text(settings.baseUrl),
          onTap: () => _editBaseUrl(context, ref, settings.baseUrl),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Auto Refresh',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
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
      ],
    );
  }

  Future<void> _editBaseUrl(
    BuildContext context,
    WidgetRef ref,
    String currentUrl,
  ) async {
    final controller = TextEditingController(text: currentUrl);
    final newUrl = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Base URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.7:8020/api/v1',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newUrl != null && newUrl.isNotEmpty) {
      ref
          .read(settingsProvider.notifier)
          .modify((s) => s.copyWith(baseUrl: newUrl));
    }
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
