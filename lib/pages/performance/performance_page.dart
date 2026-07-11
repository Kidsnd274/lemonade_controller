import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/system_stats.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

class PerformancePage extends ConsumerWidget {
  const PerformancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceProvider);
    final samples = state.samples;
    final tabs = <_MetricTab>[
      const _MetricTab('Overview', Icons.dashboard_outlined, null),
      if (samples.any((s) => s.stats.cpuPercent != null))
        _MetricTab('CPU', Icons.memory, (s) => s.cpuPercent),
      if (samples.any((s) => s.stats.memoryGb != null))
        _MetricTab('Memory', Icons.storage_outlined, (s) => s.memoryGb),
      if (samples.any(
        (s) => s.stats.gpuPercent != null || s.stats.vramGb != null,
      ))
        const _MetricTab('GPU / VRAM', Icons.developer_board_outlined, null),
      if (samples.any((s) => s.stats.npuPercent != null))
        _MetricTab('NPU', Icons.auto_awesome_outlined, (s) => s.npuPercent),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Performance'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final tab in tabs)
                Tab(icon: Icon(tab.icon), text: tab.title),
            ],
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
            : state.loading && samples.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (state.systemError != null && samples.isNotEmpty)
                    MaterialBanner(
                      content: Text('Showing last data: ${state.systemError}'),
                      actions: const [SizedBox.shrink()],
                    ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final tab in tabs)
                          if (tab.title == 'Overview')
                            _Overview(samples: samples)
                          else if (tab.title == 'GPU / VRAM')
                            _GpuView(samples: samples)
                          else
                            _MetricView(
                              title: tab.title,
                              samples: samples,
                              value: tab.value!,
                              unit: tab.title == 'Memory' ? 'GiB' : '%',
                            ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MetricTab {
  final String title;
  final IconData icon;
  final double? Function(SystemStats)? value;
  const _MetricTab(this.title, this.icon, this.value);
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

class _Overview extends StatelessWidget {
  final List<SystemStatsSample> samples;
  const _Overview({required this.samples});

  @override
  Widget build(BuildContext context) {
    final latest = samples.isEmpty ? null : samples.last.stats;
    final values = <(String, IconData, double?, String)>[
      ('CPU', Icons.memory, latest?.cpuPercent, '%'),
      ('Memory', Icons.storage_outlined, latest?.memoryGb, 'GiB'),
      ('GPU', Icons.developer_board_outlined, latest?.gpuPercent, '%'),
      ('VRAM', Icons.video_settings_outlined, latest?.vramGb, 'GiB'),
      ('NPU', Icons.auto_awesome_outlined, latest?.npuPercent, '%'),
    ].where((entry) => entry.$3 != null).toList();
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisExtent: 240,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: values.length,
      itemBuilder: (context, index) {
        final metric = values[index];
        double? Function(SystemStats) getter = switch (metric.$1) {
          'CPU' => (s) => s.cpuPercent,
          'Memory' => (s) => s.memoryGb,
          'GPU' => (s) => s.gpuPercent,
          'VRAM' => (s) => s.vramGb,
          _ => (s) => s.npuPercent,
        };
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(metric.$2, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      metric.$1,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    Text('${metric.$3!.toStringAsFixed(1)} ${metric.$4}'),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _Chart(samples: samples, value: getter),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricView extends StatelessWidget {
  final String title;
  final String unit;
  final List<SystemStatsSample> samples;
  final double? Function(SystemStats) value;
  const _MetricView({
    required this.title,
    required this.samples,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final latest = samples.isEmpty ? null : value(samples.last.stats);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          Text(
            latest == null
                ? 'Unavailable'
                : '${latest.toStringAsFixed(2)} $unit',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _Chart(samples: samples, value: value),
          ),
          const SizedBox(height: 8),
          const Text('Rolling five-minute history'),
        ],
      ),
    );
  }
}

class _GpuView extends StatelessWidget {
  final List<SystemStatsSample> samples;
  const _GpuView({required this.samples});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (samples.any((s) => s.stats.gpuPercent != null))
        SizedBox(
          height: 300,
          child: _MetricView(
            title: 'GPU utilization',
            samples: samples,
            value: (s) => s.gpuPercent,
            unit: '%',
          ),
        ),
      if (samples.any((s) => s.stats.vramGb != null))
        SizedBox(
          height: 300,
          child: _MetricView(
            title: 'VRAM usage',
            samples: samples,
            value: (s) => s.vramGb,
            unit: 'GiB',
          ),
        ),
    ],
  );
}

class _Chart extends StatelessWidget {
  final List<SystemStatsSample> samples;
  final double? Function(SystemStats) value;
  const _Chart({required this.samples, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final segments = <List<FlSpot>>[];
    var current = <FlSpot>[];
    for (var i = 0; i < samples.length; i++) {
      final point = value(samples[i].stats);
      if (point == null) {
        if (current.isNotEmpty) segments.add(current);
        current = [];
      } else {
        current.add(FlSpot(i.toDouble(), point));
      }
    }
    if (current.isNotEmpty) segments.add(current);
    if (segments.isEmpty) return const Center(child: Text('No data'));
    return LineChart(
      LineChartData(
        lineTouchData: const LineTouchData(enabled: true),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          for (final segment in segments)
            LineChartBarData(
              spots: segment,
              color: color,
              barWidth: 2,
              isCurved: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: color.withAlpha(28)),
            ),
        ],
      ),
    );
  }
}
