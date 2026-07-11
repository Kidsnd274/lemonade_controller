import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';
import 'package:lemonade_controller/models/log_entry.dart';
import 'package:lemonade_controller/providers/log_providers.dart';

enum InferencePhase { received, promptProcessing, generating, completed }

class InferenceTaskActivity {
  final String key;
  final int? taskId;
  final int? slotId;
  final InferencePhase phase;
  final DateTime startedAt;
  final DateTime updatedAt;
  final double? promptProgress;
  final int? promptTokensProcessed;
  final double? promptTokensPerSecond;
  final double? promptProgressPerSecond;
  final int? decodedTokens;
  final double? generationTokensPerSecond;
  final double? averageGenerationTokensPerSecond;

  const InferenceTaskActivity({
    required this.key,
    required this.phase,
    required this.startedAt,
    required this.updatedAt,
    this.taskId,
    this.slotId,
    this.promptProgress,
    this.promptTokensProcessed,
    this.promptTokensPerSecond,
    this.promptProgressPerSecond,
    this.decodedTokens,
    this.generationTokensPerSecond,
    this.averageGenerationTokensPerSecond,
  });

  InferenceTaskActivity copyWith({
    String? key,
    int? taskId,
    int? slotId,
    InferencePhase? phase,
    DateTime? startedAt,
    DateTime? updatedAt,
    double? promptProgress,
    int? promptTokensProcessed,
    double? promptTokensPerSecond,
    double? promptProgressPerSecond,
    int? decodedTokens,
    double? generationTokensPerSecond,
    double? averageGenerationTokensPerSecond,
  }) => InferenceTaskActivity(
    key: key ?? this.key,
    taskId: taskId ?? this.taskId,
    slotId: slotId ?? this.slotId,
    phase: phase ?? this.phase,
    startedAt: startedAt ?? this.startedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    promptProgress: promptProgress ?? this.promptProgress,
    promptTokensProcessed: promptTokensProcessed ?? this.promptTokensProcessed,
    promptTokensPerSecond: promptTokensPerSecond ?? this.promptTokensPerSecond,
    promptProgressPerSecond:
        promptProgressPerSecond ?? this.promptProgressPerSecond,
    decodedTokens: decodedTokens ?? this.decodedTokens,
    generationTokensPerSecond:
        generationTokensPerSecond ?? this.generationTokensPerSecond,
    averageGenerationTokensPerSecond:
        averageGenerationTokensPerSecond ??
        this.averageGenerationTokensPerSecond,
  );

  Duration elapsedAt(DateTime now) {
    final elapsed = now.difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Duration? promptEtaAt(DateTime now) {
    final progress = promptProgress;
    final rate = promptProgressPerSecond;
    if (progress == null || rate == null || rate <= 0 || progress >= 1) {
      return null;
    }
    final secondsAtUpdate = (1 - progress) / rate;
    final sinceUpdate = now.difference(updatedAt).inMilliseconds / 1000;
    final remaining = secondsAtUpdate - sinceUpdate;
    if (remaining <= 0) return Duration.zero;
    return Duration(milliseconds: (remaining * 1000).round());
  }
}

class InferenceCompletion {
  final InferenceTaskActivity task;
  final DateTime completedAt;
  final String? model;
  final int? totalTokens;
  final int? inputTokens;
  final int? outputTokens;
  final double? timeToFirstTokenSeconds;
  final double? tokensPerSecond;

  const InferenceCompletion({
    required this.task,
    required this.completedAt,
    this.model,
    this.totalTokens,
    this.inputTokens,
    this.outputTokens,
    this.timeToFirstTokenSeconds,
    this.tokensPerSecond,
  });

  InferenceCompletion copyWith({
    String? model,
    int? totalTokens,
    int? inputTokens,
    int? outputTokens,
    double? timeToFirstTokenSeconds,
    double? tokensPerSecond,
  }) => InferenceCompletion(
    task: task,
    completedAt: completedAt,
    model: model ?? this.model,
    totalTokens: totalTokens ?? this.totalTokens,
    inputTokens: inputTokens ?? this.inputTokens,
    outputTokens: outputTokens ?? this.outputTokens,
    timeToFirstTokenSeconds:
        timeToFirstTokenSeconds ?? this.timeToFirstTokenSeconds,
    tokensPerSecond: tokensPerSecond ?? this.tokensPerSecond,
  );
}

class InferenceActivityState {
  final LogConnectionStatus connectionStatus;
  final bool formatSupported;
  final List<InferenceTaskActivity> activeRequests;
  final InferenceCompletion? recentCompletion;
  final DateTime now;

