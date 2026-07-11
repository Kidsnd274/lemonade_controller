import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/system_info.dart';
import 'package:lemonade_controller/models/system_stats.dart';
import 'package:lemonade_controller/pages/performance/widgets/performance_meter.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

enum _MetricKind { cpu, memory, gpu, npu }

class PerformancePage extends ConsumerWidget {
  const PerformancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceProvider);
    final infoAsync = ref.watch(systemInfoProvider);
    final info = infoAsync.value;
    final hasGpu =
        info?.hasGpu ??
        state.samples.any(
          (sample) =>
              sample.stats.gpuPercent != null || sample.stats.vramGb != null,
        );
    final hasNpu =
        info?.hasNpu ??
        state.samples.any((sample) => sample.stats.npuPercent != null);
    final metrics = <_MetricKind>[
      _MetricKind.cpu,
      _MetricKind.memory,
      if (hasGpu) _MetricKind.gpu,
      if (hasNpu) _MetricKind.npu,
    ];

    return DefaultTabController(
      length: metrics.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Performance'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final metric in metrics) _tab(metric)],
          ),
          actions: [
            IconButton(
              onPressed: () => ref.read(performanceProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: state.systemUnsupported
            ? const _Unsupported()
            : state.loading && state.samples.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (state.systemError != null && state.samples.isNotEmpty)
                    MaterialBanner(
                      content: Text(
                        'Showing the last available data: ${state.systemError}',
                      ),
                      actions: const [SizedBox.shrink()],
                    ),
                  if (infoAsync.hasError)
                    MaterialBanner(
                      content: const Text(
                        'Hardware details are unavailable. Device tabs are based on available telemetry.',
                      ),
                      actions: const [SizedBox.shrink()],
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final metric in metrics)
                          _MetricView(
                            metric: metric,
                            samples: state.samples,
                            info: info,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Tab _tab(_MetricKind metric) => switch (metric) {
    _MetricKind.cpu => const Tab(icon: Icon(Icons.memory), text: 'CPU'),
    _MetricKind.memory => const Tab(
      icon: Icon(Icons.storage_outlined),
      text: 'Memory',
    ),
    _MetricKind.gpu => const Tab(
      icon: Icon(Icons.developer_board_outlined),
      text: 'GPU',
    ),
    _MetricKind.npu => const Tab(
      icon: Icon(Icons.auto_awesome_outlined),
      text: 'NPU',
    ),
  };
}

class _Unsupported extends StatelessWidget {
  const _Unsupported();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('Not supported by this server version.'),
    ),
  );
}

class _MetricView extends StatelessWidget {
  final _MetricKind metric;
  final List<SystemStatsSample> samples;
  final SystemInfo? info;

  const _MetricView({
    required this.metric,
    required this.samples,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    final latest = samples.isEmpty ? null : samples.last.stats;
    final rawValue = _rawValue(latest);
    final hardwarePresent = switch (metric) {
      _MetricKind.gpu => info?.hasGpu ?? rawValue != null,
      _MetricKind.npu => info?.hasNpu ?? rawValue != null,
      _ => true,
    };
    final telemetryUnavailable =
        (metric == _MetricKind.gpu || metric == _MetricKind.npu) &&
        hardwarePresent &&
        rawValue == null;
    final displayValue = telemetryUnavailable ? 0.0 : rawValue;
    final memoryCapacity = info?.physicalMemoryGb;
    final percent = metric == _MetricKind.memory
        ? displayValue != null && memoryCapacity != null
              ? displayValue / memoryCapacity * 100
              : null
        : displayValue;
    final maxY = metric == _MetricKind.memory
        ? memoryCapacity ?? _fallbackMemoryMax(samples)
        : 100.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 28.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            32,
          ),
          children: [
            Wrap(
              spacing: 28,
              runSpacing: 20,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PerformanceMeter(
                  label: _title,
                  percent: percent,
                  valueLabel: _valueLabel(displayValue, memoryCapacity),
                  icon: _icon,
                  telemetryUnavailable: telemetryUnavailable,
                  size: constraints.maxWidth < 600 ? 112 : 136,
                ),
                SizedBox(
                  width: math.max(240, constraints.maxWidth - 260),
                  child: _MetricDetails(
                    title: _title,
                    detail: _hardwareDetail(info),
                    value: _valueLabel(displayValue, memoryCapacity),
                    memoryCapacityUnavailable:
                        metric == _MetricKind.memory && memoryCapacity == null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: constraints.maxHeight < 620 ? 300 : 410,
              child: _HistoryChart(
                samples: samples,
                value: (stats) {
                  final value = _rawValue(stats);
                  return telemetryUnavailable && value == null ? 0 : value;
                },
                maxY: maxY,
                unit: metric == _MetricKind.memory ? 'GiB' : '%',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(_historyLabel),
                const Spacer(),
                const Text('Now'),
              ],
            ),
            if (metric == _MetricKind.memory) ...[
              const SizedBox(height: 10),
              Text(
                'Capacity is reported by the server. Unified-memory RAM/VRAM partitioning is not currently exposed.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (metric == _MetricKind.gpu) ...[
              const SizedBox(height: 24),
              _VramPanel(samples: samples, info: info),
            ],
          ],
        );
      },
    );
  }

  String get _title => switch (metric) {
    _MetricKind.cpu => 'CPU utilization',
    _MetricKind.memory => 'Memory usage',
    _MetricKind.gpu => 'GPU utilization',
    _MetricKind.npu => 'NPU utilization',
  };

  IconData get _icon => switch (metric) {
    _MetricKind.cpu => Icons.memory,
    _MetricKind.memory => Icons.storage_outlined,
    _MetricKind.gpu => Icons.developer_board_outlined,
    _MetricKind.npu => Icons.auto_awesome_outlined,
  };

  double? _rawValue(SystemStats? stats) => switch (metric) {
    _MetricKind.cpu => stats?.cpuPercent,
    _MetricKind.memory => stats?.memoryGb,
    _MetricKind.gpu => stats?.gpuPercent,
    _MetricKind.npu => stats?.npuPercent,
  };

  String _valueLabel(double? value, double? memoryCapacity) {
    if (value == null) return 'Unavailable';
    if (metric != _MetricKind.memory) return '${value.toStringAsFixed(1)}%';
    if (memoryCapacity == null) return '${value.toStringAsFixed(1)} GiB';
    return '${value.toStringAsFixed(1)} / ${memoryCapacity.toStringAsFixed(1)} GiB';
  }

  String _hardwareDetail(SystemInfo? info) => switch (metric) {
    _MetricKind.cpu =>
      info == null
          ? ''
          : [
                  info.cpu.name,
                  '${info.cpu.cores} cores / ${info.cpu.threads} threads',
                ]
                .where((value) => !value.startsWith('0 ') && value.isNotEmpty)
                .join(' · '),
    _MetricKind.memory => info?.physicalMemory ?? '',
    _MetricKind.gpu =>
      info == null
          ? ''
          : [...info.allAmdGpus, ...info.allNvidiaGpus]
                .map((gpu) => gpu.name)
                .where((name) => name.isNotEmpty)
                .join(' · '),
    _MetricKind.npu => info?.amdNpu?.name ?? '',
  };
}

class _MetricDetails extends StatelessWidget {
  final String title;
  final String detail;
  final String value;
  final bool memoryCapacityUnavailable;

  const _MetricDetails({
    required this.title,
    required this.detail,
    required this.value,
    required this.memoryCapacityUnavailable,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            detail,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (memoryCapacityUnavailable) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Capacity unavailable; percentage cannot be calculated.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _VramPanel extends StatelessWidget {
  final List<SystemStatsSample> samples;
  final SystemInfo? info;

  const _VramPanel({required this.samples, required this.info});

  @override
  Widget build(BuildContext context) {
    final latest = samples.isEmpty ? null : samples.last.stats.vramGb;
    final capacity = info?.reportedVramGb ?? 0;
    final hasCapacity = capacity > 0;
    final percent = latest != null && hasCapacity
        ? latest / capacity * 100
        : null;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.video_settings_outlined),
                const SizedBox(width: 10),
                Text('VRAM', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  latest == null
                      ? '—'
                      : hasCapacity
                      ? '${latest.toStringAsFixed(1)} / ${capacity.toStringAsFixed(1)} GiB'
                      : '${latest.toStringAsFixed(1)} GiB',
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: percent?.clamp(0, 100).toDouble() == null
                  ? 0
                  : percent!.clamp(0, 100) / 100,
              minHeight: 10,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 10),
            Text(
              hasCapacity
                  ? 'Dedicated capacity reported by the server.'
                  : 'Shared/unified-memory capacity is not exposed by the server.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  final List<SystemStatsSample> samples;
  final double? Function(SystemStats) value;
  final double maxY;
  final String unit;

  const _HistoryChart({
    required this.samples,
    required this.value,
    required this.maxY,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final maxX = performanceHistoryDuration.inSeconds.toDouble();
    final segments = <List<FlSpot>>[];
    var current = <FlSpot>[];
    for (final sample in samples) {
      final point = value(sample.stats);
      final x = performanceHistoryX(sample.timestamp, now);
      if (point == null || x < 0 || x > maxX) {
        if (current.isNotEmpty) segments.add(current);
        current = [];
      } else {
        current.add(FlSpot(x, point.clamp(0, maxY).toDouble()));
      }
    }
    if (current.isNotEmpty) segments.add(current);

    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 18, 8),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: maxX,
            minY: 0,
            maxY: maxY,
            lineTouchData: LineTouchData(enabled: segments.isNotEmpty),
            gridData: FlGridData(
              show: true,
              horizontalInterval: maxY / 4,
              verticalInterval: maxX / 5,
              getDrawingHorizontalLine: (_) => FlLine(
                color: theme.colorScheme.outlineVariant.withAlpha(100),
                strokeWidth: 1,
              ),
              getDrawingVerticalLine: (_) => FlLine(
                color: theme.colorScheme.outlineVariant.withAlpha(70),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 54,
                  interval: maxY / 4,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      unit == '%'
                          ? '${value.round()}%'
                          : '${value.toStringAsFixed(value >= 10 ? 0 : 1)} GiB',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              for (final segment in segments)
                LineChartBarData(
                  spots: segment,
                  color: color,
                  barWidth: 2.5,
                  isCurved: segment.length > 2,
                  preventCurveOverShooting: true,
                  dotData: FlDotData(show: segment.length == 1),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withAlpha(30),
                  ),
                ),
            ],
          ),
          duration: const Duration(milliseconds: 250),
        ),
      ),
    );
  }
}

double _fallbackMemoryMax(List<SystemStatsSample> samples) {
  final largest = samples
      .map((sample) => sample.stats.memoryGb ?? 0)
      .fold<double>(0, math.max);
  return math.max(1, (largest * 1.2).ceilToDouble());
}

String get _historyLabel {
  final minutes = performanceHistoryDuration.inMinutes;
  return '$minutes minute${minutes == 1 ? '' : 's'} ago';
}
