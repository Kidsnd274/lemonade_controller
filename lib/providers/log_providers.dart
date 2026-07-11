import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:lemonade_controller/models/log_entry.dart';
import 'package:lemonade_controller/models/server_profile.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/providers/service_providers.dart';
import 'package:lemonade_controller/services/log_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum LogConnectionStatus { unavailable, connecting, connected, disconnected }

class LogsState {
  final List<LogEntry> entries;
  final LogConnectionStatus status;
  final String? error;

  const LogsState({
    this.entries = const [],
    this.status = LogConnectionStatus.connecting,
    this.error,
  });
}

final logsProvider = StateNotifierProvider.autoDispose<LogsNotifier, LogsState>(
  (ref) {
    final profile = ref.watch(activeServerProfileProvider);
    final health = ref.watch(healthInfoProvider).value;
    final uri = _logUri(profile, health?.websocketPort ?? 0);
    return LogsNotifier(profile, uri);
  },
);

Uri? _logUri(ServerProfile profile, int websocketPort) {
  final override = profile.webSocketUrlOverride?.trim();
  if (override?.isNotEmpty == true) return Uri.tryParse(override!);
  if (websocketPort <= 0) return null;
  final base = Uri.tryParse(profile.baseUrl);
  if (base == null || base.host.isEmpty) return null;
  return Uri(
    scheme: base.scheme == 'https' ? 'wss' : 'ws',
    host: base.host,
    port: websocketPort,
    path: '/logs/stream',
  );
}

class LogsNotifier extends StateNotifier<LogsState> {
  final ServerProfile profile;
  final Uri? uri;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  int? _lastSeq;

  LogsNotifier(this.profile, this.uri)
    : super(
        uri == null
            ? const LogsState(
                status: LogConnectionStatus.unavailable,
                error: 'Log streaming is not available on this server.',
              )
            : const LogsState(),
      ) {
    if (uri != null) connect();
  }

  Map<String, String> get _headers {
    final headers = {...profile.customHeaders};
    if (profile.bearerToken?.trim().isNotEmpty == true) {
      headers.removeWhere((key, _) => key.toLowerCase() == 'authorization');
      headers['Authorization'] = 'Bearer ${profile.bearerToken!.trim()}';
    }
    return headers;
  }

  Future<void> connect() async {
    if (uri == null) return;
    await _subscription?.cancel();
    await _channel?.sink.close();
    state = LogsState(
      entries: state.entries,
      status: LogConnectionStatus.connecting,
    );
    try {
      final channel = connectLogSocket(uri!, _headers);
      _channel = channel;
      await channel.ready;
      _reconnectAttempt = 0;
      state = LogsState(
        entries: state.entries,
        status: LogConnectionStatus.connected,
      );
      channel.sink.add(
        jsonEncode({'type': 'logs.subscribe', 'after_seq': _lastSeq}),
      );
      _subscription = channel.stream.listen(
        _onMessage,
        onError: (Object error) => _onDisconnected(error.toString()),
        onDone: () => _onDisconnected('Log connection closed.'),
      );
    } catch (error) {
      _onDisconnected(error.toString());
    }
  }

  void _onMessage(dynamic message) {
    try {
      final json = jsonDecode(message.toString()) as Map<String, dynamic>;
      final type = json['type'];
      if (type == 'logs.snapshot') {
        _append(
          (json['entries'] as List? ?? const []).map(
            (item) => LogEntry.fromJson((item as Map).cast<String, dynamic>()),
          ),
        );
      } else if (type == 'logs.entry' && json['entry'] is Map) {
        _append([
          LogEntry.fromJson((json['entry'] as Map).cast<String, dynamic>()),
        ]);
      } else if (type == 'error') {
        state = LogsState(
          entries: state.entries,
          status: state.status,
          error: json['message']?.toString() ?? 'Log stream error.',
        );
      }
    } catch (_) {
      // Ignore malformed individual messages without dropping the stream.
    }
  }

  void _append(Iterable<LogEntry> incoming) {
    final bySeq = <int, LogEntry>{
      for (final entry in state.entries) entry.seq: entry,
    };
    for (final entry in incoming) {
      bySeq[entry.seq] = entry;
      if (_lastSeq == null || entry.seq > _lastSeq!) _lastSeq = entry.seq;
    }
    final entries = bySeq.values.toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    state = LogsState(
      entries: entries.length > 5000
          ? entries.sublist(entries.length - 5000)
          : entries,
      status: LogConnectionStatus.connected,
    );
  }

  void _onDisconnected(String error) {
    state = LogsState(
      entries: state.entries,
      status: LogConnectionStatus.disconnected,
      error: error,
    );
    _reconnectTimer?.cancel();
    final seconds = (1 << _reconnectAttempt.clamp(0, 5)).clamp(1, 30);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), connect);
  }

  void clear() => state = LogsState(status: state.status, error: state.error);

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