  const InferenceActivityState({
    this.connectionStatus = LogConnectionStatus.connecting,
    this.formatSupported = false,
    this.activeRequests = const [],
    this.recentCompletion,
    required this.now,
  });

  bool get shouldShow =>
      connectionStatus == LogConnectionStatus.connected && formatSupported;

  int countInPhase(InferencePhase phase) =>
      activeRequests.where((request) => request.phase == phase).length;
}

class InferenceActivityTracker {
  static const staleActivityAge = Duration(minutes: 5);
  static const completionDisplayAge = Duration(seconds: 8);
  static const telemetryMatchWindow = Duration(seconds: 2);

  static final _launchPattern = RegExp(
    r'slot\s+launch_slot_:\s+id\s+(\d+)\s*\|\s*task\s+(\d+)\s*\|\s*processing task',
  );
  static final _promptPattern = RegExp(
    r'slot\s+print_timing:\s+id\s+(\d+)\s*\|\s*task\s+(\d+)\s*\|\s*prompt processing,\s*n_tokens\s*=\s*(\d+),\s*progress\s*=\s*([0-9.]+),\s*t\s*=\s*([0-9.]+)\s*s\s*/\s*([0-9.]+)\s+tokens per second',
  );
  static final _generationPattern = RegExp(
    r'slot\s+print_timing:\s+id\s+(\d+)\s*\|\s*task\s+(\d+)\s*\|\s*n_decoded\s*=\s*(\d+),\s*tg\s*=\s*([0-9.]+)\s*t/s,\s*tg_3s\s*=\s*([0-9.]+)\s*t/s',
  );
  static final _releasePattern = RegExp(
    r'slot\s+release:\s+id\s+(\d+)\s*\|\s*task\s+(\d+)\s*\|\s*stop processing',
  );
  static final _telemetryPattern = RegExp(
    r'Inference completed:\s*model=(.+?),\s*tokens=(\d+)\s*\(in=(\d+),\s*out=(\d+)\),\s*ttft=([0-9.]+)s,\s*tps=([0-9.]+)',
  );
  static final _lineTimestampPattern = RegExp(
    r'^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2}\.\d+)',
  );

  final DateTime Function() _clock;
  final Map<String, InferenceTaskActivity> _active = {};
  final List<String> _pendingKeys = [];
  final List<InferenceCompletion> _unmatchedCompletions = [];
  int? _lastSequence;
  bool _formatSupported = false;
  LogConnectionStatus _connectionStatus = LogConnectionStatus.connecting;
  InferenceCompletion? _recentCompletion;

