import 'dart:convert';

import 'package:flutter/material.dart';

class ModelParamsJsonEditorPage extends StatefulWidget {
  final Map<String, double> overrides;
  const ModelParamsJsonEditorPage({super.key, required this.overrides});

  @override
  State<ModelParamsJsonEditorPage> createState() =>
      _ModelParamsJsonEditorPageState();
}

class _ModelParamsJsonEditorPageState extends State<ModelParamsJsonEditorPage> {
  late final TextEditingController _controller;
  String? _error;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(widget.overrides),
    );
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Map<String, double>? _parse() {
    try {
      final decoded = jsonDecode(_controller.text);
      if (decoded is! Map<String, dynamic>) {
        setState(() => _error = 'Root must be a JSON object');
        return null;
      }
      final result = <String, double>{};
      for (final entry in decoded.entries) {
        if (entry.key.startsWith('_')) continue;
        if (entry.value is! num) {
          setState(
            () => _error = 'Value for "${entry.key}" must be a number',
          );
          return null;
        }
        result[entry.key] = (entry.value as num).toDouble();
      }
      setState(() => _error = null);
      return result;
    } on FormatException catch (e) {
      setState(() => _error = 'Invalid JSON: ${e.message}');
      return null;
    }
  }

  void _apply() {
    final parsed = _parse();
    if (parsed == null) return;
    Navigator.of(context).pop(parsed);
  }

  void _format() {
    final parsed = _parse();
    if (parsed == null) return;
    _controller.removeListener(_onTextChanged);
    _controller.text = const JsonEncoder.withIndent('  ').convert(parsed);
    _controller.addListener(_onTextChanged);
  }

  Future<bool> _onWillPop() async {
    if (!_dirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved JSON changes. Do you want to discard them?',
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
          title: const Text('JSON Editor'),
          actions: [
            IconButton(
              onPressed: _format,
              icon: const Icon(Icons.auto_fix_high),
              tooltip: 'Format JSON',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _dirty ? _apply : null,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Apply'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: colorScheme.errorContainer,
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(12),
                    fillColor: colorScheme.surfaceContainerHighest.withAlpha(40),
                    filled: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
