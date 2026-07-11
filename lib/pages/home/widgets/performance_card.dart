import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/home/widgets/dashboard_card.dart';
import 'package:lemonade_controller/pages/performance/performance_page.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

class PerformanceCard extends ConsumerWidget {
  const PerformanceCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceProvider);
    if (state.systemUnsupported) {
      return const DashboardCard(
        title: 'System Performance',
        icon: Icons.monitor_heart_outlined,
        child: Text('Not supported by this server version.'),
      );
    }
    final stats = state.latest;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PerformancePage())),
      child: DashboardCard(
        title: 'System Performance',
        icon: Icons.monitor_heart_outlined,
        trailing: const Icon(Icons.chevron_right),
        child: stats == null
            ? const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  if (stats.cpuPercent != null)
                    _Value('CPU', stats.cpuPercent!, '%'),
                  if (stats.memoryGb != null)
                    _Value('RAM', stats.memoryGb!, 'GiB'),
                  if (stats.gpuPercent != null)
                    _Value('GPU', stats.gpuPercent!, '%'),
                  if (stats.vramGb != null)
                    _Value('VRAM', stats.vramGb!, 'GiB'),
                  if (stats.npuPercent != null)
                    _Value('NPU', stats.npuPercent!, '%'),
                ],
              ),
      ),
    );
  }
}

class _Value extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  const _Value(this.label, this.value, this.unit);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      Text(
        '${value.toStringAsFixed(1)} $unit',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ],
  );
}
