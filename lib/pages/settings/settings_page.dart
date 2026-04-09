import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/providers/service_providers.dart';
import 'package:lemonade_controller/services/settings_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  final SettingsService settings;
  const SettingsPage({super.key, required this.settings});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _loading = true;
  String _baseUrl = '';
  bool _autoRefreshEnabled = false;
  int _autoRefreshInterval = 60;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final results = await Future.wait([
      widget.settings.getBaseUrl(),
      widget.settings.getAutoRefreshEnabled(),
      widget.settings.getAutoRefreshIntervalSeconds(),
    ]);
    setState(() {
      _baseUrl = results[0] as String;
      _autoRefreshEnabled = results[1] as bool;
      _autoRefreshInterval = results[2] as int;
      _loading = false;
    });
  }

  Future<void> _editBaseUrl() async {
    final controller = TextEditingController(text: _baseUrl);
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
      await widget.settings.setBaseUrl(newUrl);
      setState(() => _baseUrl = newUrl);
    }
  }

  Future<void> _editAutoRefreshInterval() async {
    final controller = TextEditingController(text: _autoRefreshInterval.toString());
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
      await widget.settings.setAutoRefreshIntervalSeconds(newInterval);
      setState(() => _autoRefreshInterval = newInterval);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    final themeMode = ref.watch(themeModeProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Appearance', style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          )),
        ),
        ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: const Text('Theme'),
          subtitle: Text(themeMode.name[0].toUpperCase() + themeMode.name.substring(1)),
          trailing: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_suggest_outlined)),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined)),
            ],
            selected: {themeMode},
            onSelectionChanged: (selected) {
              ref.read(themeModeProvider.notifier).setThemeMode(selected.first);
            },
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Server', style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          )),
        ),
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: const Text('API Base URL'),
          subtitle: Text(_baseUrl),
          onTap: _editBaseUrl,
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Auto Refresh', style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          )),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.sync_outlined),
          title: const Text('Auto Refresh Models'),
          subtitle: Text(_autoRefreshEnabled ? 'Enabled' : 'Disabled'),
          value: _autoRefreshEnabled,
          onChanged: (value) async {
            await widget.settings.setAutoRefreshEnabled(value);
            setState(() => _autoRefreshEnabled = value);
          },
        ),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: const Text('Refresh Interval'),
          subtitle: Text('$_autoRefreshInterval seconds'),
          enabled: _autoRefreshEnabled,
          onTap: _autoRefreshEnabled ? _editAutoRefreshInterval : null,
        ),
      ],
    );
  }
}
