import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/home/widgets/dashboard_card.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

class RequestStatsCard extends ConsumerWidget {
  final bool expand;

  const RequestStatsCard({super.key, this.expand = false});

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
      expandContent: expand,
      child: stats == null || stats.isEmpty
          ? const Text('No inference statistics are available yet.')
          : _InferenceSummary(
              tokensPerSecond: stats.tokensPerSecond,
              timeToFirstToken: stats.timeToFirstToken,
              inputTokens: stats.inputTokens,
              outputTokens: stats.outputTokens,
              promptTokens: stats.promptTokens,
            ),
    );
  }
}

class _InferenceSummary extends StatelessWidget {
  final double? tokensPerSecond;
  final double? timeToFirstToken;
  final int? inputTokens;
  final int? outputTokens;
  final int? promptTokens;

  const _InferenceSummary({
    required this.tokensPerSecond,
    required this.timeToFirstToken,
    required this.inputTokens,
    required this.outputTokens,
    required this.promptTokens,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // Keep the anti-aliased bottom border clear of the card's clip edge.
      padding: const EdgeInsets.only(bottom: 1),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _InferenceMetric(
                      label: 'Generation rate',
                      value: tokensPerSecond == null
                          ? '—'
                          : '${tokensPerSecond!.toStringAsFixed(1)} tok/s',
                      icon: Icons.bolt_rounded,
                      emphasized: true,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _InferenceMetric(
                      label: 'Time to first token',
                      value: timeToFirstToken == null
                          ? '—'
                          : '${timeToFirstToken!.toStringAsFixed(2)} s',
                      icon: Icons.timer_outlined,
                      emphasized: true,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _InferenceMetric(
                      label: 'Input',
                      value: _tokens(inputTokens),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _InferenceMetric(
                      label: 'Output',
                      value: _tokens(outputTokens),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _InferenceMetric(
                      label: 'Prompt',
                      value: _tokens(promptTokens),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tokens(int? value) => value == null ? '—' : '$value tok';
}

class _InferenceMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool emphasized;

  const _InferenceMetric({
    required this.label,
    required this.value,
    this.icon,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style:
              (emphasized
                      ? theme.textTheme.titleLarge
                      : theme.textTheme.titleMedium)
                  ?.copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: emphasized ? 14 : 12,
        vertical: emphasized ? 10 : 8,
      ),
      child: icon == null
          ? content
          : Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 20, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(child: content),
              ],
            ),
    );
  }
}
