import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/pull_progress_event.dart';
import 'package:lemonade_controller/pages/home/widgets/dashboard_card.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/utils/format.dart';

class DownloadProgressCard extends ConsumerWidget {
  const DownloadProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(pullProgressProvider);

    if (progress.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return DashboardCard(
      title: 'Downloading Models',
      icon: Icons.downloading,
      child: Column(
        children: [
          for (int i = 0; i < progress.length; i++) ...[
            if (i > 0) const Divider(height: 16),
            _DownloadProgressRow(
              modelName: progress.keys.elementAt(i),
              event: progress.values.elementAt(i),
              theme: theme,
            ),
          ],
        ],
      ),
    );
  }
}

class _DownloadProgressRow extends ConsumerWidget {
  final String modelName;
  final PullProgressEvent event;
  final ThemeData theme;

  const _DownloadProgressRow({
    required this.modelName,
    required this.event,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percent = event.percent ?? 0;
    final inProgress = !event.isComplete && !event.isError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (event.isComplete)
              const Icon(Icons.check_circle, size: 18, color: Colors.green)
            else if (event.isError)
              Icon(Icons.error, size: 18, color: theme.colorScheme.error)
            else
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                modelName.replaceFirst('user.', ''),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (inProgress)
              Text(
                '$percent%',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            if (inProgress) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Cancel download',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: () {
                  ref
                      .read(pullProgressProvider.notifier)
                      .cancelPull(modelName);
                },
              ),
            ],
          ],
        ),
        if (event.isError) ...[
          const SizedBox(height: 4),
          Text(
            event.errorMessage ?? 'Download failed',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ] else if (event.isComplete) ...[
          const SizedBox(height: 4),
          Text(
            'Download complete',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
          ),
        ] else ...[
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: percent / 100.0,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (event.file != null)
                Expanded(
                  child: Text(
                    event.file!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (event.fileIndex != null && event.totalFiles != null)
                Text(
                  'File ${event.fileIndex}/${event.totalFiles}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (event.bytesDownloaded != null &&
                  event.bytesTotal != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${formatFileSize(event.bytesDownloaded!.toDouble())} / ${formatFileSize(event.bytesTotal!.toDouble())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (event.speedBytesPerSec != null) ...[
                const SizedBox(width: 8),
                Text(
                  formatSpeed(event.speedBytesPerSec!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
