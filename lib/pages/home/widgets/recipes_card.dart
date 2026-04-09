import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/system_info.dart';
import 'package:lemonade_controller/pages/home/widgets/dashboard_card.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

class RecipesCard extends ConsumerWidget {
  const RecipesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sysInfoAsync = ref.watch(systemInfoProvider);

    return DashboardCard(
      title: 'Recipes & Backends',
      icon: Icons.extension_outlined,
      child: sysInfoAsync.when(
        data: (info) {
          if (info.recipes.isEmpty) {
            return const Text('No recipes available.');
          }

          return Column(
            children: [
              for (int i = 0; i < info.recipes.length; i++) ...[
                if (i > 0) const SizedBox(height: 4),
                _RecipeTile(
                  name: info.recipes.keys.elementAt(i),
                  recipe: info.recipes.values.elementAt(i),
                ),
              ],
            ],
          );
        },
        error: (err, _) => _ErrorRow(error: err.toString()),
        loading: () => const _LoadingIndicator(),
      ),
    );
  }
}

class _RecipeTile extends StatelessWidget {
  final String name;
  final RecipeInfo recipe;

  const _RecipeTile({required this.name, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ExpansionTile(
      dense: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.only(left: 16, bottom: 8, right: 4),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: recipe.installedCount > 0
              ? Colors.green.withAlpha(30)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          recipe.installedCount > 0
              ? Icons.check_circle_outline
              : Icons.download_outlined,
          size: 18,
          color: recipe.installedCount > 0
              ? Colors.green
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        name,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${recipe.installedCount}/${recipe.totalCount} backends installed'
        '${recipe.defaultBackend.isNotEmpty ? '  •  default: ${recipe.defaultBackend}' : ''}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      children: [
        for (final entry in recipe.backends.entries)
          _BackendRow(name: entry.key, backend: entry.value),
      ],
    );
  }
}

class _BackendRow extends StatelessWidget {
  final String name;
  final BackendInfo backend;

  const _BackendRow({required this.name, required this.backend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (Color bgColor, Color fgColor, String label) = switch (backend.state) {
      'installed' => (
        Colors.green.withAlpha(30),
        Colors.green,
        'installed',
      ),
      'installable' => (
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
        'installable',
      ),
      'unsupported' => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        'unsupported',
      ),
      _ => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        backend.state,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fgColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (backend.version != null && backend.version!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              backend.version!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String error;
  const _ErrorRow({required this.error});

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

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

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
