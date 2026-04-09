import 'dart:convert';

class ServerProfile {
  final String id;
  final String name;
  final String baseUrl;

  const ServerProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
  });

  String get host => Uri.tryParse(baseUrl)?.host ?? baseUrl;

  String get displayAddress {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return baseUrl;
    final port = uri.port;
    if (port == 0) return uri.host;
    return '${uri.host}:$port';
  }

  ServerProfile copyWith({String? id, String? name, String? baseUrl}) {
    return ServerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'baseUrl': baseUrl};

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    return ServerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
    );
  }

  static String encodeList(List<ServerProfile> profiles) {
    return jsonEncode(profiles.map((p) => p.toJson()).toList());
  }

  static List<ServerProfile> decodeList(String encoded) {
    final list = jsonDecode(encoded) as List;
    return list
        .map((e) => ServerProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static ServerProfile createDefault({String? baseUrl}) {
    return ServerProfile(
      id: 'default',
      name: 'Local Server',
      baseUrl: baseUrl ?? 'http://localhost:8020/api/v1',
    );
  }

  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerProfile &&
          id == other.id &&
          name == other.name &&
          baseUrl == other.baseUrl;

  @override
  int get hashCode => Object.hash(id, name, baseUrl);

  @override
  String toString() => 'ServerProfile(id: $id, name: $name, baseUrl: $baseUrl)';
}
