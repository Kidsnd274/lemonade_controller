enum DownloadStatus {
  downloading,
  paused,
  cancelled,
  completed,
  error,
  unknown,
}

class DownloadJob {
  final String id;
  final String type;
  final String modelName;
  final DownloadStatus status;
  final bool running;
  final String? file;
  final int fileIndex;
  final int totalFiles;
  final int bytesDownloaded;
  final int bytesTotal;
  final int totalDownloadSize;
  final int bytesPreviouslyDownloaded;
  final int completedFilesBytes;
  final int cumulativeBytesDownloaded;
  final double percent;
  final bool complete;
  final String? error;
  final double? speedBytesPerSecond;

  const DownloadJob({
    required this.id,
    required this.type,
    required this.modelName,
    required this.status,
    required this.running,
    this.file,
    this.fileIndex = 0,
    this.totalFiles = 0,
    this.bytesDownloaded = 0,
    this.bytesTotal = 0,
    this.totalDownloadSize = 0,
    this.bytesPreviouslyDownloaded = 0,
    this.completedFilesBytes = 0,
    this.cumulativeBytesDownloaded = 0,
    this.percent = 0,
    this.complete = false,
    this.error,
    this.speedBytesPerSecond,
  });

  factory DownloadJob.fromJson(Map<String, dynamic> json) {
    final raw = json['status']?.toString() ?? '';
    return DownloadJob(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'model',
      modelName: json['model_name']?.toString() ?? '',
      status: DownloadStatus.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => DownloadStatus.unknown,
      ),
      running: json['running'] as bool? ?? false,
      file: json['file']?.toString(),
      fileIndex: (json['file_index'] as num?)?.toInt() ?? 0,
      totalFiles: (json['total_files'] as num?)?.toInt() ?? 0,
      bytesDownloaded: (json['bytes_downloaded'] as num?)?.toInt() ?? 0,
      bytesTotal: (json['bytes_total'] as num?)?.toInt() ?? 0,
      totalDownloadSize: (json['total_download_size'] as num?)?.toInt() ?? 0,
      bytesPreviouslyDownloaded:
          (json['bytes_previously_downloaded'] as num?)?.toInt() ?? 0,
      completedFilesBytes:
          (json['completed_files_bytes'] as num?)?.toInt() ?? 0,
      cumulativeBytesDownloaded:
          (json['cumulative_bytes_downloaded'] as num?)?.toInt() ??
          (json['overall_bytes_downloaded'] as num?)?.toInt() ??
          0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
      complete: json['complete'] as bool? ?? false,
      error: json['error']?.toString(),
    );
  }

  DownloadJob copyWith({double? speedBytesPerSecond}) => DownloadJob(
    id: id,
    type: type,
    modelName: modelName,
    status: status,
    running: running,
    file: file,
    fileIndex: fileIndex,
    totalFiles: totalFiles,
    bytesDownloaded: bytesDownloaded,
    bytesTotal: bytesTotal,
    totalDownloadSize: totalDownloadSize,
    bytesPreviouslyDownloaded: bytesPreviouslyDownloaded,
    completedFilesBytes: completedFilesBytes,
    cumulativeBytesDownloaded: cumulativeBytesDownloaded,
    percent: percent,
    complete: complete,
    error: error,
    speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
  );

  bool get canPause => running && status == DownloadStatus.downloading;
  bool get canResume => !running && status == DownloadStatus.paused;
  bool get isTerminal =>
      status == DownloadStatus.completed ||
      status == DownloadStatus.cancelled ||
      status == DownloadStatus.error;
}
