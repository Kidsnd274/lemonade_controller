import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/home/widgets/dashboard_card.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

class LoadingModelsCard extends ConsumerWidget {
  const LoadingModelsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadingIds = ref.watch(loadingModelsProvider);

    if (loadingIds.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return DashboardCard(
      title: 'Loading Models',
      icon: Icons.sync,
      child: Column(
        children: [
          for (int i = 0; i < loadingIds.length; i++) ...[
            if (i > 0) const Divider(height: 16),
            _LoadingModelRow(
              modelId: loadingIds.elementAt(i),
              theme: theme,
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingModelRow extends StatelessWidget {
  final String modelId;
  final ThemeData theme;

  const _LoadingModelRow({required this.modelId, required this.theme});

  String get _displayName => modelId.replaceFirst('user.', '');

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _displayName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
