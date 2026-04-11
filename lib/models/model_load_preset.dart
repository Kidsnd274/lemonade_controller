import 'dart:convert';

import 'package:lemonade_controller/models/lemonade_load_options.dart';

class ModelLoadPreset {
  final String id;
  final String name;
  final List<LemonadeLoadOptionsModel> entries;

  const ModelLoadPreset({
    required this.id,
    required this.name,
    this.entries = const [],
  });

  ModelLoadPreset copyWith({
    String? id,
    String? name,
    List<LemonadeLoadOptionsModel>? entries,
  }) {
    return ModelLoadPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      entries: entries ?? this.entries,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory ModelLoadPreset.fromJson(Map<String, dynamic> json) {
    return ModelLoadPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      entries: (json['entries'] as List?)
              ?.map(
                (e) =>
                    LemonadeLoadOptionsModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  static String encodeList(List<ModelLoadPreset> presets) {
    return jsonEncode(presets.map((p) => p.toJson()).toList());
  }

  static List<ModelLoadPreset> decodeList(String encoded) {
    final list = jsonDecode(encoded) as List;
    return list
        .map((e) => ModelLoadPreset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelLoadPreset &&
          id == other.id &&
          name == other.name &&
          _listEquals(entries, other.entries);

  static bool _listEquals(
    List<LemonadeLoadOptionsModel> a,
    List<LemonadeLoadOptionsModel> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(entries));

  @override
  String toString() =>
      'ModelLoadPreset(id: $id, name: $name, entries: ${entries.length})';
}