  InferenceActivityTracker({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  InferenceActivityState synchronize(LogsState logs) {
    if (logs.status != LogConnectionStatus.connected) {
      _resetForConnection(logs.status);
      return snapshot();
    }

    if (_connectionStatus != LogConnectionStatus.connected) {
      _lastSequence = null;
      _active.clear();
      _pendingKeys.clear();
      _unmatchedCompletions.clear();
      _recentCompletion = null;
      _formatSupported = false;
    }
    _connectionStatus = logs.status;

    final incoming =
        logs.entries
            .where(
              (entry) => _lastSequence == null || entry.seq > _lastSequence!,
            )
            .toList()
          ..sort((a, b) => a.seq.compareTo(b.seq));
    for (final entry in incoming) {
      ingest(entry);
      if (_lastSequence == null || entry.seq > _lastSequence!) {
        _lastSequence = entry.seq;
      }
    }
    _prune(_clock());
    return snapshot();
  }

  bool ingest(LogEntry entry) {
    final line = entry.line;
    final eventTime = _eventTime(entry);

    if (line.contains('POST /api/v1/chat/completions')) {
      final key = 'pending:${entry.seq}';
      _active[key] = InferenceTaskActivity(
        key: key,
        phase: InferencePhase.received,
        startedAt: eventTime,
        updatedAt: eventTime,
      );
      _pendingKeys.add(key);
      _recentCompletion = null;
      return true;
    }

    if (line.contains('launch_slot_')) {
      final match = _launchPattern.firstMatch(line);
      if (match == null) return false;
      _formatSupported = true;
      final slotId = int.parse(match.group(1)!);
      final taskId = int.parse(match.group(2)!);
      final pending = _takePending();
      final key = 'task:$taskId';
      _active[key] = InferenceTaskActivity(
        key: key,
        taskId: taskId,
        slotId: slotId,
        phase: InferencePhase.promptProcessing,
        startedAt: pending?.startedAt ?? eventTime,
        updatedAt: eventTime,
      );
      return true;
    }

    if (line.contains('prompt processing')) {
      final match = _promptPattern.firstMatch(line);
      if (match == null) return false;
      _formatSupported = true;
      final slotId = int.parse(match.group(1)!);
      final taskId = int.parse(match.group(2)!);
      final tokens = int.parse(match.group(3)!);
      final parsedProgress = double.parse(
        match.group(4)!,
      ).clamp(0.0, 1.0).toDouble();
      final tokensPerSecond = double.parse(match.group(6)!);
      final key = 'task:$taskId';
      final previous = _active[key];
      final progress = previous?.promptProgress == null
          ? parsedProgress
          : parsedProgress.clamp(previous!.promptProgress!, 1.0).toDouble();
      double? smoothedRate = previous?.promptProgressPerSecond;
      if (previous?.promptProgress != null &&
          progress > previous!.promptProgress!) {
        final seconds =
            eventTime.difference(previous.updatedAt).inMilliseconds / 1000;
        if (seconds > 0) {
          final sample = (progress - previous.promptProgress!) / seconds;
          smoothedRate = smoothedRate == null
              ? sample
              : smoothedRate * 0.65 + sample * 0.35;
        }
      }
      _active[key] =
          (previous ??
                  InferenceTaskActivity(
                    key: key,
                    taskId: taskId,
                    slotId: slotId,
                    phase: InferencePhase.promptProcessing,
                    startedAt: eventTime,
                    updatedAt: eventTime,
                  ))
              .copyWith(
                taskId: taskId,
                slotId: slotId,
                phase: InferencePhase.promptProcessing,
                updatedAt: eventTime,
                promptProgress: progress,
                promptTokensProcessed: tokens,
                promptTokensPerSecond: tokensPerSecond,
                promptProgressPerSecond: smoothedRate,
              );
      return true;
    }

    if (line.contains('n_decoded')) {
      final match = _generationPattern.firstMatch(line);
      if (match == null) return false;
      _formatSupported = true;
      final slotId = int.parse(match.group(1)!);
      final taskId = int.parse(match.group(2)!);
      final key = 'task:$taskId';
      final previous = _active[key];
      _active[key] =
          (previous ??
                  InferenceTaskActivity(
                    key: key,
                    taskId: taskId,
                    slotId: slotId,
                    phase: InferencePhase.generating,
                    startedAt: eventTime,
                    updatedAt: eventTime,
                  ))
              .copyWith(
                taskId: taskId,
                slotId: slotId,
                phase: InferencePhase.generating,
                updatedAt: eventTime,
                decodedTokens: int.parse(match.group(3)!),
                averageGenerationTokensPerSecond: double.parse(match.group(4)!),
                generationTokensPerSecond: double.parse(match.group(5)!),
              );
      return true;
    }

    if (line.contains('stop processing')) {
      final match = _releasePattern.firstMatch(line);
      if (match == null) return false;
      _formatSupported = true;
      final slotId = int.parse(match.group(1)!);
      final taskId = int.parse(match.group(2)!);
      final key = 'task:$taskId';
      final task =
          (_active.remove(key) ??
                  InferenceTaskActivity(
                    key: key,
                    taskId: taskId,
                    slotId: slotId,
                    phase: InferencePhase.completed,
                    startedAt: eventTime,
                    updatedAt: eventTime,
                  ))
              .copyWith(
                taskId: taskId,
                slotId: slotId,
                phase: InferencePhase.completed,
                updatedAt: eventTime,
              );
      final completion = InferenceCompletion(
        task: task,
        completedAt: eventTime,
      );
      _unmatchedCompletions.add(completion);
      _recentCompletion = completion;
      return true;
    }

    if (line.contains('Inference completed:')) {
      final match = _telemetryPattern.firstMatch(line);
      if (match == null) return false;
      _formatSupported = true;
      _pruneCompletionCandidates(eventTime);
      final candidates = _unmatchedCompletions.where((completion) {
        final difference = eventTime.difference(completion.completedAt).abs();
        return difference <= telemetryMatchWindow;
      }).toList();
      if (candidates.length == 1) {
        final original = candidates.single;
        final enriched = original.copyWith(
          model: match.group(1)!.trim(),
          totalTokens: int.parse(match.group(2)!),
          inputTokens: int.parse(match.group(3)!),
          outputTokens: int.parse(match.group(4)!),
          timeToFirstTokenSeconds: double.parse(match.group(5)!),
          tokensPerSecond: double.parse(match.group(6)!),
        );
        _unmatchedCompletions.remove(original);
        if (_recentCompletion == original) _recentCompletion = enriched;
      }
      return true;
    }

    return false;
  }

  InferenceActivityState tick() {
    _prune(_clock());
    return snapshot();
  }

  InferenceActivityState snapshot() {
    final now = _clock();
    final active = _active.values.toList()
      ..sort((a, b) {
        final byStart = a.startedAt.compareTo(b.startedAt);
        return byStart != 0 ? byStart : a.key.compareTo(b.key);
      });
    final completion =
        _recentCompletion != null &&
            now.difference(_recentCompletion!.completedAt) <=
                completionDisplayAge
        ? _recentCompletion
        : null;
    return InferenceActivityState(
      connectionStatus: _connectionStatus,
      formatSupported: _formatSupported,
      activeRequests: List.unmodifiable(active),
      recentCompletion: completion,
      now: now,
    );
  }

  InferenceTaskActivity? _takePending() {
    while (_pendingKeys.isNotEmpty) {
      final key = _pendingKeys.removeAt(0);
      final pending = _active.remove(key);
      if (pending != null) return pending;
    }
    return null;
  }

  DateTime _eventTime(LogEntry entry) {
    final timestamp = entry.timestamp.trim();
    if (timestamp.isNotEmpty) {
      final parsed =
          DateTime.tryParse(timestamp) ??
          DateTime.tryParse(timestamp.replaceFirst(' ', 'T'));
      if (parsed != null) return parsed;
    }
    final match = _lineTimestampPattern.firstMatch(entry.line);
    if (match != null) {
      final parsed = DateTime.tryParse('${match.group(1)}T${match.group(2)}');
      if (parsed != null) return parsed;
    }
    return _clock();
  }

  void _prune(DateTime now) {
    final staleKeys = _active.entries
        .where(
          (entry) => now.difference(entry.value.updatedAt) > staleActivityAge,
        )
        .map((entry) => entry.key)
        .toSet();
    for (final key in staleKeys) {
      _active.remove(key);
      _pendingKeys.remove(key);
    }
    if (_recentCompletion != null &&
        now.difference(_recentCompletion!.completedAt) > completionDisplayAge) {
      _recentCompletion = null;
    }
    _pruneCompletionCandidates(now);
  }

  void _pruneCompletionCandidates(DateTime now) {
    _unmatchedCompletions.removeWhere(
      (completion) =>
          now.difference(completion.completedAt).abs() > telemetryMatchWindow,
    );
  }

  void _resetForConnection(LogConnectionStatus status) {
    _connectionStatus = status;
    _lastSequence = null;
    _active.clear();
    _pendingKeys.clear();
    _unmatchedCompletions.clear();
    _recentCompletion = null;
    _formatSupported = false;
  }
}

final inferenceActivityProvider =
    StateNotifierProvider.autoDispose<
      InferenceActivityNotifier,
      InferenceActivityState
    >((ref) {
      final tracker = InferenceActivityTracker();
      final notifier = InferenceActivityNotifier(tracker);
      notifier.synchronize(ref.read(logsProvider));
      ref.listen<LogsState>(
        logsProvider,
        (_, next) => notifier.synchronize(next),
      );
      return notifier;
    });

class InferenceActivityNotifier extends StateNotifier<InferenceActivityState> {
  final InferenceActivityTracker _tracker;
  Timer? _ticker;

  InferenceActivityNotifier(this._tracker) : super(_tracker.snapshot());

  void synchronize(LogsState logs) {
    if (!mounted) return;
    state = _tracker.synchronize(logs);
    _updateTicker();
  }

  void _updateTicker() {
    final needsTicker =
        state.shouldShow &&
        (state.activeRequests.isNotEmpty || state.recentCompletion != null);
    if (!needsTicker) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        state = _tracker.tick();
        _updateTicker();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
