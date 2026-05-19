class CpuInfo {
  final bool available;
  final String name;
  final String family;
  final int cores;
  final int threads;

  const CpuInfo({
    required this.available,
    required this.name,
    required this.family,
    required this.cores,
    required this.threads,
  });

  factory CpuInfo.fromJson(Map<String, dynamic> json) {
    return CpuInfo(
      available: json['available'] as bool? ?? false,
      name: json['name']?.toString() ?? '',
      family: json['family']?.toString() ?? '',
      cores: (json['cores'] as num?)?.toInt() ?? 0,
      threads: (json['threads'] as num?)?.toInt() ?? 0,
    );
  }
}

class GpuInfo {
  final bool available;
  final String name;
  final String family;
  final double vramGb;
  final double virtualMemGb;
  final String? error;

  const GpuInfo({
    required this.available,
    required this.name,
    required this.family,
    this.vramGb = 0,
    this.virtualMemGb = 0,
    this.error,
  });

  factory GpuInfo.fromJson(Map<String, dynamic> json) {
    return GpuInfo(
      available: json['available'] as bool? ?? false,
      name: json['name']?.toString() ?? '',
      family: json['family']?.toString() ?? '',
      vramGb: (json['vram_gb'] as num?)?.toDouble() ?? 0,
      virtualMemGb: (json['virtual_mem_gb'] as num?)?.toDouble() ?? 0,
      error: json['error']?.toString(),
    );
  }
}

class NpuInfo {
  final bool available;
  final String name;
  final String family;
  final double utilization;

  const NpuInfo({
    required this.available,
    required this.name,
    required this.family,
    this.utilization = 0,
  });

