import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/home/widgets/dashboard_card.dart';
import 'package:lemonade_controller/pages/performance/performance_page.dart';
import 'package:lemonade_controller/pages/performance/widgets/performance_meter.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

class PerformanceCard extends ConsumerWidget {
  final bool expand;

  const PerformanceCard({super.key, this.expand = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceProvider);
    final info = ref.watch(systemInfoProvider).value;
    if (state.systemUnsupported) {
      return const DashboardCard(
        title: 'System Performance',
        icon: Icons.monitor_heart_outlined,
        child: Text('Not supported by this server version.'),
      );
    }

    final stats = state.latest;
    final memoryCapacity = info?.physicalMemoryGb;
    final hasGpu =
        info?.hasGpu ??
        state.samples.any(
          (sample) =>
              sample.stats.gpuPercent != null || sample.stats.vramGb != null,
        );
    final hasNpu =
        info?.hasNpu ??
        state.samples.any((sample) => sample.stats.npuPercent != null);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PerformancePage())),
      child: DashboardCard(
        title: 'System Performance',
        icon: Icons.monitor_heart_outlined,
        trailing: const Icon(Icons.chevron_right),
        expandContent: expand,
        child: stats == null
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final metrics = <_HomeMetricData>[
                      _HomeMetricData(
                        label: 'CPU',
                        icon: Icons.memory,
                        percent: stats.cpuPercent,
                        valueLabel: stats.cpuPercent == null
                            ? '—'
                            : '${stats.cpuPercent!.toStringAsFixed(1)}%',
                      ),
                      _HomeMetricData(
                        label: 'RAM',
                        icon: Icons.storage_outlined,
                        percent:
                            stats.memoryGb != null && memoryCapacity != null
                            ? stats.memoryGb! / memoryCapacity * 100
                            : null,
                        valueLabel: stats.memoryGb == null
                            ? 'Unavailable'
                            : memoryCapacity == null
                            ? '${stats.memoryGb!.toStringAsFixed(1)} GiB'
                            : '${(stats.memoryGb! / memoryCapacity * 100).toStringAsFixed(1)}%',
                        subtitle:
                            stats.memoryGb != null && memoryCapacity != null
                            ? '${stats.memoryGb!.toStringAsFixed(1)} / ${memoryCapacity.toStringAsFixed(1)} GiB'
                            : memoryCapacity == null
                            ? 'Capacity unavailable'
                            : null,
                      ),
                      if (hasGpu)
                        _HomeMetricData(
                          label: 'GPU',
                          icon: Icons.developer_board_outlined,
                          percent: stats.gpuPercent ?? 0,
                          valueLabel:
                              '${(stats.gpuPercent ?? 0).toStringAsFixed(1)}%',
                          subtitle: _vramLabel(
                            stats.vramGb,
                            info?.reportedVramGb,
                          ),
                          telemetryUnavailable: stats.gpuPercent == null,
                        ),
                      if (hasNpu)
                        _HomeMetricData(
                          label: 'NPU',
                          icon: Icons.auto_awesome_outlined,
                          percent: stats.npuPercent ?? 0,
                          valueLabel:
                              '${(stats.npuPercent ?? 0).toStringAsFixed(1)}%',
                          telemetryUnavailable: stats.npuPercent == null,
                        ),
                    ];
                    final meterSize = (constraints.maxWidth / metrics.length)
                        .clamp(58.0, 72.0);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final metric in metrics)
                          Expanded(
                            child: _HomeMetric(
                              metric: metric,
                              meterSize: meterSize,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }

  String? _vramLabel(double? used, double? capacity) {
    if (used == null) return null;
    if (capacity != null && capacity > 0) {
      return 'VRAM ${used.toStringAsFixed(1)} / ${capacity.toStringAsFixed(1)} GiB';
    }
    return 'VRAM ${used.toStringAsFixed(1)} GiB';
  }
}

class _HomeMetricData {
  final String label;
  final IconData icon;
  final double? percent;
  final String valueLabel;
  final String? subtitle;
  final bool telemetryUnavailable;

  const _HomeMetricData({
    required this.label,
    required this.icon,
    required this.percent,
    required this.valueLabel,
    this.subtitle,
    this.telemetryUnavailable = false,
  });
}

class _HomeMetric extends StatelessWidget {
  final _HomeMetricData metric;
  final double meterSize;

  const _HomeMetric({required this.metric, required this.meterSize});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PerformanceMeter(
          label: metric.label,
          percent: metric.percent,
          valueLabel: metric.valueLabel,
          icon: metric.icon,
          telemetryUnavailable: metric.telemetryUnavailable,
          size: meterSize,
        ),
        if (metric.subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 2, right: 2),
            child: Text(
              metric.subtitle!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
