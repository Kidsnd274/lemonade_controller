import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lemonade_controller/models/request_stats.dart';
import 'package:lemonade_controller/models/system_info.dart';
import 'package:lemonade_controller/models/system_stats.dart';
import 'package:lemonade_controller/pages/home/widgets/performance_card.dart';
import 'package:lemonade_controller/pages/home/widgets/request_stats_card.dart';
import 'package:lemonade_controller/pages/performance/performance_page.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/services/api_client.dart';

void main() {
  group('SystemInfo performance helpers', () {
    test('parses common physical-memory formats', () {
      expect(_systemInfo(memory: '128 GB').physicalMemoryGb, 128);
      expect(_systemInfo(memory: '31.5 GiB').physicalMemoryGb, 31.5);
      expect(_systemInfo(memory: '32,768 MB').physicalMemoryGb, 32);
      expect(_systemInfo(memory: '1.5 TiB').physicalMemoryGb, 1536);
      expect(_systemInfo(memory: 'Unknown').physicalMemoryGb, isNull);
    });

    test('detects legacy and consolidated accelerators', () {
      final consolidated = SystemInfo.fromJson({
        'Physical Memory': '64 GB',
        'devices': {
          'amd_gpu': [
            {'available': true, 'name': 'GPU A', 'vram_gb': 8},
          ],
          'nvidia_gpu': [
            {'available': true, 'name': 'GPU B', 'vram_gb': 16},
          ],
          'amd_npu': {'available': true, 'name': 'NPU'},
        },
      });
      final legacy = SystemInfo.fromJson({
        'devices': {
          'amd_igpu': {'available': true, 'name': 'Legacy iGPU'},
        },
      });

      expect(consolidated.hasGpu, isTrue);
      expect(consolidated.hasNpu, isTrue);
      expect(consolidated.reportedVramGb, 24);
      expect(legacy.hasGpu, isTrue);
    });
  });

  test('history coordinates retain the complete five-minute domain', () {
    final end = DateTime(2026, 7, 11, 12);
    expect(performanceHistoryDuration, const Duration(minutes: 5));
    expect(
      performanceHistoryX(end.subtract(const Duration(minutes: 5)), end),
      0,
    );
    expect(
      performanceHistoryX(end.subtract(const Duration(seconds: 30)), end),
      270,
    );
    expect(performanceHistoryX(end, end), 300);
  });

  test('models request does not include show_all', () async {
    final dio = Dio();
    RequestOptions? request;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response(requestOptions: options, data: {'data': []}),
          );
        },
      ),
    );
    final client = LemonadeApiClient(
      baseUrl: 'http://localhost:8000/api/v1',
      dio: dio,
    );

    await client.getModelsList();

    expect(request?.path, endsWith('/models'));
    expect(request?.queryParameters, isEmpty);
  });

  testWidgets('GPU and NPU remain visible with qualified zero telemetry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final info = _systemInfo(
      memory: '128 GB',
      gpu: const GpuInfo(
        available: true,
        name: 'Integrated GPU',
        family: 'Test',
      ),
      npu: const NpuInfo(
        available: true,
        name: 'Integrated NPU',
        family: 'Test',
      ),
    );
    final state = PerformanceState(
      loading: false,
      samples: [
        SystemStatsSample(
          timestamp: DateTime.now(),
          stats: const SystemStats(
            cpuPercent: 2,
            memoryGb: 12.7,
            gpuPercent: null,
            npuPercent: null,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemInfoProvider.overrideWith((ref) async => info),
          performanceProvider.overrideWith(
            (ref) => _StaticPerformanceNotifier(ref, state),
          ),
        ],
        child: const MaterialApp(home: PerformancePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsNothing);
    expect(find.text('GPU'), findsOneWidget);
    expect(find.text('NPU'), findsOneWidget);

    await tester.tap(find.text('Memory'));
    await tester.pumpAndSettle();
    var chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, 0);
    expect(chart.data.maxX, performanceHistoryDuration.inSeconds);
    expect(chart.data.minY, 0);
    expect(chart.data.maxY, 128);

    await tester.tap(find.text('GPU'));
    await tester.pumpAndSettle();
    expect(find.text('0.0%'), findsWidgets);
    expect(find.textContaining('Telemetry unavailable'), findsNothing);
    chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, 0);
    expect(chart.data.maxX, performanceHistoryDuration.inSeconds);
    expect(chart.data.minY, 0);
    expect(chart.data.maxY, 100);
  });

  testWidgets('home performance meters stay in one compact row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final info = _systemInfo(
      memory: '128 GB',
      gpu: const GpuInfo(
        available: true,
        name: 'Integrated GPU',
        family: 'Test',
      ),
      npu: const NpuInfo(
        available: true,
        name: 'Integrated NPU',
        family: 'Test',
      ),
    );
    final state = PerformanceState(
      loading: false,
      samples: [
        SystemStatsSample(
          timestamp: DateTime.now(),
          stats: const SystemStats(cpuPercent: 2, memoryGb: 12.7),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          systemInfoProvider.overrideWith((ref) async => info),
          performanceProvider.overrideWith(
            (ref) => _StaticPerformanceNotifier(ref, state),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 560,
                height: 226,
                child: PerformanceCard(expand: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final metricY = [
      'CPU',
      'RAM',
      'GPU',
      'NPU',
    ].map((label) => tester.getCenter(find.text(label)).dy).toList();
    expect(metricY.toSet().length, 1);
    expect(find.textContaining('Telemetry unavailable'), findsNothing);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('inference token counts include tok units', (tester) async {
    const state = PerformanceState(
      loading: false,
      requestStats: RequestStats(
        inputTokens: 107,
        outputTokens: 11334,
        promptTokens: 107,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          performanceProvider.overrideWith(
            (ref) => _StaticPerformanceNotifier(ref, state),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 560,
                height: 226,
                child: RequestStatsCard(expand: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Input'), findsOneWidget);
    expect(find.text('Output'), findsOneWidget);
    expect(find.text('Prompt'), findsOneWidget);
    expect(find.text('107 tok'), findsNWidgets(2));
    expect(find.text('11334 tok'), findsOneWidget);
  });
}

SystemInfo _systemInfo({String memory = '', GpuInfo? gpu, NpuInfo? npu}) =>
    SystemInfo(
      osVersion: 'Test OS',
      physicalMemory: memory,
      processor: 'Test CPU',
      cpu: const CpuInfo(
        available: true,
        name: 'Test CPU',
        family: 'Test',
        cores: 8,
        threads: 16,
      ),
      amdGpus: gpu == null ? const [] : [gpu],
      amdNpu: npu,
    );

class _StaticPerformanceNotifier extends PerformanceNotifier {
  _StaticPerformanceNotifier(Ref ref, PerformanceState value)
    : super(
        LemonadeApiClient(baseUrl: 'http://localhost'),
        10,
        ref,
        enabled: false,
      ) {
    state = value;
  }
}