  factory NpuInfo.fromJson(Map<String, dynamic> json) {
    return NpuInfo(
      available: json['available'] as bool? ?? false,
      name: json['name']?.toString() ?? '',
      family: json['family']?.toString() ?? '',
      utilization: (json['utilization'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BackendInfo {
  final String state;
  final String? message;
  final String? version;
  final String? action;
  final List<String> devices;
  final String? releaseUrl;
  final String? downloadFilename;
  final bool canUninstall;

  const BackendInfo({
    required this.state,
    this.message,
    this.version,
    this.action,
    this.devices = const [],
    this.releaseUrl,
    this.downloadFilename,
    this.canUninstall = false,
  });

  factory BackendInfo.fromJson(Map<String, dynamic> json) {
    return BackendInfo(
      state: json['state']?.toString() ?? 'unknown',
      message: json['message']?.toString(),
      version: json['version']?.toString(),
      action: json['action']?.toString(),
      devices: (json['devices'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      releaseUrl: json['release_url']?.toString(),
      downloadFilename: json['download_filename']?.toString(),
      canUninstall: json['can_uninstall'] as bool? ?? false,
    );
  }

  bool get isInstalled => state == 'installed';
  bool get isInstallable => state == 'installable';
  bool get isUnsupported => state == 'unsupported';
}

class RecipeInfo {
  final String defaultBackend;
  final Map<String, BackendInfo> backends;

  const RecipeInfo({
    required this.defaultBackend,
    required this.backends,
  });

  factory RecipeInfo.fromJson(Map<String, dynamic> json) {
    final backendsJson =
        (json['backends'] as Map?)?.cast<String, dynamic>() ?? {};
    return RecipeInfo(
      defaultBackend: json['default_backend']?.toString() ?? '',
      backends: backendsJson.map(
        (key, value) => MapEntry(
          key,
          BackendInfo.fromJson((value as Map).cast<String, dynamic>()),
        ),
      ),
    );
  }

  int get installedCount =>
      backends.values.where((b) => b.isInstalled).length;

  int get totalCount => backends.length;
}

class SystemInfo {
  final String osVersion;
  final String physicalMemory;
  final String processor;
  final CpuInfo cpu;

  // Legacy fields (old API: separate amd_igpu, amd_dgpu, nvidia_dgpu)
  final GpuInfo? amdIgpu;
  final List<GpuInfo> amdDgpus;
  final NpuInfo? amdNpu;
  final List<GpuInfo> nvidiaDgpus;

  // New API fields (consolidated amd_gpu array, renamed nvidia_gpu)
  final List<GpuInfo> amdGpus;
  final List<GpuInfo> nvidiaGpus;

  final Map<String, RecipeInfo> recipes;

  const SystemInfo({
    required this.osVersion,
    required this.physicalMemory,
    required this.processor,
    required this.cpu,
    this.amdIgpu,
    this.amdDgpus = const [],
    this.amdNpu,
    this.nvidiaDgpus = const [],
    this.amdGpus = const [],
    this.nvidiaGpus = const [],
    this.recipes = const {},
  });

  factory SystemInfo.fromJson(Map<String, dynamic> json) {
    final devices =
        (json['devices'] as Map?)?.cast<String, dynamic>() ?? {};
    final recipesJson =
        (json['recipes'] as Map?)?.cast<String, dynamic>() ?? {};

    // Parse CPU
    final cpuJson =
        (devices['cpu'] as Map?)?.cast<String, dynamic>() ?? {};

    // -----------------------------------------------------------------------
    // Parse AMD GPUs – support both old (separate) and new (consolidated) API
    // -----------------------------------------------------------------------

    // New API: amd_gpu is a single array containing all AMD GPUs
    final amdGpus = <GpuInfo>[];
    if (devices['amd_gpu'] is List) {
      for (final item in devices['amd_gpu'] as List) {
        final gpu = GpuInfo.fromJson((item as Map).cast<String, dynamic>());
        if (gpu.available) amdGpus.add(gpu);
      }
    }

    // Legacy API: amd_igpu (single object) + amd_dgpu (array)
    GpuInfo? amdIgpu;
    if (devices['amd_igpu'] is Map) {
      final igpu = GpuInfo.fromJson(
          (devices['amd_igpu'] as Map).cast<String, dynamic>());
      if (igpu.available) amdIgpu = igpu;
    }

    final amdDgpus = <GpuInfo>[];
    if (devices['amd_dgpu'] is List) {
      for (final item in devices['amd_dgpu'] as List) {
        final gpu = GpuInfo.fromJson((item as Map).cast<String, dynamic>());
        if (gpu.available) amdDgpus.add(gpu);
      }
    }

    // -----------------------------------------------------------------------
    // Parse NVIDIA GPUs – support both old and new API
    // -----------------------------------------------------------------------

    // New API: nvidia_gpu (array, renamed from nvidia_dgpu)
    final nvidiaGpus = <GpuInfo>[];
    if (devices['nvidia_gpu'] is List) {
      for (final item in devices['nvidia_gpu'] as List) {
        final gpu = GpuInfo.fromJson((item as Map).cast<String, dynamic>());
        if (gpu.available) nvidiaGpus.add(gpu);
      }
    }

    // Legacy API: nvidia_dgpu (array)
    final nvidiaDgpus = <GpuInfo>[];
    if (devices['nvidia_dgpu'] is List) {
      for (final item in devices['nvidia_dgpu'] as List) {
        final gpu = GpuInfo.fromJson((item as Map).cast<String, dynamic>());
        if (gpu.available) nvidiaDgpus.add(gpu);
      }
    }

    // Parse NPU
    NpuInfo? amdNpu;
    if (devices['amd_npu'] is Map) {
      final npu = NpuInfo.fromJson(
          (devices['amd_npu'] as Map).cast<String, dynamic>());
      if (npu.available) amdNpu = npu;
    }

    return SystemInfo(
      osVersion: json['OS Version']?.toString() ?? '',
      physicalMemory: json['Physical Memory']?.toString() ?? '',
      processor: json['Processor']?.toString() ?? '',
      cpu: CpuInfo.fromJson(cpuJson),
      // Legacy fields populated from old API keys
      amdIgpu: amdIgpu,
      amdDgpus: amdDgpus,
      amdNpu: amdNpu,
      nvidiaDgpus: nvidiaDgpus,
      // New API fields populated from new API keys
      amdGpus: amdGpus,
      nvidiaGpus: nvidiaGpus,
      recipes: recipesJson.map(
        (key, value) => MapEntry(
          key,
          RecipeInfo.fromJson((value as Map).cast<String, dynamic>()),
        ),
      ),
    );
  }

  /// Returns all AMD GPUs, preferring the new consolidated [amdGpus] list
  /// but falling back to legacy [amdIgpu] + [amdDgpus] for backwards
  /// compatibility.
  List<GpuInfo> get allAmdGpus =>
      amdGpus.isNotEmpty ? amdGpus : _legacyAmdGpus;

  /// Returns all NVIDIA GPUs, preferring the new [nvidiaGpus] list
  /// but falling back to legacy [nvidiaDgpus] for backwards
  /// compatibility.
  List<GpuInfo> get allNvidiaGpus =>
      nvidiaGpus.isNotEmpty ? nvidiaGpus : nvidiaDgpus;

  List<GpuInfo> get _legacyAmdGpus {
    final gpus = <GpuInfo>[];
    if (amdIgpu != null) gpus.add(amdIgpu!);
    gpus.addAll(amdDgpus);
    return gpus;
  }

  /// All available devices as a flat list of (label, icon, detail) tuples.
  /// Works with both old and new API responses.
  List<({String label, String icon, String detail})> get availableDevices {
    final result = <({String label, String icon, String detail})>[];

    if (cpu.available) {
      result.add((
        label: 'CPU',
        icon: 'cpu',
        detail: '${cpu.cores} cores / ${cpu.threads} threads (${cpu.family})',
      ));
    }

    // AMD GPUs – unified display for both old and new API
    for (final gpu in allAmdGpus) {
      // Determine if this is likely integrated (0.5 GB VRAM or less) or
      // discrete based on VRAM heuristic when we don't have explicit info.
      final isIntegrated = gpu.vramGb <= 0.5;
      result.add((
        label: isIntegrated ? 'AMD iGPU' : 'AMD dGPU',
        icon: 'gpu',
        detail: _gpuDetail(gpu),
      ));
    }

    // NVIDIA GPUs
    for (final gpu in allNvidiaGpus) {
      result.add((
        label: 'NVIDIA GPU',
        icon: 'gpu',
        detail: _gpuDetail(gpu),
      ));
    }

    if (amdNpu != null) {
      result.add((
        label: 'NPU',
        icon: 'npu',
        detail: '${amdNpu!.name} (${amdNpu!.family})',
      ));
    }

    return result;
  }

  /// Format a human-readable GPU detail string.
  static String _gpuDetail(GpuInfo gpu) {
    final parts = <String>[gpu.name];
    if (gpu.vramGb > 0) {
      parts.add('${gpu.vramGb.toStringAsFixed(1)} GB VRAM');
    }
    if (gpu.family.isNotEmpty) {
      parts.add(gpu.family);
    }
    return parts.join(' · ');
  }
}
