enum PullEventType { progress, complete, error }

class PullProgressEvent {
  final PullEventType eventType;
  final String? file;
  final int? fileIndex;
  final int? totalFiles;
  final int? bytesDownloaded;
  final int? bytesTotal;
  final int? percent;
  final String? errorMessage;

  /// Client-computed download speed in bytes per second.
  final double? speedBytesPerSec;

  const PullProgressEvent({
    required this.eventType,
    this.file,
    this.fileIndex,
    this.totalFiles,
    this.bytesDownloaded,
    this.bytesTotal,
    this.percent,
    this.errorMessage,
    this.speedBytesPerSec,
  });

  factory PullProgressEvent.fromSse(String eventType, Map<String, dynamic> data) {
    final type = switch (eventType) {
      'complete' => PullEventType.complete,
      'error' => PullEventType.error,
      _ => PullEventType.progress,
    };
    return PullProgressEvent(
      eventType: type,
      file: data['file'] as String?,
      fileIndex: (data['file_index'] as num?)?.toInt(),
      totalFiles: (data['total_files'] as num?)?.toInt(),
      bytesDownloaded: (data['bytes_downloaded'] as num?)?.toInt(),
      bytesTotal: (data['bytes_total'] as num?)?.toInt(),
      percent: (data['percent'] as num?)?.toInt(),
      errorMessage: data['error'] as String?,
    );
  }

  PullProgressEvent withSpeed(double? speed) => PullProgressEvent(
    eventType: eventType,
    file: file,
    fileIndex: fileIndex,
    totalFiles: totalFiles,
    bytesDownloaded: bytesDownloaded,
    bytesTotal: bytesTotal,
    percent: percent,
    errorMessage: errorMessage,
    speedBytesPerSec: speed,
  );

  bool get isComplete => eventType == PullEventType.complete;
  bool get isError => eventType == PullEventType.error;
}
