# Lemonade Controller 🍋

A cross-platform Flutter app for operating AI models on one or more Lemonade servers.  
It focuses on day-to-day model operations: monitoring server health, loading/unloading models, pulling new checkpoints, and managing reusable load presets.

## Features ✨

- **Responsive Navigation** - Unified app shell with `Home`, `Models`, `Pull`, `Presets`, and `Settings` pages across mobile, tablet, and desktop layouts.
- **Server Dashboard** - Live server health, active model, model slot usage, loaded/loading models, pull/download progress, system specs, and recipe/backend availability.
- **Model Catalog & Actions** - Search and filter models (`user.` and quantization filters), favorite models, and open detailed model pages for load/unload, configure-and-load, and delete.
- **Pull Models from Hugging Face** - Pull by checkpoint/recipe with labels (`reasoning`, `vision`, `embedding`, `reranking`) and live SSE download progress (percent, file, bytes, speed).
- **Model Load Presets** - Create/edit/reorder presets, configure per-model load options (`ctx_size`, `llamacpp_backend`, `llamacpp_args`), and batch-load models.
- **VRAM Estimation Tooling** - Per-model and per-preset VRAM estimates plus editable model parameter overrides (form UI + JSON editor).
- **Multi-Server Profiles** - Save and switch between multiple API base URLs from settings.
- **Portable Settings** - Export/import all app settings as JSON, plus one-click reset to defaults.
- **Appearance Controls** - Theme mode (system/light/dark) and UI scaling controls.
- **Release Packaging Scripts** - Build scripts for Windows, Android, macOS, and Linux distribution artifacts.

## Screenshots 📸

Screenshots are still pending. If you want, open an issue/PR and we can add a gallery section.

## Tech Stack 🛠️

- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **HTTP Client**: Dio
- **Storage**: SharedPreferences
- **Utilities**: Logger, File Picker, Package Info Plus

## API Integration

The app integrates with [Lemonade Server](https://github.com/lemonade-sdk/lemonade) using a configurable API base URL (default: `http://localhost:8020/api/v1`).

- `GET /system-info` - System/device info and recipe/backend capabilities
- `GET /health` - Server status, active model, loaded models, and capacity
- `GET /models` - Model catalog
- `POST /load` - Load a model (optionally with runtime options)
- `POST /unload` - Unload a model
- `POST /delete` - Delete a model
- `POST /pull` - Pull a model with streaming progress events (SSE)

## Getting Started 🚀

### Prerequisites

- Flutter SDK `^3.10.8`
- Dart SDK `^3.10.8`
- A running Lemonade Server API endpoint

### Development Setup

```bash
git clone https://github.com/Kidsnd274/lemonade_controller.git
cd lemonade_controller
flutter pub get
flutter run
```

### Supported Platforms

- Android
- iOS
- Windows
- macOS
- Linux
- Web

## Build & Distribution

Preconfigured scripts are available in `scripts/`:

- **Windows**: `scripts/build_windows.bat`
  - Builds Windows release, zips portable output, and creates an Inno Setup installer.
- **Android**: `scripts/build_android.bat`
  - Builds APKs (split per ABI by default) and copies versioned artifacts into `dist/`.
- **macOS**: `scripts/build_macos.sh`
  - Builds and packages Apple Silicon, Intel, and Universal zip bundles.
- **Linux**: `scripts/build_linux.sh`
  - Builds release and packages both DEB and RPM artifacts (via `fastforge` or `flutter_distributor`).

Most scripts infer app version from `pubspec.yaml` and write outputs to `dist/`.

## Project Structure

```text
lib/
├── main.dart                 # App bootstrap + theme/UI scale setup
├── models/                   # Domain models (health, system info, presets, pull events, etc.)
├── pages/
│   ├── home/                 # Dashboard cards and status views
│   ├── models_list/          # Search/filter/favourites model catalog
│   ├── model_page/           # Detailed model actions + VRAM estimate
│   ├── pull/                 # Pull form + live download progress
│   ├── presets/              # Preset list/editor and batch loading
│   ├── settings/             # Profiles, appearance, import/export, overrides
│   └── widgets/              # Shared navigation shell widgets
├── providers/                # Riverpod providers and async state orchestration
├── services/                 # API client + settings persistence
├── theme/                    # App theming
└── utils/                    # Formatters, quant colors, VRAM estimator
```

## Notes

- App settings (profiles, favorites, presets, refresh preferences, theme/UI scale, model param overrides) are persisted locally.
- Download progress and model loading state are reflected both in their dedicated pages and the Home dashboard.
- The project is actively evolving; behavior and APIs may continue to improve between releases.

