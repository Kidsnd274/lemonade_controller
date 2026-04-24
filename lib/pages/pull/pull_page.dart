import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/pull_progress_event.dart';
import 'package:lemonade_controller/models/pull_request_options.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/utils/format.dart';

class PullPage extends ConsumerStatefulWidget {
  const PullPage({super.key});

  @override
  ConsumerState<PullPage> createState() => _PullPageState();
}

class _PullPageState extends ConsumerState<PullPage> {
  final _formKey = GlobalKey<FormState>();
  final _modelNameController = TextEditingController();
  final _checkpointController = TextEditingController();
  final _mmprojController = TextEditingController();

  bool? _reasoning;
  bool? _vision;
  bool? _embedding;
  bool? _reranking;
  String? _selectedRecipe = 'llamacpp';
  _ParsedPullCommand? _parsedCommand;
  bool _modelNameAutofilledFromCommand = false;
  final Set<String> _shownPullErrors = {};

  static const _commonRecipes = ['llamacpp', 'oga', 'hf'];

  @override
  void initState() {
    super.initState();
    _checkpointController.addListener(_onCheckpointChanged);
  }

  @override
  void dispose() {
    _checkpointController.removeListener(_onCheckpointChanged);
    _modelNameController.dispose();
    _checkpointController.dispose();
    _mmprojController.dispose();
    super.dispose();
  }

