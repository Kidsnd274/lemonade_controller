<div align="center">

<img src="assets/icon/app_icon.png" alt="Lemonade Controller icon" width="128" height="128" />

# Lemonade Controller 🍋

**A cross-platform control center for your Lemonade Server.**

Browse and pull models, manage model slots, follow live inference, inspect
CPU/GPU/NPU performance, and watch server logs from a responsive desktop or
mobile interface.

[![Latest release](https://img.shields.io/github/v/release/Kidsnd274/lemonade_controller?display_name=tag&sort=semver&label=latest&color=2E7D32)](https://github.com/Kidsnd274/lemonade_controller/releases/latest)
[![Platform: Windows](https://img.shields.io/badge/Windows-0078D6?logo=windows&logoColor=white)](#download)
[![Platform: macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white)](#download)
[![Platform: Linux](https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black)](#download)
[![Platform: Android](https://img.shields.io/badge/Android-3DDC84?logo=android&logoColor=white)](#download)
[![Built with Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)

[**Download the latest release**](https://github.com/Kidsnd274/lemonade_controller/releases/latest)
·
[All releases](https://github.com/Kidsnd274/lemonade_controller/releases)
·
[Lemonade Server](https://github.com/lemonade-sdk/lemonade)

</div>

> [!NOTE]
> Lemonade Controller is an unofficial, community-built companion for
> [Lemonade Server](https://github.com/lemonade-sdk/lemonade).

## What is Lemonade Controller?

Lemonade Server gives you a local API for running AI models. Lemonade
Controller puts a full graphical interface on top of it, so you can manage a
server on the same machine or elsewhere on your network without reaching for
the terminal.

It is built for both quick everyday actions—loading a favourite model or
checking a download—and deeper server visibility, including model slots,
inference stages, request statistics, hardware telemetry, and live logs.

## Screenshots

<img src="docs/images/desktop.png" alt="Lemonade Controller desktop dashboard" width="100%" />

<div align="center">
  <img src="docs/images/image1.jpg" alt="Lemonade Controller mobile dashboard" width="18%" />
  <img src="docs/images/image2.jpg" alt="Lemonade Controller model catalog" width="18%" />
  <img src="docs/images/image3.jpg" alt="Lemonade Controller model details" width="18%" />
  <img src="docs/images/image4.jpg" alt="Lemonade Controller model pull workflow" width="18%" />
  <img src="docs/images/image5.jpg" alt="Lemonade Controller presets" width="18%" />
</div>

## Features

### Model management

- Browse the server's complete model catalog with search, favourites,
  Custom/Built-in filters, and quantization filters.
- Inspect model metadata, local files, quantization, maximum context window,
  estimated VRAM usage, and update availability.
- Load, unload, configure, update, or delete models from one interface.
- Configure context size, backends, runtime arguments, image-generation
  options, model pinning, automatic eviction, idle timeouts, and eviction
  weighting.
- Save multi-model load presets, estimate their combined VRAM use, reorder
  entries, and launch the whole setup in one action.

### Pulls and downloads

- Paste a Hugging Face repository or `lemonade pull` command and select from
  the available quantization variants.
- Automatically fill the suggested model name, recipe, capability labels, and
  multimodal projection file when the server provides them.
- Follow percentage, current file, bytes transferred, and download speed
  inline on the Pull page.
- Manage active, paused, completed, and failed jobs from the dedicated
  Downloads page, including pause, resume, cancel, and remove controls.

### Monitoring and observability

- See server health, version, WebSocket port, available model slots, loaded
  models, pinned models, and models currently loading.
- Track concurrent inference requests live, including auto-loading, prompt,
  generation, completion, elapsed time, and estimated time remaining.
- Review the latest request's prompt tokens, generated tokens, time to first
  token, and generation rate.
- Monitor CPU, memory, GPU, VRAM, and NPU utilization with live meters and
  history charts.
- Stream server logs with severity and tag filters, optional autoscroll, local
  clearing, and reconnect controls.

### Profiles and personalization

- Save and switch between multiple local or remote Lemonade Server profiles.
- Connect through bearer-token authentication, custom HTTP headers, and an
  optional WebSocket URL override.
- Test a server connection before saving it.
- Choose system, light, or dark appearance and adjust the UI scale.
- Configure model refresh and performance-sampling intervals.
- Export, import, or reset locally stored settings.

## Download

Prebuilt packages are published on the
[GitHub Releases page](https://github.com/Kidsnd274/lemonade_controller/releases/latest).

| Platform | Available packages |
| --- | --- |
| **Windows x64** | Installer (`.exe`) or portable archive (`.zip`) |
| **macOS** | Apple Silicon, Intel, or Universal archives (`.zip`) |
| **Linux x64** | Debian (`.deb`) or RPM (`.rpm`) package |
| **Android** | `arm64-v8a`, `armeabi-v7a`, or `x86_64` APK |
| **iOS / Web** | Build from source |

For Android, `arm64-v8a` is the right choice for most modern phones and
tablets. On macOS, choose `arm64` for Apple Silicon or `x64` for Intel; the
Universal build supports both.

## Quick start

1. Start a [Lemonade Server](https://github.com/lemonade-sdk/lemonade) that is
   reachable from your device.
2. Download and launch Lemonade Controller.
3. Open **Settings → Server Profiles**, add the API base URL, and use
   **Test Connection** to verify it. The default local URL is
   `http://localhost:8020/api/v1`.
4. Open **Home** for an overview, **Models** to manage the catalog, or **Pull**
   to download a model from Hugging Face.

Lemonade Server 10.10 or newer is recommended for the complete current feature
set. The app detects unsupported endpoints and keeps compatible areas
available when connected to an older server.

App settings—including profiles, favourites, presets, refresh preferences,
appearance, and model parameter overrides—are stored locally on the device.

## Build from source

### Requirements

- Flutter SDK with a Dart version compatible with `^3.10.8`
- A reachable Lemonade Server API endpoint
- Platform build tooling for your chosen target

### Run locally

```bash
git clone https://github.com/Kidsnd274/lemonade_controller.git
cd lemonade_controller
flutter pub get
flutter run
```

### Build and package

The scripts in `scripts/` read the app version from `pubspec.yaml` and place
release artifacts in `dist/`:

- `scripts/build_windows.bat` — Windows portable archive and Inno Setup
  installer
- `scripts/build_android.bat` — versioned, ABI-split Android APKs
- `scripts/build_macos.sh` — Apple Silicon, Intel, and Universal archives
- `scripts/build_linux.sh` — Debian and RPM packages

## API coverage

Lemonade Controller uses the configurable Lemonade Server API base URL
(`http://localhost:8020/api/v1` by default).

| Area | Endpoints |
| --- | --- |
| Server and hardware | `GET /health`, `GET /system-info`, `GET /system-stats`, `GET /stats` |
| Models | `GET /models`, `GET /models/{id}/files` |
| Model lifecycle | `POST /load`, `POST /unload`, `POST /delete` |
| Pulls | `GET /pull/variants`, `POST /pull` |
| Downloads | `GET /downloads`, `POST /downloads/control` |
| Live activity | Lemonade Server WebSocket log stream |

## Tech stack

- [Flutter](https://flutter.dev) and Dart
- [Riverpod](https://riverpod.dev) for application state
- [Dio](https://pub.dev/packages/dio) for HTTP
- [fl_chart](https://pub.dev/packages/fl_chart) for performance history
- SharedPreferences for local settings
- WebSocket Channel for live server activity

## Project structure

```text
lib/
├── main.dart                 # App bootstrap, theme, and UI scaling
├── models/                   # API and local domain models
├── pages/
│   ├── home/                 # Server dashboard and live inference activity
│   ├── models_list/          # Searchable and filterable model catalog
│   ├── model_page/           # Model metadata, files, VRAM, and actions
│   ├── pull/                 # Hugging Face variant picker and pull form
│   ├── downloads/            # Server-managed download queue
│   ├── performance/          # CPU, memory, GPU, VRAM, and NPU charts
│   ├── presets/              # Multi-model load presets
│   ├── logs/                 # Filterable live server logs
│   ├── settings/             # Profiles, appearance, data, and overrides
│   └── widgets/              # Shared responsive navigation
├── providers/                # Riverpod state and async orchestration
├── services/                 # API, WebSocket, and settings services
├── theme/                    # Material theme definitions
└── utils/                    # Formatters, quantization, logging, and VRAM
```

## Feedback

Found a bug or have an idea? Open an
[issue](https://github.com/Kidsnd274/lemonade_controller/issues).
