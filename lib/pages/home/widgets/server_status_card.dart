import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/home/widgets/dashboard_card.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

class ServerStatusCard extends ConsumerWidget {
  const ServerStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(healthInfoProvider);
    final theme = Theme.of(context);

    return DashboardCard(
      title: 'Server Status',
      icon: Icons.dns_outlined,
      child: healthAsync.when(
        data: (health) {
          final loadedByType = health.loadedCountByType;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    health.isHealthy
                        ? Icons.check_circle
                        : Icons.error,
                    color: health.isHealthy
                        ? Colors.green
                        : theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    health.isHealthy ? 'Online' : 'Unhealthy',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: health.isHealthy
                          ? Colors.green
                          : theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'v${health.version}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (health.activeModel != null) ...[
                _InfoRow(
                  label: 'Active Model',
                  value: health.activeModel!
                      .replaceFirst('user.', ''),
                ),
                const SizedBox(height: 4),
              ],
              _InfoRow(
                label: 'WebSocket Port',
                value: health.websocketPort.toString(),
              ),
              const SizedBox(height: 12),
              Text(
                'Model Slots',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: health.maxModels.entries.map((entry) {
                  final used = loadedByType[entry.key] ?? 0;
                  final max = entry.value;
                  return _SlotChip(
                    label: entry.key.toUpperCase(),
                    used: used,
                    max: max,
                  );
                }).toList(),
              ),
            ],
          );
        },
        error: (err, _) => _ErrorContent(error: err.toString()),
        loading: () => const _LoadingContent(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  final String label;
  final int used;
  final int max;

  const _SlotChip({
    required this.label,
    required this.used,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = used > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label $used/$max',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: isActive
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ErrorContent extends StatelessWidget {
  final String error;
  const _ErrorContent({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
