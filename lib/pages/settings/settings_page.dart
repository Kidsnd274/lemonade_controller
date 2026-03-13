import 'package:flutter/material.dart';
import 'package:lemonade_controller/services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  final SettingsService settings;
  const SettingsPage({super.key, required this.settings});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<String> _baseUrlFuture;
  late Future<bool> _autoRefreshEnabledFuture;
  late Future<int> _autoRefreshIntervalFuture;

  @override
  void initState() {
    super.initState();
    _baseUrlFuture = widget.settings.getBaseUrl();
    _autoRefreshEnabledFuture = widget.settings.getAutoRefreshEnabled();
    _autoRefreshIntervalFuture = widget.settings.getAutoRefreshIntervalSeconds();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Base URL Setting
          FutureBuilder<String>(
            future: _baseUrlFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              return ListTile(
                title: const Text('API Base URL'),
                subtitle: Text(snapshot.data!),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final newUrl = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Enter API Base URL'),
                        content: TextField(
                          decoration: const InputDecoration(hintText: 'Base URL'),
                          controller: TextEditingController(text: snapshot.data),
                          onSubmitted: (value) => Navigator.pop(context, value),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, snapshot.data),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                    if (newUrl != null && newUrl.isNotEmpty) {
                      await widget.settings.setBaseUrl(newUrl);
                      setState(() {
                        _baseUrlFuture = widget.settings.getBaseUrl();
                      });
                    }
                  },
                ),
              );
            },
          ),
          // Auto Refresh Enabled
          FutureBuilder<bool>(
            future: _autoRefreshEnabledFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              return SwitchListTile(
                title: const Text('Auto Refresh Models'),
                value: snapshot.data!,
                onChanged: (value) async {
                  await widget.settings.setAutoRefreshEnabled(value);
                  setState(() {
                    _autoRefreshEnabledFuture = widget.settings.getAutoRefreshEnabled();
                  });
                },
              );
            },
          ),
          // Auto Refresh Interval
          FutureBuilder<int>(
            future: _autoRefreshIntervalFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              return ListTile(
                title: const Text('Auto Refresh Interval (seconds)'),
                subtitle: Text(snapshot.data.toString()),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final newInterval = await showDialog<int?>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Enter Refresh Interval'),
                        content: TextField(
                          decoration: const InputDecoration(hintText: 'Seconds'),
                          controller: TextEditingController(text: snapshot.data.toString()),
                          keyboardType: TextInputType.number,
                          onSubmitted: (value) {
                            final parsed = int.tryParse(value);
                            Navigator.pop(context, parsed);
                          },
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, snapshot.data),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                    if (newInterval != null) {
                      await widget.settings.setAutoRefreshIntervalSeconds(newInterval);
                      setState(() {
                        _autoRefreshIntervalFuture = widget.settings.getAutoRefreshIntervalSeconds();
                      });
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}