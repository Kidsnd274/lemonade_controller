class LogEntry {
  final int seq;
  final String timestamp;
  final String severity;
  final String tag;
  final String line;

  const LogEntry({
    required this.seq,
    required this.timestamp,
    required this.severity,
    required this.tag,
    required this.line,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    seq: (json['seq'] as num?)?.toInt() ?? 0,
    timestamp: json['timestamp']?.toString() ?? '',
    severity: json['severity']?.toString() ?? 'Info',
    tag: json['tag']?.toString() ?? '',
    line: json['line']?.toString() ?? '',
  );
}
