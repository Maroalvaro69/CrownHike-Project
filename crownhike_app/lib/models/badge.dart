// lib/models/badge.dart

class Badge {
  final int id;
  final String code;
  final String name;
  final String description;
  final int? requiredPeaks;

  Badge({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    this.requiredPeaks,
  });

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: _toInt(json['id']),
      code: (json['code'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      requiredPeaks: json['required_peaks'] == null
          ? null
          : _toInt(json['required_peaks']),
    );
  }
}
