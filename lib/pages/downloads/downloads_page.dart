import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/download_job.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/utils/format.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadsProvider);
    if (state.unsupported) {
      return const Center(child: Text('Not supported by this server version.'));
    }
    if (state.loading && state.jobs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.jobs.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(downloadsProvider.notifier).refresh(),
        child: ListView(
          children: const [
            SizedBox(height: 160),
            Icon(Icons.download_done_outlined, size: 48),
            SizedBox(height: 12),
            Center(child: Text('No server-managed downloads')),
          ],
        ),
      );
    }
    final active = state.jobs.where((job) => job.running).toList();
    final paused = state.jobs
        .where((job) => !job.running && job.status == DownloadStatus.paused)
        .toList();
    final finished = state.jobs
        .where((job) => !active.contains(job) && !paused.contains(job))
        .toList();
    return RefreshIndicator(
      onRefresh: () => ref.read(downloadsProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(state.error!),
              ),
            ),
          if (active.isNotEmpty) _Section(title: 'Active', jobs: active),
          if (paused.isNotEmpty) _Section(title: 'Paused', jobs: paused),
          if (finished.isNotEmpty) _Section(title: 'Finished', jobs: finished),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<DownloadJob> jobs;
  const _Section({required this.title, required this.jobs});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      for (final job in jobs) _DownloadCard(job: job),
    ],
  );
}

class _DownloadCard extends ConsumerWidget {
  final DownloadJob job;
  const _DownloadCard({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final overallTotal = job.totalDownloadSize > 0
        ? job.totalDownloadSize
        : job.bytesTotal;
    final overallDone = job.cumulativeBytesDownloaded > 0
        ? job.cumulativeBytesDownloaded
        : job.bytesDownloaded;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusIcon(job: job),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LemonadeModel.stripIdPrefix(job.modelName),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Chip(label: Text(job.status.name)),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: (job.percent / 100).clamp(0, 1)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (overallTotal > 0)
                  Text(
                    '${formatFileSize(overallDone.toDouble())} / '
                    '${formatFileSize(overallTotal.toDouble())}',
                  ),
                if (job.speedBytesPerSecond != null)
                  Text(formatSpeed(job.speedBytesPerSecond!)),
                if (job.file?.isNotEmpty == true) Text(job.file!),
                if (job.totalFiles > 0)
                  Text('File ${job.fileIndex}/${job.totalFiles}'),
              ],
            ),
            if (job.error != null) ...[
              const SizedBox(height: 8),
              Text(
                job.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (job.canPause)
                  TextButton.icon(
                    onPressed: () => ref
                        .read(downloadsProvider.notifier)
                        .control(job, 'pause'),
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                if (job.canResume)
                  TextButton.icon(
                    onPressed: () =>
                        ref.read(downloadsProvider.notifier).resume(job),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  ),
                if (!job.isTerminal || job.running)
                  TextButton.icon(
                    onPressed: () => ref
                        .read(downloadsProvider.notifier)
                        .control(job, 'cancel'),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                if (!job.running)
                  TextButton.icon(
                    onPressed: () => ref
                        .read(downloadsProvider.notifier)
                        .control(job, 'remove'),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final DownloadJob job;
  const _StatusIcon({required this.job});
  @override
  Widget build(BuildContext context) {
    if (job.running) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final (icon, color) = switch (job.status) {
      DownloadStatus.completed => (Icons.check_circle, Colors.green),
      DownloadStatus.error => (
        Icons.error,
        Theme.of(context).colorScheme.error,
      ),
      DownloadStatus.paused => (Icons.pause_circle, Colors.orange),
      _ => (Icons.download_outlined, Theme.of(context).colorScheme.primary),
    };
    return Icon(icon, color: color);
  }
}
