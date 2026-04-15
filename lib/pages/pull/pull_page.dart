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
  final _recipeController = TextEditingController();
  final _mmprojController = TextEditingController();

  bool _reasoning = false;
  bool _vision = false;
  bool _embedding = false;
  bool _reranking = false;
  String? _selectedRecipe = 'llamacpp';

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
    _recipeController.dispose();
    _mmprojController.dispose();
    super.dispose();
  }

  /// Extracts the repo name from a checkpoint like "unsloth/gemma-4-E4B-it-GGUF:BF16"
  /// and autofills the model name field only if it's empty.
  void _onCheckpointChanged() {
    if (_modelNameController.text.trim().isNotEmpty) return;

    final text = _checkpointController.text.trim();
    if (text.isEmpty) return;

    final withoutVariant = text.split(':').first;
    final parts = withoutVariant.split('/');
    if (parts.length >= 2 && parts.last.isNotEmpty) {
      _modelNameController.text = parts.last;
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    var modelName = _modelNameController.text.trim();
    if (!modelName.startsWith('user.')) {
      modelName = 'user.$modelName';
    }

    final options = PullRequestOptions(
      modelName: modelName,
      checkpoint: _checkpointController.text.trim(),
      recipe: _selectedRecipe!,
      reasoning: _reasoning,
      vision: _vision,
      embedding: _embedding,
      reranking: _reranking,
      mmproj: _vision ? _mmprojController.text.trim() : null,
    );

    ref.read(pullProgressProvider.notifier).startPull(options);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Started pulling "$modelName"')),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  hintText: 'e.g. unsloth/Phi-4-mini-instruct-GGUF:Q4_K_M',
                  helperText: 'HuggingFace checkpoint (org/repo or org/repo:variant)',
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
                value: recipes.contains(_selectedRecipe)
                    ? _selectedRecipe
                    : null,
                decoration: InputDecoration(
                  labelText: 'Recipe',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: recipes
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedRecipe = value);
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Recipe is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Labels',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilterChip(
                    label: const Text('Reasoning'),
                    selected: _reasoning,
                    onSelected: (v) => setState(() => _reasoning = v),
                  ),
                  FilterChip(
                    label: const Text('Vision'),
                    selected: _vision,
                    onSelected: (v) => setState(() => _vision = v),
                  ),
                  FilterChip(
                    label: const Text('Embedding'),
                    selected: _embedding,
                    onSelected: (v) => setState(() => _embedding = v),
                  ),
                  FilterChip(
                    label: const Text('Reranking'),
                    selected: _reranking,
                    onSelected: (v) => setState(() => _reranking = v),
                  ),
                ],
              ),
              if (_vision) ...[
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
                Icon(Icons.downloading, size: 20, color: theme.colorScheme.primary),
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
              if (event.bytesDownloaded != null && event.bytesTotal != null) ...[
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
