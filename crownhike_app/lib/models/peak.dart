// lib/models/peak.dart

class Peak {
  final int id;
  final String name;
  final String region;
  final int? elevationM; // może być null
  final double? lat; // może być null
  final double? lng; // może być null
  final String? description;

  // NOWE POLA:
  final String? difficulty; // EASY / MODERATE / HARD / EXPERT
  final String? mainTrailColor; // RED / BLUE / GREEN / YELLOW / BLACK / MIXED

  Peak({
    required this.id,
    required this.name,
    required this.region,
    this.elevationM,
    this.lat,
    this.lng,
    this.description,
    this.difficulty,
    this.mainTrailColor,
  });

  // Pomocnicze konwertery, które obsługują numery i stringi
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory Peak.fromJson(Map<String, dynamic> json) {
    return Peak(
      id: _toInt(json['id']) ?? 0,
      name: (json['name'] ?? '') as String,
      region: (json['region'] ?? '') as String,
      // backend może zwrócić elevation_m ALBO height_m
      elevationM: _toInt(json['elevation_m'] ?? json['height_m']),
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
      description: json['description'] as String?,
      difficulty: json['difficulty'] as String?, // <-- NOWE
      mainTrailColor: json['main_trail_color'] as String?, // <-- NOWE
    );
  }
}
