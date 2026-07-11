import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lemonade_controller/models/download_job.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';
import 'package:lemonade_controller/models/pull_request_options.dart';
import 'package:lemonade_controller/models/pull_variants.dart';
import 'package:lemonade_controller/pages/widgets/action_feedback.dart';
import 'package:lemonade_controller/providers/api_providers.dart';
import 'package:lemonade_controller/providers/service_providers.dart';
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

  PullVariants? _variants;
  String? _selectedVariantName;
  bool _loadingVariants = false;
  Timer? _variantsDebounce;
  int _variantsRequestId = 0;
  String? _variantsError;
  final _otherVariantController = TextEditingController();
  bool _submitting = false;
  String? _currentDownloadId;

  bool _userEditedRecipe = false;
  final Set<String> _userTouchedLabels = {};

  @override
  void initState() {
    super.initState();
    _checkpointController.addListener(_onCheckpointChanged);
  }

  @override
  void dispose() {
    _variantsDebounce?.cancel();
    _checkpointController.removeListener(_onCheckpointChanged);
    _modelNameController.dispose();
    _checkpointController.dispose();
    _recipeController.dispose();
    _mmprojController.dispose();
    _otherVariantController.dispose();
    super.dispose();
  }

  /// Matches `lemonade pull `, `lemonade-server pull `, etc. so a copy-pasted
  /// CLI command collapses down to the bare checkpoint.
  static final _cliPrefixPattern = RegExp(
    r'^lemonade(?:-[a-z]+)*\s+pull\s+',
    caseSensitive: false,
  );

  /// Extracts the repo name from a checkpoint like "unsloth/gemma-4-E4B-it-GGUF:BF16"
  /// and autofills the model name field only if it's empty. When the checkpoint
  /// is a bare `org/repo`, also schedules a variants lookup after a short debounce.
  void _onCheckpointChanged() {
    final raw = _checkpointController.text;

    // Strip a pasted `lemonade pull <checkpoint>` command. Rewriting the field
    // re-fires this listener with the cleaned text, which then proceeds through
    // the normal flow.
    final match = _cliPrefixPattern.firstMatch(raw.trimLeft());
    if (match != null) {
      final cleaned = raw.trimLeft().substring(match.end).trim();
      _checkpointController.removeListener(_onCheckpointChanged);
      _checkpointController.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
      _checkpointController.addListener(_onCheckpointChanged);
      _onCheckpointChanged();
      return;
    }

    final text = raw.trim();

    if (_modelNameController.text.trim().isEmpty && text.isNotEmpty) {
      final withoutVariant = text.split(':').first;
      final parts = withoutVariant.split('/');
      if (parts.length >= 2 && parts.last.isNotEmpty) {
        _modelNameController.text = parts.last;
      }
    }

    _variantsDebounce?.cancel();

    if (text.contains(':')) {
      if (_variants != null ||
          _selectedVariantName != null ||
          _loadingVariants) {
        setState(() {
          _variants = null;
          _selectedVariantName = null;
          _loadingVariants = false;
        });
      }
      return;
    }

    final parts = text.split('/');
    if (parts.length < 2 || parts.last.isEmpty || parts.first.isEmpty) {
      if (_variants != null || _loadingVariants) {
        setState(() {
          _variants = null;
          _selectedVariantName = null;
          _loadingVariants = false;
        });
      }
      return;
    }

    if (_variants?.checkpoint == text) return;

    _variantsDebounce = Timer(const Duration(milliseconds: 500), () {
      _fetchVariants(text);
    });
  }

  Future<void> _fetchVariants(String orgRepo) async {
    if (!mounted) return;
    final requestId = ++_variantsRequestId;
    setState(() => _loadingVariants = true);

    final apiClient = ref.read(apiClientProvider);
    PullVariants? result;
    String? error;
    try {
      result = await apiClient.getPullVariants(orgRepo);
    } catch (exception) {
      error = exception.toString();
    }

    if (!mounted || requestId != _variantsRequestId) return;

    final currentText = _checkpointController.text.trim().split(':').first;
    if (currentText != orgRepo) {
      setState(() => _loadingVariants = false);
      return;
    }

    setState(() {
      _loadingVariants = false;
      _variants = result;
      _selectedVariantName = null;
      _variantsError = error;
    });

    if (result != null && result.variants.isNotEmpty) {
      _applySuggestions(result);
      _selectVariant(result.variants.first.name);
    }
  }

  void _applySuggestions(PullVariants v) {
    setState(() {
      if (_modelNameController.text.trim().isEmpty &&
          v.suggestedName.isNotEmpty) {
        _modelNameController.text = v.suggestedName;
      }

      for (final label in v.suggestedLabels) {
        if (_userTouchedLabels.contains(label)) continue;
        switch (label) {
          case 'vision':
            if (!_vision) _vision = true;
            break;
          case 'embeddings':
          case 'embedding':
            if (!_embedding) _embedding = true;
            break;
          case 'reranking':
            if (!_reranking) _reranking = true;
            break;
        }
      }

      if (!_userEditedRecipe && v.recipe.isNotEmpty) {
        _selectedRecipe = v.recipe;
      }

      if (_vision &&
          _mmprojController.text.trim().isEmpty &&
          v.mmprojFiles.isNotEmpty) {
        _mmprojController.text = v.mmprojFiles.first;
      }
    });
  }

  void _selectVariant(String variantName) {
    final v = _variants;
    if (v == null) return;
    setState(() => _selectedVariantName = variantName);

    final newText = '${v.checkpoint}:$variantName';
    if (_checkpointController.text == newText) return;

    _checkpointController.removeListener(_onCheckpointChanged);
    _checkpointController.text = newText;
    _checkpointController.selection = TextSelection.collapsed(
      offset: newText.length,
    );
    _checkpointController.addListener(_onCheckpointChanged);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final enteredName = _modelNameController.text.trim();
    final modelName = enteredName.startsWith('user.')
        ? enteredName
        : 'user.$enteredName';

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

    setState(() => _submitting = true);
    try {
      final job = await ref.read(downloadsProvider.notifier).startPull(options);
      if (!mounted) return;
      setState(() => _currentDownloadId = job.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Started downloading "$modelName"')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final systemInfoAsync = ref.watch(systemInfoProvider);
    final downloadsState = ref.watch(downloadsProvider);
    final currentDownload = _resolveCurrentDownload(downloadsState);

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
              if (currentDownload != null) ...[
                const SizedBox(height: 24),
                _ActiveDownload(
                  job: currentDownload,
                  pollingError: downloadsState.error,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  DownloadJob? _resolveCurrentDownload(DownloadsState state) {
    final currentId = _currentDownloadId;
    if (currentId != null) {
      for (final job in state.jobs) {
        if (job.id == currentId) return job;
      }
    }
    for (final job in state.jobs) {
      if (job.running) return job;
    }
    return null;
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
                  helperText: _modelNameController.text.trim().isEmpty
                      ? 'Custom models are registered under the user. namespace.'
                      : 'Will register as ${_modelNameController.text.trim().startsWith('user.') ? _modelNameController.text.trim() : 'user.${_modelNameController.text.trim()}'}',
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
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _checkpointController,
                decoration: InputDecoration(
                  labelText: 'Checkpoint',
                  hintText: 'e.g. unsloth/Phi-4-mini-instruct-GGUF:Q4_K_M',
                  helperText:
                      'HuggingFace checkpoint (org/repo or org/repo:variant)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: _loadingVariants
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Checkpoint is required';
                  }
                  return null;
                },
              ),
              if (_variants != null) ...[
                const SizedBox(height: 12),
                _buildVariantsSection(theme),
              ],
              if (_variantsError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _variantsError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: recipes.contains(_selectedRecipe)
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
                  setState(() {
                    _selectedRecipe = value;
                    _userEditedRecipe = true;
                  });
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
                    onSelected: (v) => setState(() {
                      _reasoning = v;
                      _userTouchedLabels.add('reasoning');
                    }),
                  ),
                  FilterChip(
                    label: const Text('Vision'),
                    selected: _vision,
                    onSelected: (v) => setState(() {
                      _vision = v;
                      _userTouchedLabels.add('vision');
                    }),
                  ),
                  FilterChip(
                    label: const Text('Embedding'),
                    selected: _embedding,
                    onSelected: (v) => setState(() {
                      _embedding = v;
                      _userTouchedLabels.add('embeddings');
                      _userTouchedLabels.add('embedding');
                    }),
                  ),
                  FilterChip(
                    label: const Text('Reranking'),
                    selected: _reranking,
                    onSelected: (v) => setState(() {
                      _reranking = v;
                      _userTouchedLabels.add('reranking');
                    }),
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
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: const Text('Pull Model'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariantsSection(ThemeData theme) {
    final v = _variants;
    if (v == null) return const SizedBox.shrink();

    if (v.variants.isEmpty) {
      return Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'No GGUF variants found for this repo.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    final groups = <int?, List<PullVariant>>{};
    for (final variant in v.variants) {
      groups.putIfAbsent(variant.quantBits, () => []).add(variant);
    }
    final orderedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null && b == null) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'Variants',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'grouped by precision',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        for (var i = 0; i < orderedKeys.length; i++) ...[
          SizedBox(height: i == 0 ? 10 : 14),
          _buildVariantGroupHeader(orderedKeys[i], theme),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final variant in groups[orderedKeys[i]]!)
                _buildVariantTile(variant, theme),
            ],
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _otherVariantController,
          decoration: InputDecoration(
            labelText: 'Other quantization',
            hintText: 'e.g. IQ3_M',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'Use quantization',
              onPressed: () {
                final value = _otherVariantController.text.trim();
                if (value.isNotEmpty) _selectVariant(value);
              },
              icon: const Icon(Icons.check),
            ),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) _selectVariant(value.trim());
          },
        ),
      ],
    );
  }

  Widget _buildVariantGroupHeader(int? bits, ThemeData theme) {
    final label = bits == null ? 'OTHER' : '$bits-BIT';
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildVariantTile(PullVariant variant, ThemeData theme) {
    final selected = _selectedVariantName == variant.name;
    final accent = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    final bg = selected
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    final nameColor = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectVariant(variant.name),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent, width: selected ? 1.5 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    variant.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: nameColor,
                    ),
                  ),
                  if (variant.sharded) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Multi-file (sharded)',
                      child: Icon(
                        Icons.layers_outlined,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                formatFileSize(variant.sizeBytes.toDouble()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveDownload extends StatelessWidget {
  final DownloadJob job;
  final String? pollingError;

  const _ActiveDownload({required this.job, this.pollingError});

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
                  'Current Download',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _DownloadRow(job: job),
            if (pollingError != null) ...[
              const SizedBox(height: 8),
              Text(
                pollingError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DownloadRow extends ConsumerWidget {
  final DownloadJob job;

  const _DownloadRow({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final percent = job.percent.clamp(0, 100).toDouble();
    final inProgress = job.running;
    final overallTotal = job.totalDownloadSize > 0
        ? job.totalDownloadSize
        : job.bytesTotal;
    final overallDone = job.cumulativeBytesDownloaded > 0
        ? job.cumulativeBytesDownloaded
        : job.bytesDownloaded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                LemonadeModel.stripIdPrefix(job.modelName),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (job.complete || job.status == DownloadStatus.completed)
              Icon(Icons.check_circle, size: 18, color: Colors.green)
            else if (job.status == DownloadStatus.error)
              Icon(Icons.error, size: 18, color: theme.colorScheme.error)
            else
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            if (inProgress) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Cancel download',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: () => runWithErrorFeedback(
                  context,
                  () => ref
                      .read(downloadsProvider.notifier)
                      .control(job, 'cancel'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        if (job.status == DownloadStatus.error)
          Text(
            job.error ?? 'Download failed',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else if (job.complete || job.status == DownloadStatus.completed)
          Text(
            'Download complete',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
          )
        else ...[
          TweenAnimationBuilder<double>(
            tween: Tween(end: percent / 100),
            duration: const Duration(milliseconds: 450),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (job.file?.isNotEmpty == true)
                Text(
                  job.file!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (job.totalFiles > 0)
                Text(
                  'File ${job.fileIndex}/${job.totalFiles}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (overallTotal > 0)
                Text(
                  '${formatFileSize(overallDone.toDouble())} / '
                  '${formatFileSize(overallTotal.toDouble())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (job.speedBytesPerSecond != null)
                Text(
                  formatSpeed(job.speedBytesPerSecond!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
