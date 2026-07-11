import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/home/widgets/dashboard_card.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

class RequestStatsCard extends ConsumerWidget {
  const RequestStatsCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceProvider);
    if (state.requestUnsupported) {
      return const DashboardCard(
        title: 'Last Inference',
        icon: Icons.speed_outlined,
        child: Text('Not supported by this server version.'),
      );
    }
    final stats = state.requestStats;
    return DashboardCard(
      title: 'Last Inference',
      icon: Icons.speed_outlined,
      child: stats == null || stats.isEmpty
          ? const Text('No inference statistics are available yet.')
          : Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                if (stats.timeToFirstToken != null)
                  Text('TTFT ${stats.timeToFirstToken!.toStringAsFixed(2)}s'),
                if (stats.tokensPerSecond != null)
                  Text('${stats.tokensPerSecond!.toStringAsFixed(1)} tok/s'),
                if (stats.inputTokens != null)
                  Text('Input ${stats.inputTokens}'),
                if (stats.outputTokens != null)
                  Text('Output ${stats.outputTokens}'),
                if (stats.promptTokens != null)
                  Text('Prompt ${stats.promptTokens}'),
              ],
            ),
    );
  }
}
