import 'dart:convert';

class ServerProfile {
  final String id;
  final String name;
  final String baseUrl;
  final String? bearerToken;
  final Map<String, String> customHeaders;
  final String? webSocketUrlOverride;

  const ServerProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.bearerToken,
    this.customHeaders = const {},
    this.webSocketUrlOverride,
  });

  String get host => Uri.tryParse(baseUrl)?.host ?? baseUrl;

  String get displayAddress {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return baseUrl;
    final port = uri.port;
    if (port == 0) return uri.host;
    return '${uri.host}:$port';
  }

  ServerProfile copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? bearerToken,
    Map<String, String>? customHeaders,
    String? webSocketUrlOverride,
    bool clearBearerToken = false,
    bool clearWebSocketUrlOverride = false,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      bearerToken: clearBearerToken ? null : bearerToken ?? this.bearerToken,
      customHeaders: customHeaders ?? this.customHeaders,
      webSocketUrlOverride: clearWebSocketUrlOverride
          ? null
          : webSocketUrlOverride ?? this.webSocketUrlOverride,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    if (bearerToken != null && bearerToken!.isNotEmpty)
      'bearerToken': bearerToken,
    if (customHeaders.isNotEmpty) 'customHeaders': customHeaders,
    if (webSocketUrlOverride != null && webSocketUrlOverride!.isNotEmpty)
      'webSocketUrlOverride': webSocketUrlOverride,
  };

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    return ServerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      bearerToken: json['bearerToken']?.toString(),
      customHeaders:
          (json['customHeaders'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
      webSocketUrlOverride: json['webSocketUrlOverride']?.toString(),
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
          baseUrl == other.baseUrl &&
          bearerToken == other.bearerToken &&
          webSocketUrlOverride == other.webSocketUrlOverride &&
          _mapEquals(customHeaders, other.customHeaders);

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    return a.entries.every((entry) => b[entry.key] == entry.value);
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    baseUrl,
    bearerToken,
    webSocketUrlOverride,
    Object.hashAll(
      customHeaders.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() => 'ServerProfile(id: $id, name: $name, baseUrl: $baseUrl)';
}