  void _listenForPullErrors() {
    ref.listen<Map<String, PullProgressEvent>>(pullProgressProvider, (
      previous,
      next,
    ) {
      for (final entry in next.entries) {
        final previousEvent = previous?[entry.key];
        final event = entry.value;
        if (!event.isError) {
          _shownPullErrors.removeWhere(
            (key) => key.startsWith('${entry.key}:'),
          );
          continue;
        }
        if (previousEvent?.isError == true) continue;

        final errorKey = '${entry.key}:${event.errorMessage ?? ''}';
        if (_shownPullErrors.contains(errorKey)) continue;
        _shownPullErrors.add(errorKey);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showPullErrorDialog(entry.key, event.errorMessage);
        });
      }
    });
  }

  Future<void> _showPullErrorDialog(
    String modelName,
    String? errorMessage,
  ) async {
    final theme = Theme.of(context);
    final message = errorMessage?.trim().isNotEmpty == true
        ? errorMessage!.trim()
        : 'The pull request failed. Please check the checkpoint and try again.';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
              size: 30,
            ),
          ),
          title: const Text('Pull Failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                modelName.replaceFirst('user.', ''),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.35),
                  ),
                ),
                child: SelectableText(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check),
              label: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  /// Detects pasted `lemonade pull` commands and extracts the checkpoint.
  /// Otherwise extracts the repo name from a checkpoint like
  /// "unsloth/gemma-4-E4B-it-GGUF:BF16" and autofills the model name field
  /// only if it's empty.
  void _onCheckpointChanged() {
    final text = _checkpointController.text.trim();
    final parsedCommand = _parsePullCommand(text);

    if (text.isEmpty && _parsedCommand != null) {
      if (_modelNameAutofilledFromCommand) {
        _modelNameController.clear();
      }
      setState(() {
        _parsedCommand = null;
        _modelNameAutofilledFromCommand = false;
      });
      return;
    }

    if (parsedCommand != _parsedCommand) {
      setState(() => _parsedCommand = parsedCommand);
    }

    if (text.isEmpty) return;

    if (parsedCommand != null) {
      if (_modelNameController.text.trim().isEmpty &&
          parsedCommand.modelName != null) {
        _modelNameController.text = parsedCommand.modelName!;
        _modelNameAutofilledFromCommand = true;
      }
      return;
    }

    if (_modelNameAutofilledFromCommand) {
      _modelNameAutofilledFromCommand = false;
    }

    if (_modelNameController.text.trim().isNotEmpty) return;

    final modelName = _modelNameFromCheckpoint(text);
    if (modelName != null) {
      _modelNameController.text = modelName;
    }
  }

  _ParsedPullCommand? _parsePullCommand(String input) {
    final match = RegExp(
      r'^\s*lemonade\s+pull\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(input);
    if (match == null) return null;

    final tokens = _splitCommandArgs(match.group(1)!.trim());
    if (tokens.isEmpty) return null;

    String? recipe;
    String? checkpoint;
    final firstArg = tokens.first;

    for (var i = 1; i < tokens.length; i++) {
      final token = tokens[i];
      if (token == '--recipe' && i + 1 < tokens.length) {
        recipe = tokens[++i];
      } else if (token == '--checkpoint' && i + 2 < tokens.length) {
        i++; // skip checkpoint name, e.g. "main"
        checkpoint = tokens[++i];
      }
    }

    checkpoint ??= firstArg;

    final modelName = checkpoint == firstArg
        ? _modelNameFromCheckpoint(checkpoint)
        : _stripUserPrefix(firstArg);

    return _ParsedPullCommand(
      checkpoint: checkpoint,
      modelName: modelName,
      recipe: recipe,
    );
  }

  List<String> _splitCommandArgs(String input) {
    return RegExp(r'"([^"]*)"|\S+')
        .allMatches(input)
        .map((match) => match.group(1) ?? match.group(0)!)
        .toList();
  }

  String? _modelNameFromCheckpoint(String checkpoint) {
    final withoutVariant = checkpoint.split(':').first;
    final parts = withoutVariant.split('/');
    if (parts.length >= 2 && parts.last.isNotEmpty) {
      return parts.last;
    }
    return null;
  }

  String _stripUserPrefix(String modelName) {
    return modelName.startsWith('user.')
        ? modelName.substring('user.'.length)
        : modelName;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    var modelName = _modelNameController.text.trim();
    if (!modelName.startsWith('user.')) {
      modelName = 'user.$modelName';
    }

    final command = _parsePullCommand(_checkpointController.text.trim());
    final isCommandMode = command != null;
    final recipe = command?.recipe ?? _selectedRecipe!;
    final mmproj = _vision == true ? _mmprojController.text.trim() : '';

    final options = PullRequestOptions(
      modelName: modelName,
      checkpoint: command?.checkpoint ?? _checkpointController.text.trim(),
      recipe: recipe,
      reasoning: isCommandMode ? null : _reasoning,
      vision: isCommandMode ? null : _vision,
      embedding: isCommandMode ? null : _embedding,
      reranking: isCommandMode ? null : _reranking,
      mmproj: isCommandMode || mmproj.isEmpty ? null : mmproj,
    );

    ref.read(pullProgressProvider.notifier).startPull(options);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Started pulling "$modelName"')));
  }

  @override
  Widget build(BuildContext context) {
    _listenForPullErrors();

    final theme = Theme.of(context);
    final pullProgress = ref.watch(pullProgressProvider);
    final systemInfoAsync = ref.watch(systemInfoProvider);

    final availableRecipes = systemInfoAsync.whenOrNull(
      data: (info) => info.recipes.keys.toList(),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildForm(theme, availableRecipes),
              if (pullProgress.isNotEmpty) ...[
                const SizedBox(height: 24),
                _ActiveDownloads(progress: pullProgress),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme, List<String>? availableRecipes) {
    final recipes = availableRecipes ?? _commonRecipes;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.download,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pull New Model',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Register and install a model from Hugging Face.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: 24),
              TextFormField(
                controller: _modelNameController,
                decoration: InputDecoration(
                  labelText: 'Model Name',
                  hintText: 'e.g. Phi-4-Mini-GGUF',
                  helperText: 'Will be prefixed with "user." automatically',
                  prefixText: 'user.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Model name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _checkpointController,
                decoration: InputDecoration(
                  labelText: 'Checkpoint',
                  hintText:
                      'e.g. unsloth/Phi-4-mini-instruct-GGUF:Q4_K_M or lemonade pull org/repo',
                  helperText:
                      'HuggingFace checkpoint or a lemonade pull command',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Checkpoint is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: recipes.contains(_selectedRecipe)
                    ? _selectedRecipe
                    : null,
                decoration: InputDecoration(
                  labelText: 'Recipe',
                  helperText: _parsedCommand?.recipe != null
                      ? 'Using recipe from command: ${_parsedCommand!.recipe}'
                      : 'Required by Lemonade Server',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: recipes
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedRecipe = value),
                validator: (value) {
                  if ((value == null || value.trim().isEmpty) &&
                      _parsedCommand?.recipe == null) {
                    return 'Recipe is required';
                  }
                  return null;
                },
              ),
              if (_parsedCommand != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.terminal,
                        size: 18,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lemonade command detected. Advanced Options are disabled while this command is active.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildAdvancedSettings(theme, recipes),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.download),
                  label: const Text('Pull Model'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings(ThemeData theme, List<String> recipes) {
    final commandMode = _parsedCommand != null;

    return IgnorePointer(
      ignoring: commandMode,
      child: Opacity(
        opacity: commandMode ? 0.55 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: Icon(
              Icons.tune,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              'Advanced Options',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: commandMode
                ? const Text('Disabled while a lemonade command is detected')
                : const Text(
                    'Optional label overrides; Auto lets the server infer',
                  ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.label_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Labels',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  _buildLabelOptionRow(
                    theme: theme,
                    label: 'Reasoning',
                    description: 'Model performs chain-of-thought style tasks',
                    value: _reasoning,
                    onChanged: (value) => setState(() => _reasoning = value),
                  ),
                  const SizedBox(height: 10),
                  _buildLabelOptionRow(
                    theme: theme,
                    label: 'Vision',
                    description: 'Model accepts image or multimodal inputs',
                    value: _vision,
                    onChanged: (value) => setState(() => _vision = value),
                  ),
                  const SizedBox(height: 10),
                  _buildLabelOptionRow(
                    theme: theme,
                    label: 'Embedding',
                    description: 'Model generates vector embeddings',
                    value: _embedding,
                    onChanged: (value) => setState(() => _embedding = value),
                  ),
                  const SizedBox(height: 10),
                  _buildLabelOptionRow(
                    theme: theme,
                    label: 'Reranking',
                    description: 'Model reranks search or retrieval results',
                    value: _reranking,
                    onChanged: (value) => setState(() => _reranking = value),
                  ),
                ],
              ),
              if (_vision == true) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mmprojController,
                  decoration: InputDecoration(
                    labelText: 'mmproj (optional)',
                    hintText: 'Multimodal projector file for vision models',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabelOptionRow({
    required ThemeData theme,
    required String label,
    required String description,
    required bool? value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SegmentedButton<bool?>(
            segments: const [
              ButtonSegment(value: null, label: Text('Auto')),
              ButtonSegment(value: true, label: Text('Yes')),
              ButtonSegment(value: false, label: Text('No')),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

class _ParsedPullCommand {
  final String checkpoint;
  final String? modelName;
  final String? recipe;

  const _ParsedPullCommand({
    required this.checkpoint,
    required this.modelName,
    required this.recipe,
  });

  @override
  bool operator ==(Object other) {
    return other is _ParsedPullCommand &&
        other.checkpoint == checkpoint &&
        other.modelName == modelName &&
        other.recipe == recipe;
  }

  @override
  int get hashCode => Object.hash(checkpoint, modelName, recipe);
}

class _ActiveDownloads extends StatelessWidget {
  final Map<String, PullProgressEvent> progress;

  const _ActiveDownloads({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.downloading,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Active Downloads',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            for (final entry in progress.entries) ...[
              _DownloadRow(modelName: entry.key, event: entry.value),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  final String modelName;
  final PullProgressEvent event;

  const _DownloadRow({required this.modelName, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = event.percent ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                modelName.replaceFirst('user.', ''),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (event.isComplete)
              Icon(Icons.check_circle, size: 18, color: Colors.green)
            else if (event.isError)
              Icon(Icons.error, size: 18, color: theme.colorScheme.error)
            else
              Text(
                '$percent%',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (event.isError)
          Text(
            event.errorMessage ?? 'Download failed',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else if (event.isComplete)
          Text(
            'Download complete',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
          )
        else ...[
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
