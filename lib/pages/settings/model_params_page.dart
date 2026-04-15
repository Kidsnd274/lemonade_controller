import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/pages/settings/model_params_json_editor_page.dart';
import 'package:lemonade_controller/services/settings_service.dart';

class ModelParamsPage extends ConsumerStatefulWidget {
  const ModelParamsPage({super.key});

  @override
  ConsumerState<ModelParamsPage> createState() => _ModelParamsPageState();
}

class _ModelParamsPageState extends ConsumerState<ModelParamsPage> {
  late Map<String, double> _overrides;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _overrides = Map.of(
      ref.read(settingsProvider).requireValue.modelParamOverrides,
    );
  }

  Future<void> _save() async {
    await ref
        .read(settingsProvider.notifier)
        .modify((s) => s.copyWith(modelParamOverrides: Map.of(_overrides)));
    setState(() => _dirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model parameter overrides saved')),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'This will discard all custom overrides and restore the '
          'bundled defaults. This cannot be undone.',
        ),
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
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final defaults =
        await SettingsNotifier.loadDefaultModelParamOverrides();
    setState(() {
      _overrides = defaults;
      _dirty = true;
    });
  }

  void _addEntry() async {
    final result = await _showEntryDialog(context);
    if (result == null) return;
    if (_overrides.containsKey(result.key)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${result.key}" already exists. Edit it instead.')),
      );
      return;
    }
    setState(() {
      _overrides[result.key] = result.value;
      _dirty = true;
    });
  }

  void _editEntry(String key) async {
    final result = await _showEntryDialog(
      context,
      initialKey: key,
      initialValue: _overrides[key]!,
    );
    if (result == null) return;
    setState(() {
      if (result.key != key) _overrides.remove(key);
      _overrides[result.key] = result.value;
      _dirty = true;
    });
  }

  void _removeEntry(String key) {
    setState(() {
      _overrides.remove(key);
      _dirty = true;
    });
  }

  void _openJsonEditor() async {
    final result = await Navigator.of(context).push<Map<String, double>>(
      MaterialPageRoute(
        builder: (_) => ModelParamsJsonEditorPage(overrides: _overrides),
      ),
    );
    if (result != null) {
      setState(() {
        _overrides = result;
        _dirty = true;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_dirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sortedKeys = _overrides.keys.toList()..sort();

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _onWillPop()) {
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Model Parameter Overrides'),
          actions: [
            IconButton(
              onPressed: _openJsonEditor,
              icon: const Icon(Icons.data_object),
              tooltip: 'Edit as JSON',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _dirty ? _save : null,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withAlpha(80),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Map model name substrings to parameter counts '
                          '(in billions). These are used for VRAM estimation '
                          'when the parameter count cannot be parsed from the '
                          'model name.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${sortedKeys.length} override${sortedKeys.length == 1 ? '' : 's'}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _resetToDefaults,
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Reset to Defaults'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.tonalIcon(
                    onPressed: _addEntry,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: sortedKeys.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.playlist_add,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No overrides defined',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "Add" to create one, or "Reset to Defaults" '
                            'to restore the bundled entries.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sortedKeys.length,
                      itemBuilder: (context, index) {
                        final key = sortedKeys[index];
                        final value = _overrides[key]!;
                        return _OverrideTile(
                          modelKey: key,
                          paramsBillions: value,
                          onEdit: () => _editEntry(key),
                          onDelete: () => _removeEntry(key),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<_EntryDialogResult?> _showEntryDialog(
    BuildContext context, {
    String? initialKey,
    double? initialValue,
  }) async {
    final keyController = TextEditingController(text: initialKey ?? '');
    final valueController = TextEditingController(
      text: initialValue != null ? _formatParamValue(initialValue) : '',
    );
    final isEditing = initialKey != null;

    return showDialog<_EntryDialogResult>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Override' : 'Add Override'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Model Name Pattern',
                    hintText: 'e.g. GLM-4.5-Air',
                    helperText: 'Matched case-insensitively against model IDs',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: !isEditing,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueController,
                  decoration: const InputDecoration(
                    labelText: 'Parameters (Billions)',
                    hintText: 'e.g. 110.0',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: isEditing,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final key = keyController.text.trim();
                final value = double.tryParse(valueController.text.trim());
                if (key.isEmpty || value == null || value <= 0) return;
                Navigator.pop(
                  context,
                  _EntryDialogResult(key: key, value: value),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  static String _formatParamValue(double value) {
    return value == value.truncateToDouble()
        ? value.toStringAsFixed(1)
        : value.toString();
  }
}

class _OverrideTile extends StatelessWidget {
  final String modelKey;
  final double paramsBillions;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OverrideTile({
    required this.modelKey,
    required this.paramsBillions,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    modelKey,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatDisplay(paramsBillions)}B parameters',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: colorScheme.error,
              ),
              tooltip: 'Remove',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDisplay(double value) {
    return value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }
}

class _EntryDialogResult {
  final String key;
  final double value;
  const _EntryDialogResult({required this.key, required this.value});
}
