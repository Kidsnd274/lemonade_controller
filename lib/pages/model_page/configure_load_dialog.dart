import 'package:flutter/material.dart';
import 'package:lemonade_controller/models/lemonade_load_options.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';

const _llamacppBackends = ['vulkan', 'rocm', 'metal', 'cpu'];

/// Shows the Configure & Load dialog pre-populated from [model.recipeOptions].
///
/// Returns a [LemonadeLoadOptionsModel] when the user confirms, or `null` on
/// cancel.
Future<LemonadeLoadOptionsModel?> showConfigureLoadDialog(
  BuildContext context,
  LemonadeModel model,
) {
  return showDialog<LemonadeLoadOptionsModel>(
    context: context,
    builder: (_) => _ConfigureLoadDialog(model: model),
  );
}

class _ConfigureLoadDialog extends StatefulWidget {
  final LemonadeModel model;
  const _ConfigureLoadDialog({required this.model});

  @override
  State<_ConfigureLoadDialog> createState() => _ConfigureLoadDialogState();
}

class _ConfigureLoadDialogState extends State<_ConfigureLoadDialog> {
  late final TextEditingController _ctxSizeController;
  late final TextEditingController _llamacppArgsController;
  String? _llamacppBackend;
  bool _saveOptions = false;

  @override
  void initState() {
    super.initState();
    final opts = widget.model.recipeOptions;

    _ctxSizeController = TextEditingController(
      text: opts['ctx_size']?.toString() ?? '',
    );
    _llamacppArgsController = TextEditingController(
      text: opts['llamacpp_args']?.toString() ?? '',
    );

    final stored = opts['llamacpp_backend']?.toString();
    _llamacppBackend = (stored != null && _llamacppBackends.contains(stored))
        ? stored
        : null;
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
      modelName: widget.model.id,
      saveOptions: _saveOptions ? true : null,
      ctxSize: ctxText.isNotEmpty ? int.tryParse(ctxText) : null,
      llamacppBackend: _llamacppBackend,
      llamacppArgs: argsText.isNotEmpty ? argsText : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Configure & Load'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.model.displayName,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Recipe: ${widget.model.recipe}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

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
                value: _llamacppBackend,
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
              const SizedBox(height: 8),

              CheckboxListTile(
                value: _saveOptions,
                onChanged: (v) => setState(() => _saveOptions = v ?? false),
                title: const Text('Save options'),
                subtitle: const Text('Persist these settings for future loads'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
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
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_buildOptions()),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Configure & Load'),
          autofocus: true,
        ),
      ],
    );
  }
}
