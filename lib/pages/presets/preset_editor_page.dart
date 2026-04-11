import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/lemonade_load_options.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/models/model_load_preset.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/services/settings_service.dart';
import 'package:lemonade_controller/utils/quantization_color.dart';
import 'package:lemonade_controller/utils/vram_estimator.dart';

const _llamacppBackends = ['vulkan', 'rocm', 'metal', 'cpu'];

class PresetEditorPage extends ConsumerStatefulWidget {
  final ModelLoadPreset? existingPreset;
  const PresetEditorPage({super.key, this.existingPreset});

  @override
  ConsumerState<PresetEditorPage> createState() => _PresetEditorPageState();
}

class _PresetEditorPageState extends ConsumerState<PresetEditorPage> {
  late final TextEditingController _nameController;
  late List<LemonadeLoadOptionsModel> _entries;
  bool get _isEditing => widget.existingPreset != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingPreset?.name ?? '',
    );
    _entries = List.of(widget.existingPreset?.entries ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a preset name.')),
      );
      return;
    }
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one model to the preset.')),
      );
      return;
    }

    final notifier = ref.read(settingsProvider.notifier);
    if (_isEditing) {
      await notifier.updatePreset(
        widget.existingPreset!.copyWith(name: name, entries: _entries),
      );
    } else {
      await notifier.addPreset(ModelLoadPreset(
        id: ModelLoadPreset.generateId(),
        name: name,
        entries: _entries,
      ));
    }

    if (mounted) Navigator.of(context).pop();
  }

  void _addModels() async {
    final modelsAsync = ref.read(modelsProvider);
    final allModels = modelsAsync.value;
    if (allModels == null || allModels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model catalog not available.')),
      );
      return;
    }

    final existingIds = _entries.map((e) => e.modelName).toSet();
    final picked = await showDialog<List<LemonadeModel>>(
      context: context,
      builder: (_) => _ModelPickerDialog(
        models: allModels,
        alreadySelectedIds: existingIds,
      ),
    );

    if (picked != null && picked.isNotEmpty) {
      setState(() {
        for (final model in picked) {
          if (!existingIds.contains(model.id)) {
            _entries.add(LemonadeLoadOptionsModel(modelName: model.id));
          }
        }
      });
    }
  }

  void _configureEntry(int index) async {
    final entry = _entries[index];
    final updated = await showDialog<LemonadeLoadOptionsModel>(
      context: context,
      builder: (_) => _EntryConfigDialog(entry: entry),
    );
    if (updated != null) {
      setState(() => _entries[index] = updated);
    }
  }

  void _removeEntry(int index) {
    setState(() => _entries.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Preset' : 'New Preset'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Preset Name',
              hintText: 'e.g. My LLM Stack',
              border: OutlineInputBorder(),
            ),
            autofocus: !_isEditing,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Models (${_entries.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _addModels,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Models'),
              ),
            ],
          ),
          if (_entries.isNotEmpty) ...[
            const SizedBox(height: 12),
            _EditorVramSummary(entries: _entries),
          ],
          const SizedBox(height: 12),
          if (_entries.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No models added yet. Tap "Add Models" to pick from the catalog.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _entries.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _entries.removeAt(oldIndex);
                  _entries.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return _EntryTile(
                  key: ValueKey(entry.modelName),
                  reorderIndex: index,
                  entry: entry,
                  onConfigure: () => _configureEntry(index),
                  onRemove: () => _removeEntry(index),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final int reorderIndex;
  final LemonadeLoadOptionsModel entry;
  final VoidCallback onConfigure;
  final VoidCallback onRemove;

  const _EntryTile({
    super.key,
    required this.reorderIndex,
    required this.entry,
    required this.onConfigure,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = <String>[];
    if (entry.ctxSize != null) extras.add('ctx: ${entry.ctxSize}');
    if (entry.llamacppBackend != null) extras.add(entry.llamacppBackend!);
    if (entry.llamacppArgs != null) extras.add('args: ${entry.llamacppArgs}');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.modelName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (extras.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        extras.join(' | '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.tune, size: 20),
              tooltip: 'Configure',
              onPressed: onConfigure,
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                size: 20,
                color: theme.colorScheme.error,
              ),
              tooltip: 'Remove',
              onPressed: onRemove,
            ),
            ReorderableDragStartListener(
              index: reorderIndex,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.drag_handle, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model picker dialog
// ---------------------------------------------------------------------------

enum _UserFilter { all, userOnly, nonUserOnly }

class _ModelPickerDialog extends StatefulWidget {
  final List<LemonadeModel> models;
  final Set<String> alreadySelectedIds;

  const _ModelPickerDialog({
    required this.models,
    required this.alreadySelectedIds,
  });

  @override
  State<_ModelPickerDialog> createState() => _ModelPickerDialogState();
}

class _ModelPickerDialogState extends State<_ModelPickerDialog> {
  late final TextEditingController _searchController;
  String _query = '';
  _UserFilter _userFilter = _UserFilter.all;
  String? _selectedQuantization;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static final _qLevelPattern = RegExp(r'Q(\d)');

  static int? _parseQLevel(String quantization) {
    final match = _qLevelPattern.firstMatch(quantization);
    if (match == null) return null;
    return int.parse(match.group(1)!);
  }

  List<String> get _quantizations {
    final quants = widget.models
        .where((m) => m.isUserModel)
        .map((m) => m.quantization)
        .where((q) => q != 'Unknown')
        .toSet()
        .toList();
    quants.sort();
    return quants;
  }

  List<LemonadeModel> get _filteredModels {
    var models = widget.models;

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      models = models
          .where((m) =>
              m.id.toLowerCase().contains(q) ||
              m.checkpoint.toLowerCase().contains(q) ||
              m.recipe.toLowerCase().contains(q) ||
              m.labels.any((l) => l.toLowerCase().contains(q)))
          .toList();
    }

    switch (_userFilter) {
      case _UserFilter.userOnly:
        models = models.where((m) => m.isUserModel).toList();
        break;
      case _UserFilter.nonUserOnly:
        models = models.where((m) => !m.isUserModel).toList();
        break;
      case _UserFilter.all:
        break;
    }

    if (_selectedQuantization != null) {
      models = models
          .where((m) => m.quantization == _selectedQuantization)
          .toList();
    }

    models.sort((a, b) {
      if (a.isUserModel == b.isUserModel) return a.id.compareTo(b.id);
      return a.isUserModel ? -1 : 1;
    });
    return models;
  }

  bool get _hasActiveFilters =>
      _query.isNotEmpty ||
      _userFilter != _UserFilter.all ||
      _selectedQuantization != null;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _query = '';
      _userFilter = _UserFilter.all;
      _selectedQuantization = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredModels;
    final quantizations = _quantizations;
    final theme = Theme.of(context);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 620),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Add Models'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search models...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _userFilter == _UserFilter.all,
                      onSelected: (_) =>
                          setState(() => _userFilter = _UserFilter.all),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      avatar: _userFilter == _UserFilter.userOnly
                          ? null
                          : Icon(
                              Icons.person_outline,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                      label: const Text('user.'),
                      selected: _userFilter == _UserFilter.userOnly,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (_) =>
                          setState(() => _userFilter = _UserFilter.userOnly),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('Non-user'),
                      selected: _userFilter == _UserFilter.nonUserOnly,
                      onSelected: (_) =>
                          setState(() => _userFilter = _UserFilter.nonUserOnly),
                    ),
                    if (quantizations.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(height: 24, width: 1, color: theme.dividerColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedQuantization,
                            hint: const Text('Quant'),
                            isDense: true,
                            isExpanded: true,
                            borderRadius: BorderRadius.circular(12),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All quants'),
                              ),
                              ...quantizations.map((q) {
                                final level = _parseQLevel(q);
                                return DropdownMenuItem<String?>(
                                  value: q,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: quantizationColor(level),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(q),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedQuantization = value),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} of ${widget.models.length} models',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_selectedIds.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${_selectedIds.length} selected)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (_hasActiveFilters)
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Clear filters'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No models match your filters',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final model = filtered[i];
                          final alreadyAdded =
                              widget.alreadySelectedIds.contains(model.id);
                          final selected = _selectedIds.contains(model.id);

                          return _PickerModelTile(
                            model: model,
                            isChecked: alreadyAdded || selected,
                            isDisabled: alreadyAdded,
                            onChanged: alreadyAdded
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedIds.add(model.id);
                                      } else {
                                        _selectedIds.remove(model.id);
                                      }
                                    });
                                  },
                          );
                        },
                      ),
              ),
            ],
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () {
                          final picked = widget.models
                              .where((m) => _selectedIds.contains(m.id))
                              .toList();
                          Navigator.pop(context, picked);
                        },
                  child: Text(
                    'Add ${_selectedIds.length} model${_selectedIds.length == 1 ? '' : 's'}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerModelTile extends StatelessWidget {
  final LemonadeModel model;
  final bool isChecked;
  final bool isDisabled;
  final ValueChanged<bool?>? onChanged;

  const _PickerModelTile({
    required this.model,
    required this.isChecked,
    required this.isDisabled,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CheckboxListTile(
      value: isChecked,
      onChanged: isDisabled ? null : onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      title: Row(
        children: [
          if (model.isUserModel) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'user.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              model.displayName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (model.isUserModel && model.quantization != 'Unknown') ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: quantizationColor(model.quantizationLevel),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                model.quantization,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: quantizationForegroundColor(model.quantizationLevel),
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: model.recipe,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: '  \u2022  ${model.checkpoint}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      secondary: isDisabled
          ? Tooltip(
              message: 'Already in preset',
              child: Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// VRAM summary for the editor
// ---------------------------------------------------------------------------

class _EditorVramSummary extends ConsumerWidget {
  final List<LemonadeLoadOptionsModel> entries;
  const _EditorVramSummary({required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allModels = ref.watch(modelsProvider).value;

    double totalGb = 0;
    int estimated = 0;
    final perModel = <String, double>{};

    for (final entry in entries) {
      VramEstimate? vram;

      if (allModels != null) {
        final model =
            allModels.where((m) => m.id == entry.modelName).firstOrNull;
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
        perModel[entry.modelName] = vram.totalGb;
      }
    }

    if (estimated == 0) return const SizedBox.shrink();

    final allEstimated = estimated == entries.length;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withAlpha(40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.primary.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Estimated Total VRAM',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '~${totalGb.toStringAsFixed(1)} GB',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (!allEstimated)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$estimated of ${entries.length} models estimated',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (perModel.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...perModel.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '~${e.value.toStringAsFixed(1)} GB',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-entry config dialog (no save_options -- presets manage their own config)
// ---------------------------------------------------------------------------

class _EntryConfigDialog extends StatefulWidget {
  final LemonadeLoadOptionsModel entry;
  const _EntryConfigDialog({required this.entry});

  @override
  State<_EntryConfigDialog> createState() => _EntryConfigDialogState();
}

class _EntryConfigDialogState extends State<_EntryConfigDialog> {
  late final TextEditingController _ctxSizeController;
  late final TextEditingController _llamacppArgsController;
  String? _llamacppBackend;

  @override
  void initState() {
    super.initState();
    _ctxSizeController = TextEditingController(
      text: widget.entry.ctxSize?.toString() ?? '',
    );
    _llamacppArgsController = TextEditingController(
      text: widget.entry.llamacppArgs ?? '',
    );
    final stored = widget.entry.llamacppBackend;
    _llamacppBackend =
        (stored != null && _llamacppBackends.contains(stored)) ? stored : null;
  }

  @override
  void dispose() {
    _ctxSizeController.dispose();
    _llamacppArgsController.dispose();
    super.dispose();
  }

  LemonadeLoadOptionsModel _buildOptions() {
    final ctxText = _ctxSizeController.text.trim();
    final argsText = _llamacppArgsController.text.trim();

    return LemonadeLoadOptionsModel(
      modelName: widget.entry.modelName,
      ctxSize: ctxText.isNotEmpty ? int.tryParse(ctxText) : null,
      llamacppBackend: _llamacppBackend,
      llamacppArgs: argsText.isNotEmpty ? argsText : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Configure ${widget.entry.modelName}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _ctxSizeController,
                decoration: const InputDecoration(
                  labelText: 'Context Size',
                  hintText: 'e.g. 16384',
                  helperText: 'Leave empty for default',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _llamacppBackend,
                decoration: const InputDecoration(
                  labelText: 'LlamaCpp Backend',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None (default)'),
                  ),
                  for (final backend in _llamacppBackends)
                    DropdownMenuItem(value: backend, child: Text(backend)),
                ],
                onChanged: (value) => setState(() => _llamacppBackend = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _llamacppArgsController,
                decoration: const InputDecoration(
                  labelText: 'LlamaCpp Args',
                  hintText: 'e.g. -np 2 -kvu',
                  helperText: 'Leave empty for none',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_buildOptions()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
