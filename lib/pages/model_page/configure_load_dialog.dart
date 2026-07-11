import 'package:flutter/material.dart';
import 'package:lemonade_controller/models/lemonade_load_options.dart';
import 'package:lemonade_controller/models/lemonade_model.dart';

const _llamacppBackends = ['vulkan', 'rocm', 'metal', 'cpu'];

Future<LemonadeLoadOptionsModel?> showConfigureLoadDialog(
  BuildContext context,
  LemonadeModel model,
) => showDialog<LemonadeLoadOptionsModel>(
  context: context,
  builder: (_) => _ConfigureLoadDialog(model: model),
);

class _ConfigureLoadDialog extends StatefulWidget {
  final LemonadeModel model;
  const _ConfigureLoadDialog({required this.model});
  @override
  State<_ConfigureLoadDialog> createState() => _ConfigureLoadDialogState();
}

class _ConfigureLoadDialogState extends State<_ConfigureLoadDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ctx;
  late final TextEditingController _args;
  late final TextEditingController _downsize;
  late final TextEditingController _evict;
  late final TextEditingController _weight;
  late final TextEditingController _steps;
  late final TextEditingController _cfg;
  late final TextEditingController _width;
  late final TextEditingController _height;
  String? _backend;
  bool _save = false;
  bool _pinned = false;
  bool? _mergeArgs;
  bool? _autoEvict;

  @override
  void initState() {
    super.initState();
    final o = widget.model.recipeOptions;
    _ctx = TextEditingController(text: o['ctx_size']?.toString() ?? '');
    _args = TextEditingController(text: o['llamacpp_args']?.toString() ?? '');
    _downsize = TextEditingController(
      text: o['downsize_idle_timeout']?.toString() ?? '',
    );
    _evict = TextEditingController(
      text: o['evict_idle_timeout']?.toString() ?? '',
    );
    _weight = TextEditingController(
      text: o['evict_weight_factor']?.toString() ?? '',
    );
    _steps = TextEditingController(text: o['steps']?.toString() ?? '');
    _cfg = TextEditingController(text: o['cfg_scale']?.toString() ?? '');
    _width = TextEditingController(text: o['width']?.toString() ?? '');
    _height = TextEditingController(text: o['height']?.toString() ?? '');
    final backend = o['llamacpp_backend']?.toString();
    _backend = _llamacppBackends.contains(backend) ? backend : null;
    _mergeArgs = o['merge_args'] as bool?;
    _autoEvict = o['auto_evict'] as bool?;
  }

  @override
  void dispose() {
    for (final controller in [
      _ctx,
      _args,
      _downsize,
      _evict,
      _weight,
      _steps,
      _cfg,
      _width,
      _height,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _integer(TextEditingController value) =>
      value.text.trim().isEmpty ? null : int.tryParse(value.text.trim());
  double? _decimal(TextEditingController value) =>
      value.text.trim().isEmpty ? null : double.tryParse(value.text.trim());

  String? _contextValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = int.tryParse(value);
    if (parsed == null || (parsed != -1 && parsed <= 0)) {
      return 'Use -1 for auto or a positive number';
    }
    return null;
  }

  String? _nonNegative(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = int.tryParse(value);
    return parsed == null || parsed < 0
        ? 'Enter zero or a positive number'
        : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      LemonadeLoadOptionsModel(
        modelName: widget.model.id,
        saveOptions: _save ? true : null,
        pinned: _pinned ? true : null,
        ctxSize: _integer(_ctx),
        llamacppBackend: _backend,
        llamacppArgs: _args.text.trim().isEmpty ? null : _args.text.trim(),
        mergeArgs: _mergeArgs,
        autoEvict: _autoEvict,
        downsizeIdleTimeout: _integer(_downsize),
        evictIdleTimeout: _integer(_evict),
        evictWeightFactor: _decimal(_weight),
        steps: _integer(_steps),
        cfgScale: _decimal(_cfg),
        width: _integer(_width),
        height: _integer(_height),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLlama = widget.model.recipe == 'llamacpp';
    final isImage = widget.model.recipe == 'sd-cpp';
    return AlertDialog(
      title: const Text('Configure & Load'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.model.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ctx,
                  validator: _contextValidator,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Context size',
                    helperText:
                        'Leave empty for server default; -1 selects automatic sizing',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (isLlama) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _backend,
                    decoration: const InputDecoration(
                      labelText: 'llama.cpp backend',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Server default'),
                      ),
                      for (final backend in _llamacppBackends)
                        DropdownMenuItem(value: backend, child: Text(backend)),
                    ],
                    onChanged: (value) => setState(() => _backend = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _args,
                    decoration: const InputDecoration(
                      labelText: 'llama.cpp arguments',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  DropdownButtonFormField<bool?>(
                    initialValue: _mergeArgs,
                    decoration: const InputDecoration(
                      labelText: 'Argument inheritance',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Server default'),
                      ),
                      DropdownMenuItem(
                        value: true,
                        child: Text('Merge with global arguments'),
                      ),
                      DropdownMenuItem(
                        value: false,
                        child: Text('Replace global arguments'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _mergeArgs = value),
                  ),
                ],
                if (isImage) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(controller: _steps, label: 'Steps'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NumberField(
                          controller: _cfg,
                          label: 'CFG scale',
                          decimal: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(controller: _width, label: 'Width'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NumberField(
                          controller: _height,
                          label: 'Height',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _pinned,
                  onChanged: (value) =>
                      setState(() => _pinned = value ?? false),
                  title: const Text('Pin in memory'),
                  subtitle: const Text('Protect this model from LRU eviction'),
                  contentPadding: EdgeInsets.zero,
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Advanced eviction'),
                  children: [
                    DropdownButtonFormField<bool?>(
                      initialValue: _autoEvict,
                      decoration: const InputDecoration(
                        labelText: 'Auto eviction',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Server default'),
                        ),
                        DropdownMenuItem(value: true, child: Text('Enabled')),
                        DropdownMenuItem(value: false, child: Text('Disabled')),
                      ],
                      onChanged: (value) => setState(() => _autoEvict = value),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _downsize,
                      validator: _nonNegative,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Downsize idle timeout (seconds)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _evict,
                      validator: _nonNegative,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Evict idle timeout (seconds)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final parsed = double.tryParse(value);
                        return parsed == null || parsed <= 0
                            ? 'Enter a positive number'
                            : null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Eviction weight',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
                CheckboxListTile(
                  value: _save,
                  onChanged: (value) => setState(() => _save = value ?? false),
                  title: const Text('Save recipe options'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Load'),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool decimal;
  const _NumberField({
    required this.controller,
    required this.label,
    this.decimal = false,
  });
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    validator: (value) {
      if (value == null || value.trim().isEmpty) return null;
      final parsed = decimal ? double.tryParse(value) : int.tryParse(value);
      return parsed == null ? 'Invalid number' : null;
    },
  );
}
