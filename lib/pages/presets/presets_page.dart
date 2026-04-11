import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/model_load_preset.dart';
import 'package:lemonade_controller/pages/presets/preset_editor_page.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/services/settings_service.dart';
import 'package:lemonade_controller/utils/vram_estimator.dart';

class PresetsPage extends ConsumerWidget {
  const PresetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (settings) => _PresetsContent(presets: settings.modelLoadPresets),
    );
  }
}

class _PresetsContent extends ConsumerWidget {
  final List<ModelLoadPreset> presets;
  const _PresetsContent({required this.presets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (presets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.playlist_add,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No presets yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a preset to load multiple models at once.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('Create Preset'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                '${presets.length} preset${presets.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Preset'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: presets.length,
            itemBuilder: (context, index) =>
                _PresetCard(preset: presets[index]),
          ),
        ),
      ],
    );
  }

  void _openEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PresetEditorPage()),
    );
  }
}

class _PresetCard extends ConsumerWidget {
  final ModelLoadPreset preset;
  const _PresetCard({required this.preset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(isPresetLoadingProvider(preset.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    preset.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${preset.entries.length} model${preset.entries.length == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (preset.entries.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: preset.entries.map((entry) {
                  return Chip(
                    label: Text(
                      entry.modelName,
                      style: theme.textTheme.labelSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ],
            _PresetVramSummary(preset: preset),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _deletePreset(context, ref),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  label: Text(
                    'Delete',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _editPreset(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => _loadPreset(context, ref),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Load'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadPreset(BuildContext context, WidgetRef ref) async {
    final successes = await ref
        .read(presetLoadingProvider.notifier)
        .loadPreset(preset);

    if (!context.mounted) return;

    final total = preset.entries.length;
    final messenger = ScaffoldMessenger.of(context);
    if (successes == total) {
      messenger.showSnackBar(SnackBar(
        content: Text('Loaded all $total models from "${preset.name}".'),
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(
          'Loaded $successes of $total models from "${preset.name}".',
        ),
      ));
    }
  }

  void _editPreset(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PresetEditorPage(existingPreset: preset),
      ),
    );
  }

  Future<void> _deletePreset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text('Delete "${preset.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(settingsProvider.notifier).removePreset(preset.id);
    }
  }
}

class _PresetVramSummary extends ConsumerWidget {
  final ModelLoadPreset preset;
  const _PresetVramSummary({required this.preset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (preset.entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final allModels = ref.watch(modelsProvider).value;
    double totalGb = 0;
    int estimated = 0;

    for (final entry in preset.entries) {
      VramEstimate? vram;

      if (allModels != null) {
        final model = allModels.where((m) => m.id == entry.modelName).firstOrNull;
        if (model != null) {
          vram = estimateVramForModel(model, ctxSize: entry.ctxSize);
        }
      }

      vram ??= estimateVramFromModelName(
        entry.modelName,
        ctxSize: entry.ctxSize,
      );

      if (vram != null) {
        totalGb += vram.totalGb;
        estimated++;
      }
    }

    if (estimated == 0) return const SizedBox.shrink();

    final allEstimated = estimated == preset.entries.length;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(
            Icons.memory,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '~${totalGb.toStringAsFixed(1)} GB VRAM',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          if (!allEstimated) ...[
            const SizedBox(width: 4),
            Text(
              '($estimated of ${preset.entries.length} models)',
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
