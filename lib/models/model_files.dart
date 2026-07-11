class ModelFile {
  final String name;
  final String role;
  final int sizeBytes;
  final bool exists;

  const ModelFile({
    required this.name,
    required this.role,
    required this.sizeBytes,
    required this.exists,
  });

  factory ModelFile.fromJson(Map<String, dynamic> json) => ModelFile(
    name: json['name']?.toString() ?? '',
    role: json['role']?.toString() ?? 'other',
    sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
    exists: json['exists'] as bool? ?? false,
  );
}

class ModelFiles {
  final String modelId;
  final List<ModelFile> files;

  const ModelFiles({required this.modelId, required this.files});

  factory ModelFiles.fromJson(Map<String, dynamic> json) => ModelFiles(
    modelId: json['model_id']?.toString() ?? '',
    files: (json['files'] as List? ?? const [])
        .map((e) => ModelFile.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );
}
