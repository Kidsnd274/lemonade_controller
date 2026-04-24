# Plan: Minimal Pull Payload, Advanced Overrides, and CLI Paste Parsing

## Goal

Make the Pull Model flow in [`lib/pages/pull/pull_page.dart`](../lib/pages/pull/pull_page.dart) behave closer to `lemonade pull`:

1. Normal users provide a model name and checkpoint.
2. Lemonade Server can auto-detect optional values when the app does not send them.
3. Advanced users can explicitly override recipe and labels.
4. Users can paste common `lemonade pull` commands into the checkpoint field, have the model name auto-filled, and have Advanced Settings disabled while command mode is active.

## Current Issue

The current pull form initializes labels as booleans in [`lib/pages/pull/pull_page.dart`](../lib/pages/pull/pull_page.dart), so the UI starts from explicit `false` values instead of unspecified values.

The current request model in [`lib/models/pull_request_options.dart`](../lib/models/pull_request_options.dart) also treats recipe as required. That means the app can accidentally override Lemonade Server defaults instead of allowing auto-detection.

## Desired Behavior

### Basic flow

Only show these required fields by default:

- Model Name
- Checkpoint / Lemonade command

If the user submits without opening or changing Advanced Settings, the JSON payload should be minimal:

```json
{
  "model_name": "user.qwen3.6-gguf",
  "checkpoint": "unsloth/qwen3.6-gguf",
  "stream": true
}
```

### Advanced Settings flow

Hide optional overrides under a collapsed Advanced Settings section:

- Recipe override, default Auto
- Reasoning: Auto / Yes / No
- Vision: Auto / Yes / No
- Embedding: Auto / Yes / No
- Reranking: Auto / Yes / No
- mmproj, shown only when Vision is Yes

Auto means the field is `null` in app state and omitted from JSON.

Yes means the field is `true` and included in JSON.

No means the field is `false` and included in JSON.

Example payload when the user explicitly sets Recipe to `llamacpp` and Vision to No:

```json
{
  "model_name": "user.qwen3.6-gguf",
  "checkpoint": "unsloth/qwen3.6-gguf",
  "recipe": "llamacpp",
  "vision": false,
  "stream": true
}
```

### Command paste flow

When the checkpoint field contains a detected `lemonade pull` command:

- Keep Model Name required.
- Auto-fill Model Name from the command/checkpoint using the same behavior as the current checkpoint auto-fill logic. (It should already do this)
- Replace or normalize the checkpoint field to the extracted checkpoint value before submit.
- Disable Advanced Settings while command mode is active.
- Do not apply recipe or label overrides from the disabled Advanced Settings UI.
- If a command contains supported explicit command flags such as `--recipe`, those values may be parsed from the command itself, but they should not become editable through Advanced Settings while command mode is active.

## Implementation Plan

### 1. Update the request model

Modify [`lib/models/pull_request_options.dart`](../lib/models/pull_request_options.dart):

- Keep `modelName` required.
- Keep `checkpoint` required.
- Make `recipe` nullable.
- Make `reasoning`, `vision`, `embedding`, and `reranking` nullable.
- Keep `mmproj` nullable.
- Update `toJson()` so it always sends `model_name`, `checkpoint`, and `stream`.
- Update `toJson()` so it only sends `recipe`, labels, and `mmproj` when non-null.
- Ensure explicit `false` values are sent, not dropped.

Target shape:

```dart
class PullRequestOptions {
  final String modelName;
  final String checkpoint;
  final String? recipe;
  final bool? reasoning;
  final bool? vision;
  final bool? embedding;
  final bool? reranking;
  final String? mmproj;

  const PullRequestOptions({
    required this.modelName,
    required this.checkpoint,
    this.recipe,
    this.reasoning,
    this.vision,
    this.embedding,
    this.reranking,
    this.mmproj,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'model_name': modelName,
      'checkpoint': checkpoint,
      'stream': true,
    };

    if (recipe != null && recipe!.isNotEmpty) json['recipe'] = recipe;
    if (reasoning != null) json['reasoning'] = reasoning;
    if (vision != null) json['vision'] = vision;
    if (embedding != null) json['embedding'] = embedding;
    if (reranking != null) json['reranking'] = reranking;
    if (mmproj != null && mmproj!.isNotEmpty) json['mmproj'] = mmproj;

    return json;
  }
}
```

### 2. Simplify default UI state

Modify [`lib/pages/pull/pull_page.dart`](../lib/pages/pull/pull_page.dart):

