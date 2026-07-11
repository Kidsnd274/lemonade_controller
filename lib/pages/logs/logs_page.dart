import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/providers/log_providers.dart';
import 'package:lemonade_controller/providers/service_providers.dart';

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});
  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String? _severity;
  String? _tag;
  bool _autoScroll = true;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(logsProvider);
    final profile = ref.watch(activeServerProfileProvider);
    final hasCredentials =
        profile.bearerToken?.isNotEmpty == true ||
        profile.customHeaders.isNotEmpty;
    final severities = state.entries.map((e) => e.severity).toSet().toList()
      ..sort();
    final tags =
        state.entries
            .map((e) => e.tag)
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final query = _search.text.toLowerCase();
    final visible = state.entries.where((entry) {
      return (_severity == null || entry.severity == _severity) &&
          (_tag == null || entry.tag == _tag) &&
          (query.isEmpty || entry.line.toLowerCase().contains(query));
    }).toList();
    if (_autoScroll && visible.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
    return Column(
      children: [
        if (kIsWeb && hasCredentials)
          const MaterialBanner(
            content: Text(
              'Browsers cannot attach custom authorization headers to WebSockets. '
              'Configure your proxy to use cookies or allow the log route.',
            ),
            actions: [SizedBox.shrink()],
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ConnectionChip(status: state.status),
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search logs',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              DropdownButton<String?>(
                value: _severity,
                hint: const Text('All severities'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All severities'),
                  ),
                  for (final value in severities)
                    DropdownMenuItem(value: value, child: Text(value)),
                ],
                onChanged: (value) => setState(() => _severity = value),
              ),
              DropdownButton<String?>(
                value: _tag,
                hint: const Text('All tags'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All tags')),
                  for (final value in tags)
                    DropdownMenuItem(value: value, child: Text(value)),
                ],
                onChanged: (value) => setState(() => _tag = value),
              ),
              IconButton(
                onPressed: () => setState(() => _autoScroll = !_autoScroll),
                tooltip: _autoScroll ? 'Pause autoscroll' : 'Resume autoscroll',
                icon: Icon(
                  _autoScroll ? Icons.pause : Icons.vertical_align_bottom,
                ),
              ),
              IconButton(
                onPressed: () => ref.read(logsProvider.notifier).clear(),
                tooltip: 'Clear local logs',
                icon: const Icon(Icons.clear_all),
              ),
              IconButton(
                onPressed: () => ref.read(logsProvider.notifier).connect(),
                tooltip: 'Reconnect',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (state.error != null && state.entries.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text(state.error!)),
        Expanded(
          child: SelectionArea(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final entry = visible[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    entry.line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color:
                          entry.severity == 'Error' || entry.severity == 'Fatal'
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  final LogConnectionStatus status;
  const _ConnectionChip({required this.status});
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      status == LogConnectionStatus.connected ? Icons.check_circle : Icons.sync,
      size: 16,
      color: status == LogConnectionStatus.connected ? Colors.green : null,
    ),
    label: Text(status.name),
  );
}
