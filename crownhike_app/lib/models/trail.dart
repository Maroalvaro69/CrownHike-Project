class Trail {
  final int id;
  final String name;
  final String? region;
  final String difficulty;
  final double? lengthKm;
  final int? elevationGain;
  final int? durationMin;
  final String? description;

  Trail({
    required this.id,
    required this.name,
    required this.difficulty,
    this.region,
    this.lengthKm,
    this.elevationGain,
    this.durationMin,
    this.description,
  });

  // --- helpers: bezpieczne parsowanie liczb z num/String ---
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final d = double.tryParse(v.replaceAll(',', '.'));
      return d?.round();
    }
    return null;
  }

  factory Trail.fromJson(Map<String, dynamic> j) => Trail(
    id: _toInt(j['id']) ?? 0,
    name: (j['name'] ?? '') as String,
    region: j['region'] as String?,
    difficulty: (j['difficulty'] ?? 'moderate') as String,
    lengthKm: _toDouble(j['length_km']),
    elevationGain: _toInt(j['elevation_gain']),
    durationMin: _toInt(j['duration_min']),
    description: j['description'] as String?,
  );
}