- Change `_selectedRecipe` from default `llamacpp` to `null`.
- Change `_reasoning`, `_vision`, `_embedding`, and `_reranking` from `false` to nullable booleans.
- Add a simple state flag for Advanced Settings expansion if needed.
- Keep Model Name and Checkpoint visible outside Advanced Settings.

Target state shape:

```dart
String? _selectedRecipe;
bool? _reasoning;
bool? _vision;
bool? _embedding;
bool? _reranking;
```

### 3. Replace ambiguous chips with explicit tri-state controls

Avoid tap-cycling chips because an unselected chip does not clearly communicate Auto versus No.

Use a small explicit control for each label:

- Auto
- Yes
- No

The implementation can use `SegmentedButton<bool?>`, `DropdownButtonFormField<bool?>`, or a small reusable widget. The important requirement is that users can clearly see and choose all three states.

### 4. Move optional controls into Advanced Settings

In [`lib/pages/pull/pull_page.dart`](../lib/pages/pull/pull_page.dart), place these inside a collapsed Advanced Settings section:

- Recipe override with Auto as the default value.
- Reasoning tri-state control.
- Vision tri-state control.
- Embedding tri-state control.
- Reranking tri-state control.
- mmproj text field only when Vision is explicitly Yes.

If Advanced Settings remains untouched, all optional state remains null and is omitted from the payload.

### 5. Add Lemonade command parsing to the checkpoint field

Enhance the existing checkpoint listener in [`lib/pages/pull/pull_page.dart`](../lib/pages/pull/pull_page.dart).

Supported paste inputs:

```bash
lemonade pull org/repo
lemonade pull org/repo:Q4_K_M
lemonade pull user.MyModel --checkpoint main "org/repo:file.gguf" --recipe llamacpp
```

Required behavior:

- If the checkpoint field starts with `lemonade pull`, parse it.
- Extract the checkpoint value.
- Replace the checkpoint field text with only the extracted checkpoint.
- Auto-fill the model name only if the model name field is empty.
- Disable Advanced Settings while command mode is active.
- Do not infer labels in the app; Lemonade Server should infer them unless the user explicitly changes Advanced Settings outside command mode.
- If `--recipe` is present in the command, the parser may include it as a command-derived value, but the Advanced Settings recipe control should remain disabled while command mode is active.

Parsing does not need to support every possible shell command. It only needs to support the common documented patterns above.

### 6. Update submit behavior

In [`lib/pages/pull/pull_page.dart`](../lib/pages/pull/pull_page.dart), create `PullRequestOptions` with nullable optional values:

```dart
final options = PullRequestOptions(
  modelName: modelName,
  checkpoint: _checkpointController.text.trim(),
  recipe: _selectedRecipe,
  reasoning: _reasoning,
  vision: _vision,
  embedding: _embedding,
  reranking: _reranking,
  mmproj: _vision == true && _mmprojController.text.trim().isNotEmpty
      ? _mmprojController.text.trim()
      : null,
);
```

## Acceptance Criteria

- Submitting with only model name and checkpoint sends no `recipe`, `reasoning`, `vision`, `embedding`, `reranking`, or `mmproj` keys.
- Setting an advanced label to Yes sends that key with `true`.
- Setting an advanced label to No sends that key with `false`.
- Leaving an advanced label on Auto omits that key.
- Leaving recipe on Auto omits `recipe`.
- Selecting a recipe sends `recipe`.
- Pasting `lemonade pull unsloth/qwen3.6-gguf` fills checkpoint as `unsloth/qwen3.6-gguf` and model name as `qwen3.6-gguf` if empty.
- Pasting `lemonade pull unsloth/qwen3.6-gguf:Q4_K_M` preserves the variant in checkpoint.
- Pasting `lemonade pull user.MyModel --checkpoint main "org/repo:file.gguf" --recipe llamacpp` fills model name as `MyModel`, checkpoint as `org/repo:file.gguf`, and disables Advanced Settings while command mode is active.
- Model Name remains required because the pull API still requires `model_name`.
- Advanced Settings is disabled whenever a detected command is present in the checkpoint field.

## Final Todo List

- Update [`lib/models/pull_request_options.dart`](../lib/models/pull_request_options.dart) to make recipe and advanced fields nullable.
- Update `toJson()` to omit nullable optional fields while preserving explicit `false` values.
- Update [`lib/pages/pull/pull_page.dart`](../lib/pages/pull/pull_page.dart) so defaults are null instead of false or `llamacpp`.
- Add collapsed Advanced Settings with recipe and tri-state label overrides.
- Add command parsing for common `lemonade pull` paste inputs.
- Disable Advanced Settings while a `lemonade pull` command is detected.
- Validate payload behavior for Auto, Yes, No, recipe override, and pasted commands.
