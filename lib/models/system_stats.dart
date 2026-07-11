/// The amount of telemetry retained and rendered by performance charts.
const performanceHistoryDuration = Duration(minutes: 5);

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

/// Maps a sample timestamp into the fixed performance-history chart domain.
///
/// The returned value is measured in seconds from the beginning of the
/// configured history window. A value at the current time therefore lands at
/// [performanceHistoryDuration.inSeconds].
double performanceHistoryX(DateTime timestamp, DateTime windowEnd) {
  final windowStart = windowEnd.subtract(performanceHistoryDuration);
  return timestamp.difference(windowStart).inMilliseconds / 1000;
}
