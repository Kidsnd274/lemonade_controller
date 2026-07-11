import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/pages/downloads/downloads_page.dart';
import 'package:lemonade_controller/pages/home/widgets/dashboard_card.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

class DownloadProgressCard extends ConsumerWidget {
  const DownloadProgressCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadsProvider);
    if (state.unsupported) return const SizedBox.shrink();
    final active = state.jobs.where((job) => job.running).toList();
    if (active.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DownloadsPage())),
      child: DashboardCard(
        title: 'Downloads',
        icon: Icons.downloading,
        trailing: const Icon(Icons.chevron_right),
        child: Column(
          children: [
            for (final job in active) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(LemonadeModel.stripIdPrefix(job.modelName)),
                  ),
                  Text('${job.percent.toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: (job.percent / 100).clamp(0, 1)),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
