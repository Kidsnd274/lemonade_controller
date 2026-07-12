import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/home/widgets/dashboard_card.dart';
import 'package:lemonade_controller/pages/home/widgets/inference_activity_panel.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/providers/inference_activity_provider.dart';
import 'package:lemonade_controller/providers/service_providers.dart';
import 'package:lemonade_controller/services/settings_service.dart';

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
          final loadedCount = health.allModelsLoaded.length;
          final pinnedCount = health.pinnedModels.values.fold<int>(
            0,
            (total, count) => total + count,
          );
          final settings = ref.watch(settingsProvider).value;
          final profile = ref.watch(activeServerProfileProvider);
          final warningKey = '${profile.id}@${health.version}';
          final showCompatibilityWarning =
              health.isOlderThanRecommended &&
              !(settings?.dismissedCompatibilityWarnings.contains(warningKey) ??
                  false);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showCompatibilityWarning) ...[
                Container(
                  padding: const EdgeInsets.only(left: 12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Older Lemonade Server detected. Some features may not work.',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Dismiss',
                        onPressed: () => ref
                            .read(settingsProvider.notifier)
                            .dismissCompatibilityWarning(
                              profile.id,
                              health.version,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  Icon(
                    health.isHealthy ? Icons.check_circle : Icons.error,
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
                  const _InferenceReadyIndicator(),
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
              _ServerSummary(
                name: profile.name,
                address: profile.displayAddress,
                websocketPort: health.websocketPort,
                loadedCount: loadedCount,
                pinnedCount: pinnedCount,
              ),
              const _InferenceActivitySection(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Model Slots',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$loadedCount loaded',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: health.maxModels.entries.map((entry) {
                  final used = loadedByType[entry.key] ?? 0;
                  final pinned = health.pinnedModels[entry.key] ?? 0;
                  final max = entry.value;
                  return _SlotChip(
                    label: entry.key.toUpperCase(),
                    used: used,
                    max: max,
                    pinned: pinned,
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

class _InferenceActivitySection extends ConsumerWidget {
  const _InferenceActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isForeground = ref.watch(appForegroundProvider);
    if (!isForeground) return const SizedBox.shrink();

    final activity = ref.watch(inferenceActivityProvider);
    if (!activity.shouldShow || activity.activeRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InferenceActivityPanel(activity: activity),
    );
  }
}

class _InferenceReadyIndicator extends ConsumerWidget {
  const _InferenceReadyIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isForeground = ref.watch(appForegroundProvider);
    if (!isForeground) return const SizedBox.shrink();

    final isReady = ref.watch(
      inferenceActivityProvider.select(
        (activity) => activity.shouldShow && activity.activeRequests.isEmpty,
      ),
    );
    if (!isReady) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 430;
    return Tooltip(
      message: 'Ready for requests',
      child: Container(
        margin: const EdgeInsets.only(left: 10),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_rounded,
              size: 13,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 3),
            Text(
              compact ? 'Ready' : 'Ready for requests',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerSummary extends StatelessWidget {
  final String name;
  final String address;
  final int websocketPort;
  final int loadedCount;
  final int pinnedCount;

  const _ServerSummary({
    required this.name,
    required this.address,
    required this.websocketPort,
    required this.loadedCount,
    required this.pinnedCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = _ServerIdentity(name: name, address: address);
          final facts = <Widget>[
            _SummaryFact(
              icon: Icons.memory_outlined,
              label: '$loadedCount loaded',
            ),
            if (pinnedCount > 0)
              _SummaryFact(
                icon: Icons.push_pin_outlined,
                label: '$pinnedCount pinned',
              ),
            _SummaryFact(
              icon: Icons.cable_outlined,
              label: 'WS $websocketPort',
            ),
          ];
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                identity,
                const SizedBox(height: 9),
                Wrap(spacing: 14, runSpacing: 6, children: facts),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 14),
              ...facts.expand(
                (fact) => [
                  fact,
                  if (fact != facts.last) const SizedBox(width: 14),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ServerIdentity extends StatelessWidget {
  final String name;
  final String address;

  const _ServerIdentity({required this.name, required this.address});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            Icons.hub_outlined,
            size: 19,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                address,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryFact extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryFact({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
  final int pinned;

  const _SlotChip({
    required this.label,
    required this.used,
    required this.max,
    this.pinned = 0,
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
        '$label $used/${max == -1 ? '∞' : max}${pinned > 0 ? ' · $pinned pinned' : ''}',
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
