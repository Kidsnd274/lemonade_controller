import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/home/widgets/dashboard_card.dart';
import 'package:lemonade_controller/providers/api_providers.dart';

class LoadedModelsCard extends ConsumerWidget {
  const LoadedModelsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(healthInfoProvider);
    final theme = Theme.of(context);

    return DashboardCard(
      title: 'Loaded Models',
      icon: Icons.model_training,
      child: healthAsync.when(
        data: (health) {
          if (health.allModelsLoaded.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No models currently loaded',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              for (int i = 0; i < health.allModelsLoaded.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _LoadedModelTile(
                  modelName: health.allModelsLoaded[i].modelName,
                  checkpoint: health.allModelsLoaded[i].checkpoint,
                  device: health.allModelsLoaded[i].device,
                  recipe: health.allModelsLoaded[i].recipe,
                  type: health.allModelsLoaded[i].type,
                  recipeOptions: health.allModelsLoaded[i].recipeOptions,
                  isActive:
                      health.allModelsLoaded[i].modelName == health.activeModel,
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

class _LoadedModelTile extends StatelessWidget {
  final String modelName;
  final String checkpoint;
  final String device;
  final String recipe;
  final String type;
  final Map<String, dynamic> recipeOptions;
  final bool isActive;

  const _LoadedModelTile({
    required this.modelName,
    required this.checkpoint,
    required this.device,
    required this.recipe,
    required this.type,
    required this.recipeOptions,
    this.isActive = false,
  });

  String get _displayName => modelName.replaceFirst('user.', '');

  String get _contextSize {
    final ctx = recipeOptions['ctx_size'];
    if (ctx == null) return '';
    final k = (ctx as num).toInt();
    if (k >= 1024) return '${(k / 1024).round()}K ctx';
    return '$k ctx';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isActive)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
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
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _MiniChip(label: recipe, color: theme.colorScheme.primaryContainer),
              _MiniChip(label: device, color: theme.colorScheme.secondaryContainer),
              _MiniChip(label: type, color: theme.colorScheme.tertiaryContainer),
              if (_contextSize.isNotEmpty)
                _MiniChip(
                  label: _contextSize,
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            checkpoint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
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
