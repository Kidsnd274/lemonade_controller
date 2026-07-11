class SystemStats {
  final double? cpuPercent;
  final double? memoryGb;
  final double? gpuPercent;
  final double? vramGb;
  final double? npuPercent;

  const SystemStats({
    this.cpuPercent,
    this.memoryGb,
    this.gpuPercent,
    this.vramGb,
    this.npuPercent,
  });

  factory SystemStats.fromJson(Map<String, dynamic> json) => SystemStats(
    cpuPercent: (json['cpu_percent'] as num?)?.toDouble(),
    memoryGb: (json['memory_gb'] as num?)?.toDouble(),
    gpuPercent: (json['gpu_percent'] as num?)?.toDouble(),
    vramGb: (json['vram_gb'] as num?)?.toDouble(),
    npuPercent: (json['npu_percent'] as num?)?.toDouble(),
  );

  bool get hasAnyValue =>
      cpuPercent != null ||
      memoryGb != null ||
      gpuPercent != null ||
      vramGb != null ||
      npuPercent != null;
}

class SystemStatsSample {
  final DateTime timestamp;
  final SystemStats stats;

  const SystemStatsSample({required this.timestamp, required this.stats});
}
