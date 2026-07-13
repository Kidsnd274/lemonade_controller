import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemonade_controller/models/health_info.dart';
import 'package:lemonade_controller/models/log_entry.dart';
import 'package:lemonade_controller/pages/home/widgets/inference_activity_panel.dart';
import 'package:lemonade_controller/pages/home/widgets/server_status_card.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/providers/inference_activity_provider.dart';
import 'package:lemonade_controller/providers/log_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('InferenceActivityTracker', () {
    test('tracks prompt ETA, generation, release, and telemetry incrementally', () {
      var now = DateTime.parse('2026-07-12T00:35:54');
      final tracker = InferenceActivityTracker(clock: () => now);
      final entries = <LogEntry>[
        _entry(
          1,
          '2026-07-12 00:35:44.215',
          'POST /api/v1/chat/completions - Streaming',
          tag: 'Server',
        ),
        _entry(
          2,
          '2026-07-12 00:35:44.442',
          'slot launch_slot_: id  2 | task 10856 | processing task, is_child = 0',
        ),
        _entry(
          3,
          '2026-07-12 00:35:50.947',
          'slot print_timing: id  2 | task 10856 | prompt processing, n_tokens =   4096, progress = 0.18, t =   4.07 s / 1007.55 tokens per second',
        ),
        _entry(
          4,
          '2026-07-12 00:35:53.107',
          'slot print_timing: id  2 | task 10856 | prompt processing, n_tokens =   6144, progress = 0.26, t =   6.23 s / 986.96 tokens per second',
        ),
      ];

      var state = tracker.synchronize(_connected(entries));
      expect(state.shouldShow, isTrue);
      expect(state.activeRequests, hasLength(1));
      expect(state.activeRequests.single.taskId, 10856);
      expect(
        state.activeRequests.single.phase,
        InferencePhase.promptProcessing,
      );
      expect(state.activeRequests.single.promptProgress, .26);
      expect(state.activeRequests.single.promptEtaAt(now), isNotNull);
      expect(state.activeRequests.single.promptTokensPerSecond, 986.96);

      now = DateTime.parse('2026-07-12T00:36:40');
      entries.add(
        _entry(
          5,
          '2026-07-12 00:36:40.179',
          'slot print_timing: id  2 | task 10856 | n_decoded =    307, tg =  50.80 t/s, tg_3s =  49.26 t/s',
        ),
      );
      state = tracker.synchronize(_connected(entries));
      expect(state.activeRequests.single.phase, InferencePhase.generating);
      expect(state.activeRequests.single.decodedTokens, 307);
      expect(state.activeRequests.single.generationTokensPerSecond, 49.26);

      now = DateTime.parse('2026-07-12T00:36:46');
      entries.addAll([
        _entry(
          6,
          '2026-07-12 00:36:45.949',
          'slot      release: id  2 | task 10856 | stop processing: n_tokens = 23359, truncated = 0',
        ),
        _entry(
          7,
          '2026-07-12 00:36:45.950',
          'Inference completed: model=Qwen3.6-35B, tokens=23358 (in=23190, out=168), ttft=28.224s, tps=55.83',
          tag: 'Telemetry',
        ),
      ]);
      state = tracker.synchronize(_connected(entries));
      expect(state.activeRequests, isEmpty);
      expect(state.recentCompletion?.totalTokens, 23358);
      expect(state.recentCompletion?.tokensPerSecond, 55.83);
      expect(state.recentCompletion?.task.phase, InferencePhase.completed);
    });

    test('carries an auto-loaded model into the responses inference task', () {
      var now = DateTime.parse('2026-07-13T20:44:15.300');
      final tracker = InferenceActivityTracker(clock: () => now);
      final entries = <LogEntry>[
        _entry(
          1,
          '2026-07-13 20:44:15.207',
          'Auto-loading model: gemma-4-31B-it-GGUF-UD-Q6_K_XL',
          tag: 'Server',
        ),
      ];

      var state = tracker.synchronize(_connected(entries));
      expect(state.shouldShow, isTrue);
      expect(state.activeRequests, hasLength(1));
      expect(state.activeRequests.single.phase, InferencePhase.modelLoading);
      expect(
        state.activeRequests.single.model,
        'gemma-4-31B-it-GGUF-UD-Q6_K_XL',
      );
      expect(state.activeRequests.single.includesModelLoading, isTrue);

      entries.add(
        _entry(
          2,
          '2026-07-13 20:44:38.646',
          'Model loaded successfully: gemma-4-31B-it-GGUF-UD-Q6_K_XL',
          tag: 'Server',
        ),
      );
      now = DateTime.parse('2026-07-13T20:44:38.650');
      state = tracker.synchronize(_connected(entries));
      expect(state.activeRequests.single.phase, InferencePhase.received);

      entries.addAll([
        _entry(
          3,
          '2026-07-13 20:44:38.646',
          'POST /api/v1/responses - Streaming',
          tag: 'Server',
        ),
        _entry(
          4,
          '2026-07-13 20:44:38.716',
          'slot launch_slot_: id  3 | task 0 | processing task, is_child = 0',
        ),
      ]);
      now = DateTime.parse('2026-07-13T20:44:38.720');
      state = tracker.synchronize(_connected(entries));

      expect(state.activeRequests, hasLength(1));
      final request = state.activeRequests.single;
      expect(request.key, 'task:0');
      expect(request.taskId, 0);
      expect(request.slotId, 3);
      expect(request.phase, InferencePhase.promptProcessing);
      expect(request.model, 'gemma-4-31B-it-GGUF-UD-Q6_K_XL');
      expect(request.includesModelLoading, isTrue);
      expect(request.startedAt, DateTime.parse('2026-07-13T20:44:15.207'));
    });

    test('clears failed and stale auto-loading activities', () {
      var now = DateTime.parse('2026-07-13T20:44:16');
      final failedTracker = InferenceActivityTracker(clock: () => now);
      final failedEntries = <LogEntry>[
        _entry(
          1,
          '2026-07-13 20:44:15.207',
          'Auto-loading model: broken-model',
          tag: 'Server',
        ),
        _entry(
          2,
          '2026-07-13 20:44:15.900',
          'Failed to load model: backend initialization failed',
          tag: 'Server',
        ),
      ];

      var state = failedTracker.synchronize(_connected(failedEntries));
      expect(state.activeRequests, isEmpty);
      expect(state.shouldShow, isTrue);

      final staleTracker = InferenceActivityTracker(clock: () => now);
      state = staleTracker.synchronize(
        _connected([
          _entry(
            1,
            '2026-07-13 20:44:15.207',
            'Auto-loading model: stalled-model',
            tag: 'Server',
          ),
        ]),
      );
      expect(state.activeRequests, hasLength(1));

      now = DateTime.parse('2026-07-13T20:50:00');
      state = staleTracker.tick();
      expect(state.activeRequests, isEmpty);
    });

    test('waits for multiple timing points when cached progress starts high', () {
      var now = DateTime.parse('2026-07-12T00:36:25');
      final tracker = InferenceActivityTracker(clock: () => now);
      final entries = [
        _entry(
          1,
          '2026-07-12 00:36:20.475',
          'POST /api/v1/chat/completions - Streaming',
          tag: 'Server',
        ),
        _entry(
          2,
          '2026-07-12 00:36:20.557',
          'slot launch_slot_: id  2 | task 10942 | processing task, is_child = 0',
        ),
        _entry(
          3,
          '2026-07-12 00:36:24.387',
          'slot print_timing: id  2 | task 10942 | prompt processing, n_tokens =   2048, progress = 0.81, t =   3.83 s / 534.87 tokens per second',
        ),
      ];

      var state = tracker.synchronize(_connected(entries));
      expect(state.activeRequests.single.promptProgress, .81);
      expect(state.activeRequests.single.promptEtaAt(now), isNull);

      now = DateTime.parse('2026-07-12T00:36:28');
      entries.add(
        _entry(
          4,
          '2026-07-12 00:36:27.519',
          'slot print_timing: id  2 | task 10942 | prompt processing, n_tokens =   4096, progress = 0.87, t =   6.96 s / 588.36 tokens per second',
        ),
      );
      state = tracker.synchronize(_connected(entries));
      final eta = state.activeRequests.single.promptEtaAt(now);
      expect(eta, isNotNull);
      expect(state.activeRequests.single.promptTimingSamples, hasLength(2));
      expect(eta!.inSeconds, inInclusiveRange(5, 7));
    });

    test('fits all prompt timing points to account for decreasing speed', () {
      final now = DateTime.parse('2026-07-12T00:00:12');
      final tracker = InferenceActivityTracker(clock: () => now);
      final state = tracker.synchronize(
        _connected([
          _entry(
            1,
            '2026-07-12 00:00:00.000',
            'POST /api/v1/chat/completions - Streaming',
            tag: 'Server',
          ),
          _entry(
            2,
            '2026-07-12 00:00:00.100',
            'slot launch_slot_: id  0 | task 10 | processing task, is_child = 0',
          ),
          _entry(
            3,
            '2026-07-12 00:00:02.000',
            'slot print_timing: id  0 | task 10 | prompt processing, n_tokens =   1000, progress = 0.25, t =   2.00 s / 500.00 tokens per second',
          ),
          _entry(
            4,
            '2026-07-12 00:00:06.000',
            'slot print_timing: id  0 | task 10 | prompt processing, n_tokens =   2000, progress = 0.50, t =   6.00 s / 333.33 tokens per second',
          ),
          _entry(
            5,
            '2026-07-12 00:00:12.000',
            'slot print_timing: id  0 | task 10 | prompt processing, n_tokens =   3000, progress = 0.75, t =  12.00 s / 250.00 tokens per second',
          ),
        ]),
      );

      final request = state.activeRequests.single;
      expect(request.promptTimingSamples, hasLength(3));
      expect(request.promptEtaAt(now), const Duration(seconds: 8));
    });

    test('keeps concurrent requests ordered oldest-first and removes by task', () {
      var now = DateTime.parse('2026-07-12T00:37:00');
      final tracker = InferenceActivityTracker(clock: () => now);
      final entries = [
        _entry(
          1,
          '2026-07-12 00:36:46.110',
          'POST /api/v1/chat/completions - 200 OK',
          tag: 'Server',
        ),
        _entry(
          2,
          '2026-07-12 00:36:46.144',
          'slot launch_slot_: id  1 | task 11243 | processing task, is_child = 0',
        ),
        _entry(
          3,
          '2026-07-12 00:36:58.319',
          'POST /api/v1/chat/completions - Streaming',
          tag: 'Server',
        ),
        _entry(
          4,
          '2026-07-12 00:36:58.627',
          'slot launch_slot_: id  0 | task 11248 | processing task, is_child = 0',
        ),
        _entry(
          5,
          '2026-07-12 00:36:59.538',
          'slot print_timing: id  1 | task 11243 | prompt processing, n_tokens =   6358, progress = 0.49, t =   7.82 s / 813.52 tokens per second',
        ),
        _entry(
          6,
          '2026-07-12 00:37:01.832',
          'slot print_timing: id  0 | task 11248 | prompt processing, n_tokens =      1, progress = 1.00, t =   3.20 s / 0.31 tokens per second',
        ),
      ];

      var state = tracker.synchronize(_connected(entries));
      expect(state.activeRequests.map((request) => request.taskId), [
        11243,
        11248,
      ]);

      now = DateTime.parse('2026-07-12T00:37:10.100');
      entries.add(
        _entry(
          7,
          '2026-07-12 00:37:10.060',
          'slot      release: id  1 | task 11243 | stop processing: n_tokens = 12975, truncated = 0',
        ),
      );
      state = tracker.synchronize(_connected(entries));
      expect(state.activeRequests.map((request) => request.taskId), [11248]);
    });

    test('removes cancelled tasks without recording a normal completion', () {
      var now = DateTime.parse('2026-07-12T02:35:08.600');
      final tracker = InferenceActivityTracker(clock: () => now);
      final entries = <LogEntry>[
        _entry(
          1,
          '2026-07-12 02:35:05.506',
          'POST /api/v1/chat/completions - Streaming',
          tag: 'Server',
        ),
        _entry(
          2,
          '2026-07-12 02:35:05.617',
          'slot launch_slot_: id  0 | task 14005 | processing task, is_child = 0',
        ),
      ];

      var state = tracker.synchronize(_connected(entries));
      expect(state.activeRequests.single.taskId, 14005);

      entries.add(
        _entry(
          3,
          '2026-07-12 02:35:08.651',
          'srv          stop: cancel task, id_task = 14005',
        ),
      );
      now = DateTime.parse('2026-07-12T02:35:08.652');
      state = tracker.synchronize(_connected(entries));
      expect(state.activeRequests, isEmpty);
      expect(state.recentCompletion, isNull);

      entries.add(
        _entry(
          4,
          '2026-07-12 02:35:08.684',
          'slot      release: id  0 | task 14005 | stop processing: n_tokens = 42215, truncated = 0',
        ),
      );
      now = DateTime.parse('2026-07-12T02:35:08.685');
      state = tracker.synchronize(_connected(entries));
      expect(state.activeRequests, isEmpty);
      expect(state.recentCompletion, isNull);
    });

    test('clears a finalizing request when its model is unloaded', () {
      var now = DateTime.parse('2026-07-13T23:06:14.500');
      final tracker = InferenceActivityTracker(clock: () => now);
      final entries = <LogEntry>[
        _entry(
          1,
          '2026-07-13 23:06:08.044',
          'Model already loaded: gemma-4-31B-it-GGUF-UD-Q6_K_XL',
          tag: 'Server',
        ),
        _entry(
          2,
          '2026-07-13 23:06:08.044',
          'POST /api/v1/responses - Streaming',
          tag: 'Server',
        ),
        _entry(
          3,
          '2026-07-13 23:06:08.143',
          'slot launch_slot_: id  3 | task 156 | processing task, is_child = 0',
        ),
        _entry(
          4,
          '2026-07-13 23:06:14.423',
          'slot print_timing: id  3 | task 156 | prompt processing, n_tokens =    346, progress = 1.00, t =   6.28 s / 55.10 tokens per second',
        ),
      ];

      var state = tracker.synchronize(_connected(entries));
      expect(state.activeRequests, hasLength(1));
      expect(
        state.activeRequests.single.phase,
        InferencePhase.promptProcessing,
      );
      expect(state.activeRequests.single.promptProgress, 1);
      expect(
        state.activeRequests.single.model,
        'gemma-4-31B-it-GGUF-UD-Q6_K_XL',
      );

      entries.add(
        _entry(
          5,
          '2026-07-13 23:06:15.663',
          'Unload model called: gemma-4-31B-it-GGUF-UD-Q6_K_XL',
          tag: 'Router',
        ),
      );
      now = DateTime.parse('2026-07-13T23:06:15.664');
      state = tracker.synchronize(_connected(entries));
      expect(state.activeRequests, isEmpty);
    });

    test('clears the latest task when an SSE stream disconnects', () {
      final now = DateTime.parse('2026-07-13T23:06:21.547');
      final tracker = InferenceActivityTracker(clock: () => now);
      final state = tracker.synchronize(
        _connected([
          _entry(
            1,
            '2026-07-13 23:06:08.044',
            'POST /api/v1/responses - Streaming',
            tag: 'Server',
          ),
          _entry(
            2,
            '2026-07-13 23:06:08.143',
            'slot launch_slot_: id  3 | task 156 | processing task, is_child = 0',
          ),
          _entry(
            3,
            '2026-07-13 23:06:21.373',
            'slot print_timing: id  3 | task 156 | prompt processing, n_tokens =    372, progress = 1.00, t =  13.23 s / 28.12 tokens per second',
          ),
          _entry(
            4,
            '2026-07-13 23:06:21.546',
            'Client disconnected during SSE stream (CURL error: Failed writing received data to disk/application)',
            tag: 'StreamingProxy',
          ),
        ]),
      );

      expect(state.activeRequests, isEmpty);
      expect(state.recentCompletion, isNull);
    });

    test('fails closed for unknown logs and resets on disconnect', () {
      final now = DateTime.parse('2026-07-12T00:00:00');
      final tracker = InferenceActivityTracker(clock: () => now);
      var state = tracker.synchronize(
        _connected([_entry(1, '2026-07-12 00:00:00.000', 'unrelated log')]),
      );
      expect(state.shouldShow, isFalse);

      state = tracker.synchronize(
        _connected([
          _entry(1, '2026-07-12 00:00:00.000', 'unrelated log'),
          _entry(
            2,
            '2026-07-12 00:00:00.100',
            'POST /api/v1/chat/completions - Streaming',
            tag: 'Server',
          ),
        ]),
      );
      expect(state.shouldShow, isFalse);

      state = tracker.synchronize(
        LogsState(
          entries: [
            _entry(
              3,
              '2026-07-12 00:00:00.100',
              'POST /api/v1/chat/completions - Streaming',
            ),
          ],
          status: LogConnectionStatus.disconnected,
        ),
      );
      expect(state.shouldShow, isFalse);
      expect(state.activeRequests, isEmpty);
    });

    test('expires stale work and completed summaries', () {
      var now = DateTime.parse('2026-07-12T00:00:01');
      final tracker = InferenceActivityTracker(clock: () => now);
      final entries = [
        _entry(
          1,
          '2026-07-12 00:00:00.000',
          'POST /api/v1/chat/completions - Streaming',
          tag: 'Server',
        ),
        _entry(
          2,
          '2026-07-12 00:00:00.100',
          'slot launch_slot_: id  0 | task 10 | processing task, is_child = 0',
        ),
      ];
      var state = tracker.synchronize(_connected(entries));
      expect(state.activeRequests, hasLength(1));

      now = DateTime.parse('2026-07-12T00:06:00');
      state = tracker.tick();
      expect(state.activeRequests, isEmpty);
      expect(state.shouldShow, isTrue);

      entries.addAll([
        _entry(
          3,
          '2026-07-12 00:06:01.000',
          'POST /api/v1/chat/completions - Streaming',
          tag: 'Server',
        ),
        _entry(
          4,
          '2026-07-12 00:06:01.100',
          'slot launch_slot_: id  0 | task 11 | processing task, is_child = 0',
        ),
        _entry(
          5,
          '2026-07-12 00:06:02.000',
          'slot release: id  0 | task 11 | stop processing: n_tokens = 3, truncated = 0',
        ),
      ]);
      now = DateTime.parse('2026-07-12T00:06:02.100');
      state = tracker.synchronize(_connected(entries));
      expect(state.recentCompletion, isNotNull);

      now = DateTime.parse('2026-07-12T00:06:11');
      state = tracker.tick();
      expect(state.recentCompletion, isNull);
    });
  });

  group('InferenceActivityPanel', () {
    testWidgets('shows model loading as the first inference stage', (
      tester,
    ) async {
      final now = DateTime.parse('2026-07-13T20:44:20');
      await _pumpPanel(
        tester,
        InferenceActivityState(
          connectionStatus: LogConnectionStatus.connected,
          formatSupported: true,
          activeRequests: [
            InferenceTaskActivity(
              key: 'loading:1',
              model: 'gemma-4-31B-it-GGUF-UD-Q6_K_XL',
              includesModelLoading: true,
              phase: InferencePhase.modelLoading,
              startedAt: now.subtract(const Duration(seconds: 5)),
              updatedAt: now.subtract(const Duration(seconds: 5)),
            ),
          ],
          now: now,
        ),
      );

      expect(find.text('Live inference'), findsOneWidget);
      expect(find.text('Loading Model'), findsOneWidget);
      expect(find.text('Model gemma-4-31B-it-GGUF-UD-Q6_K_XL'), findsOneWidget);
      expect(
        find.text('Loading gemma-4-31B-it-GGUF-UD-Q6_K_XL'),
        findsOneWidget,
      );
      expect(find.text('Loading'), findsOneWidget);
      expect(find.text('Prompt'), findsOneWidget);
      expect(find.text('Generating'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Received'), findsNothing);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
    });

    testWidgets('keeps completed stage labels centered beside checkmarks', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(620, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.parse('2026-07-13T20:45:00');
      await _pumpPanel(
        tester,
        InferenceActivityState(
          connectionStatus: LogConnectionStatus.connected,
          formatSupported: true,
          activeRequests: [
            InferenceTaskActivity(
              key: 'task:0',
              taskId: 0,
              slotId: 3,
              model: 'gemma-4-31B-it-GGUF-UD-Q6_K_XL',
              includesModelLoading: true,
              phase: InferencePhase.generating,
              startedAt: now.subtract(const Duration(seconds: 45)),
              updatedAt: now,
            ),
          ],
          now: now,
        ),
      );

      final loadingLabel = find.text('Loading');
      final loadingStage = find.ancestor(
        of: loadingLabel,
        matching: find.byType(AnimatedContainer),
      );
      expect(loadingStage, findsOneWidget);
      expect(
        (tester.getCenter(loadingLabel).dx - tester.getCenter(loadingStage).dx)
            .abs(),
        lessThan(0.5),
      );
    });

    testWidgets('keeps the main request expanded while secondary rows toggle', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.parse('2026-07-12T00:37:05');
      final main = _task(
        key: 'task:11243',
        taskId: 11243,
        slotId: 1,
        startedAt: now.subtract(const Duration(seconds: 19)),
        phase: InferencePhase.promptProcessing,
        progress: .81,
      );
      final secondary = _task(
        key: 'task:11248',
        taskId: 11248,
        slotId: 0,
        startedAt: now.subtract(const Duration(seconds: 7)),
        phase: InferencePhase.generating,
      );
      final state = InferenceActivityState(
        connectionStatus: LogConnectionStatus.connected,
        formatSupported: true,
        activeRequests: [main, secondary],
        now: now,
      );

      await _pumpPanel(tester, state);
      expect(find.text('Main request'), findsOneWidget);
      expect(find.text('Concurrent request'), findsOneWidget);
      expect(find.text('#11248 · Slot 0'), findsOneWidget);
      expect(
        find.text('1 other request is sharing server capacity.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);
      expect(find.text('Prompt Processing'), findsOneWidget);
      expect(find.text('Token Generation'), findsOneWidget);
      final collapsedBars = find.byType(LinearProgressIndicator);
      expect(collapsedBars, findsNWidgets(2));
      expect(
        tester.getSize(collapsedBars.at(1)).width,
        lessThan(tester.getSize(collapsedBars.at(0)).width),
      );

      await tester.tap(find.text('Concurrent request'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text('Main request'), findsOneWidget);
      expect(find.text('Received'), findsNWidgets(2));
      expect(find.text('Done'), findsNWidgets(2));
    });

    testWidgets('caps secondary progress width on wide layouts', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.parse('2026-07-12T00:37:05');
      await _pumpPanel(
        tester,
        InferenceActivityState(
          connectionStatus: LogConnectionStatus.connected,
          formatSupported: true,
          activeRequests: [
            _task(
              key: 'task:1',
              taskId: 1,
              slotId: 0,
              startedAt: now.subtract(const Duration(seconds: 10)),
              phase: InferencePhase.promptProcessing,
              progress: .5,
            ),
            _task(
              key: 'task:2',
              taskId: 2,
              slotId: 1,
              startedAt: now.subtract(const Duration(seconds: 5)),
              phase: InferencePhase.generating,
            ),
          ],
          now: now,
        ),
      );

      final bars = find.byType(LinearProgressIndicator);
      expect(bars, findsNWidgets(2));
      expect(tester.getSize(bars.at(1)).width, lessThanOrEqualTo(240));
      expect(
        tester.getSize(bars.at(0)).width,
        greaterThan(tester.getSize(bars.at(1)).width * 2),
      );
    });

    testWidgets('promotes the remaining request into a detailed single view', (
      tester,
    ) async {
      final now = DateTime.parse('2026-07-12T00:37:05');
      final first = _task(
        key: 'task:1',
        taskId: 1,
        slotId: 0,
        startedAt: now.subtract(const Duration(seconds: 10)),
        phase: InferencePhase.generating,
      );
      final second = _task(
        key: 'task:2',
        taskId: 2,
        slotId: 1,
        startedAt: now.subtract(const Duration(seconds: 5)),
        phase: InferencePhase.promptProcessing,
        progress: .4,
      );

      await _pumpPanel(
        tester,
        InferenceActivityState(
          connectionStatus: LogConnectionStatus.connected,
          formatSupported: true,
          activeRequests: [first, second],
          now: now,
        ),
      );
      await _pumpPanel(
        tester,
        InferenceActivityState(
          connectionStatus: LogConnectionStatus.connected,
          formatSupported: true,
          activeRequests: [second],
          now: now,
        ),
      );

      expect(find.text('Active request'), findsOneWidget);
      expect(find.text('Main request'), findsNothing);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('hides the panel when supported and idle', (tester) async {
      await _pumpPanel(
        tester,
        InferenceActivityState(
          connectionStatus: LogConnectionStatus.connected,
          formatSupported: true,
          now: DateTime.parse('2026-07-12T00:00:00'),
        ),
      );
      expect(find.text('Live inference'), findsNothing);
      expect(find.text('Ready for requests'), findsNothing);
    });
  });

  testWidgets('Server Status adds nothing when log streaming is unavailable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthInfoProvider.overrideWith(
            (ref) async => const HealthInfo(
              status: 'ok',
              version: '10.10.0',
              websocketPort: 0,
              maxModels: {'llm': 4},
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ServerStatusCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Model Slots'), findsOneWidget);
    expect(find.text('Live inference'), findsNothing);
    expect(find.text('Ready for requests'), findsNothing);
  });
}

LogsState _connected(List<LogEntry> entries) => LogsState(
  entries: List.unmodifiable(entries),
  status: LogConnectionStatus.connected,
);

LogEntry _entry(
  int seq,
  String timestamp,
  String line, {
  String tag = 'Process',
}) => LogEntry(
  seq: seq,
  timestamp: timestamp,
  severity: 'Info',
  tag: tag,
  line: '$timestamp [Info] ($tag) $line',
);

InferenceTaskActivity _task({
  required String key,
  required int taskId,
  required int slotId,
  required DateTime startedAt,
  required InferencePhase phase,
  double? progress,
}) => InferenceTaskActivity(
  key: key,
  taskId: taskId,
  slotId: slotId,
  phase: phase,
  startedAt: startedAt,
  updatedAt: startedAt.add(const Duration(seconds: 3)),
  promptProgress: progress,
  promptTokensPerSecond: progress == null ? null : 800,
  decodedTokens: phase == InferencePhase.generating ? 128 : null,
  generationTokensPerSecond: phase == InferencePhase.generating ? 42 : null,
);

Future<void> _pumpPanel(WidgetTester tester, InferenceActivityState state) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: InferenceActivityPanel(activity: state),
          ),
        ),
      ),
    );
