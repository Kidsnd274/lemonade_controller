import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';
import 'package:lemonade_controller/models/log_entry.dart';
import 'package:lemonade_controller/providers/log_providers.dart';

enum InferencePhase {
  modelLoading,
  received,
  promptProcessing,
  generating,
  completed,
}

class PromptTimingSample {
  final double progress;
  final double elapsedSeconds;

  const PromptTimingSample({
    required this.progress,
    required this.elapsedSeconds,
  });
}

class InferenceTaskActivity {
  final String key;
  final int? taskId;
  final int? slotId;
  final String? model;
  final bool includesModelLoading;
  final InferencePhase phase;
  final DateTime startedAt;
  final DateTime updatedAt;
  final double? promptProgress;
  final int? promptTokensProcessed;
  final double? promptTokensPerSecond;
  final List<PromptTimingSample> promptTimingSamples;
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
    this.model,
    this.includesModelLoading = false,
    this.promptProgress,
    this.promptTokensProcessed,
    this.promptTokensPerSecond,
    this.promptTimingSamples = const [],
    this.decodedTokens,
    this.generationTokensPerSecond,
    this.averageGenerationTokensPerSecond,
  });

  InferenceTaskActivity copyWith({
    String? key,
    int? taskId,
    int? slotId,
    String? model,
    bool? includesModelLoading,
    InferencePhase? phase,
    DateTime? startedAt,
    DateTime? updatedAt,
    double? promptProgress,
    int? promptTokensProcessed,
    double? promptTokensPerSecond,
    List<PromptTimingSample>? promptTimingSamples,
    int? decodedTokens,
    double? generationTokensPerSecond,
    double? averageGenerationTokensPerSecond,
  }) => InferenceTaskActivity(
    key: key ?? this.key,
    taskId: taskId ?? this.taskId,
    slotId: slotId ?? this.slotId,
    model: model ?? this.model,
    includesModelLoading: includesModelLoading ?? this.includesModelLoading,
    phase: phase ?? this.phase,
    startedAt: startedAt ?? this.startedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    promptProgress: promptProgress ?? this.promptProgress,
    promptTokensProcessed: promptTokensProcessed ?? this.promptTokensProcessed,
    promptTokensPerSecond: promptTokensPerSecond ?? this.promptTokensPerSecond,
    promptTimingSamples: promptTimingSamples ?? this.promptTimingSamples,
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
    final samples = promptTimingSamples
        .where(
          (sample) =>
              sample.progress > 0 &&
              sample.elapsedSeconds >= 0 &&
              sample.progress.isFinite &&
              sample.elapsedSeconds.isFinite,
        )
        .toList();
    if (progress == null || progress >= 1 || samples.length < 2) {
      return null;
    }

    // Fit cumulative prompt time as t(p) = a*p + b*p^2, where p is prompt
    // progress. The quadratic term captures the common case where processing
    // slows as the prompt grows. All reported timing points contribute to the
    // least-squares fit. If that curve is unstable or implies acceleration,
    // fall back to an all-point linear fit through the origin.
    var sumP2 = 0.0;
    var sumP3 = 0.0;
    var sumP4 = 0.0;
    var sumPT = 0.0;
    var sumP2T = 0.0;
    for (final sample in samples) {
      final p = sample.progress;
      final p2 = p * p;
      sumP2 += p2;
      sumP3 += p2 * p;
      sumP4 += p2 * p2;
      sumPT += p * sample.elapsedSeconds;
      sumP2T += p2 * sample.elapsedSeconds;
    }
    if (sumP2 <= 0) return null;

    var predictedTotalSeconds = sumPT / sumP2;
    final determinant = sumP2 * sumP4 - sumP3 * sumP3;
    if (determinant.abs() > 1e-9) {
      final a = (sumPT * sumP4 - sumP2T * sumP3) / determinant;
      final b = (sumP2 * sumP2T - sumP3 * sumPT) / determinant;
      final quadraticTotal = a + b;
      final slopeNow = a + 2 * b * progress;
      final slopeAtEnd = a + 2 * b;
      if (b >= 0 &&
          quadraticTotal.isFinite &&
          quadraticTotal >= samples.last.elapsedSeconds &&
          slopeNow > 0 &&
          slopeAtEnd > 0) {
        predictedTotalSeconds = quadraticTotal;
      }
    }

    final secondsAtUpdate = predictedTotalSeconds - samples.last.elapsedSeconds;
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
  static final _cancelPattern = RegExp(
    r'srv\s+stop:\s+cancel task,\s*id_task\s*=\s*(\d+)',
  );
  static final _releasePattern = RegExp(
    r'slot\s+release:\s+id\s+(\d+)\s*\|\s*task\s+(\d+)\s*\|\s*stop processing',
  );
  static final _telemetryPattern = RegExp(
    r'Inference completed:\s*model=(.+?),\s*tokens=(\d+)\s*\(in=(\d+),\s*out=(\d+)\),\s*ttft=([0-9.]+)s,\s*tps=([0-9.]+)',
  );
  static final _autoLoadingPattern = RegExp(r'Auto-loading model:\s*(.+?)\s*$');
  static final _modelLoadedPattern = RegExp(
    r'Model loaded successfully:\s*(.+?)\s*$',
  );
  static final _modelAlreadyLoadedPattern = RegExp(
    r'Model already loaded:\s*(.+?)\s*$',
  );
  static final _unloadModelPattern = RegExp(
    r'Unload model called:\s*(.+?)\s*$',
  );
  static final _lineTimestampPattern = RegExp(
    r'^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2}\.\d+)',
  );

  final DateTime Function() _clock;
  final Map<String, InferenceTaskActivity> _active = {};
  final Map<int, DateTime> _cancelledTasks = {};
  final List<String> _pendingKeys = [];
  final List<String> _pendingRequestModels = [];
  final List<String> _awaitingRequestAfterLoadKeys = [];
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
      _cancelledTasks.clear();
      _pendingKeys.clear();
      _pendingRequestModels.clear();
      _awaitingRequestAfterLoadKeys.clear();
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

    if (line.contains('Auto-loading model:')) {
      final match = _autoLoadingPattern.firstMatch(line);
      if (match == null) return false;
      _formatSupported = true;
      final model = match.group(1)!.trim();
      final key = 'loading:${entry.seq}';
      _active[key] = InferenceTaskActivity(
        key: key,
        model: model,
        includesModelLoading: true,
        phase: InferencePhase.modelLoading,
        startedAt: eventTime,
        updatedAt: eventTime,
      );
      _recentCompletion = null;
      return true;
    }

    if (line.contains('Model loaded successfully:')) {
      final match = _modelLoadedPattern.firstMatch(line);
      if (match == null) return false;
      final model = match.group(1)!.trim();
      final loading = _findLoadingModel(model);
      if (loading == null) return false;
      _formatSupported = true;
      _active[loading.key] = loading.copyWith(
        phase: InferencePhase.received,
        updatedAt: eventTime,
      );
      if (!_awaitingRequestAfterLoadKeys.contains(loading.key)) {
        _awaitingRequestAfterLoadKeys.add(loading.key);
      }
      return true;
    }

    if (line.contains('Failed to load model:')) {
      final loading = _mostRecentLoadingModel();
      if (loading == null) return false;
      _formatSupported = true;
      _removeActivity(loading.key);
      return true;
    }

    if (line.contains('Model already loaded:')) {
      final match = _modelAlreadyLoadedPattern.firstMatch(line);
      if (match == null) return false;
      _pendingRequestModels.add(match.group(1)!.trim());
      if (_pendingRequestModels.length > 16) {
        _pendingRequestModels.removeAt(0);
      }
      return true;
    }

    if (line.contains('Unload model called:')) {
      final match = _unloadModelPattern.firstMatch(line);
      if (match == null) return false;
      final model = match.group(1)!.trim();
      final matchingKeys = _active.entries
          .where((entry) => _modelNamesMatch(entry.value.model, model))
          .map((entry) => entry.key)
          .toList();
      for (final key in matchingKeys) {
        _removeActivity(key);
      }
      return matchingKeys.isNotEmpty;
    }

    if (line.contains('Client disconnected during SSE stream')) {
      final request = _mostRecentlyUpdatedRequest();
      if (request == null) return false;
      _removeActivity(request.key);
      return true;
    }

    if (_isInferenceRequest(line)) {
      final loadedActivity = _takeAwaitingRequestAfterLoad();
      if (loadedActivity != null) {
        _active[loadedActivity.key] = loadedActivity.copyWith(
          phase: InferencePhase.received,
          updatedAt: eventTime,
        );
        _pendingKeys.add(loadedActivity.key);
        _recentCompletion = null;
        return true;
      }
      final key = 'pending:${entry.seq}';
      final model = _pendingRequestModels.isEmpty
          ? null
          : _pendingRequestModels.removeAt(0);
      _active[key] = InferenceTaskActivity(
        key: key,
        model: model,
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
        model: pending?.model,
        includesModelLoading: pending?.includesModelLoading ?? false,
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
      final promptElapsedSeconds = double.parse(match.group(5)!);
      final key = 'task:$taskId';
      final previous = _active[key];
      final progress = previous?.promptProgress == null
          ? parsedProgress
          : parsedProgress.clamp(previous!.promptProgress!, 1.0).toDouble();
      final timingSamples = List<PromptTimingSample>.unmodifiable([
        ...?previous?.promptTimingSamples,
        PromptTimingSample(
          progress: progress,
          elapsedSeconds: promptElapsedSeconds,
        ),
      ]);
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
                promptTimingSamples: timingSamples,
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

    if (line.contains('cancel task')) {
      final match = _cancelPattern.firstMatch(line);
      if (match == null) return false;
      _formatSupported = true;
      final taskId = int.parse(match.group(1)!);
      _active.remove('task:$taskId');
      _cancelledTasks[taskId] = eventTime;
      _unmatchedCompletions.removeWhere(
        (completion) => completion.task.taskId == taskId,
      );
      if (_recentCompletion?.task.taskId == taskId) {
        _recentCompletion = null;
      }
      return true;
    }

    if (line.contains('stop processing')) {
      final match = _releasePattern.firstMatch(line);
      if (match == null) return false;
      _formatSupported = true;
      final slotId = int.parse(match.group(1)!);
      final taskId = int.parse(match.group(2)!);
      final key = 'task:$taskId';
      if (_cancelledTasks.remove(taskId) != null) {
        _active.remove(key);
        return true;
      }
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

  bool _isInferenceRequest(String line) =>
      line.contains('POST /api/v1/chat/completions') ||
      line.contains('POST /api/v1/responses');

  InferenceTaskActivity? _findLoadingModel(String model) {
    for (final activity in _active.values) {
      if (activity.phase == InferencePhase.modelLoading &&
          activity.model == model) {
        return activity;
      }
    }
    return null;
  }

  InferenceTaskActivity? _mostRecentLoadingModel() {
    InferenceTaskActivity? latest;
    for (final activity in _active.values) {
      if (activity.phase != InferencePhase.modelLoading) continue;
      if (latest == null || activity.updatedAt.isAfter(latest.updatedAt)) {
        latest = activity;
      }
    }
    return latest;
  }

  InferenceTaskActivity? _mostRecentlyUpdatedRequest() {
    InferenceTaskActivity? latest;
    for (final activity in _active.values) {
      if (activity.taskId == null) continue;
      if (latest == null || activity.updatedAt.isAfter(latest.updatedAt)) {
        latest = activity;
      }
    }
    return latest;
  }

  bool _modelNamesMatch(String? left, String right) {
    if (left == null) return false;
    String normalize(String model) =>
        model.replaceFirst(RegExp(r'^(?:user|extra)\.'), '').trim();
    return normalize(left) == normalize(right);
  }

  InferenceTaskActivity? _takeAwaitingRequestAfterLoad() {
    while (_awaitingRequestAfterLoadKeys.isNotEmpty) {
      final key = _awaitingRequestAfterLoadKeys.removeAt(0);
      final activity = _active[key];
      if (activity != null) return activity;
    }
    return null;
  }

  void _removeActivity(String key) {
    _active.remove(key);
    _pendingKeys.remove(key);
    _awaitingRequestAfterLoadKeys.remove(key);
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
      _removeActivity(key);
    }
    _cancelledTasks.removeWhere(
      (_, cancelledAt) => now.difference(cancelledAt) > staleActivityAge,
    );
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
    _cancelledTasks.clear();
    _pendingKeys.clear();
    _pendingRequestModels.clear();
    _awaitingRequestAfterLoadKeys.clear();
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
