import 'dart:convert';

/// Pojedyncza wędrówka użytkownika po konkretnym szlaku.
/// Na razie przechowujemy ją tylko lokalnie (np. w SharedPreferences).
class HikeSession {
  /// Unikalne ID sesji (np. UUID jako String).
  final String id;

  /// ID szlaku z backendu (trails.id)
  final int trailId;

  /// Nazwa szlaku w momencie wędrówki (żeby było czytelnie na liście).
  final String trailName;

  /// Czas startu wędrówki (lokalny).
  final DateTime startTime;

  /// Czas trwania w sekundach.
  final int durationSeconds;

  /// Przebyty dystans w metrach.
  final double distanceMeters;

  HikeSession({
    required this.id,
    required this.trailId,
    required this.trailName,
    required this.startTime,
    required this.durationSeconds,
    required this.distanceMeters,
  });

  /// Dystans w kilometrach – pomocniczo dla UI.
  double get distanceKm => distanceMeters / 1000.0;

  /// Czas trwania jako Duration – pomocniczo dla UI.
  Duration get duration => Duration(seconds: durationSeconds);

  Map<String, dynamic> toJson() => {
    'id': id,
    'trailId': trailId,
    'trailName': trailName,
    'startTime': startTime.toIso8601String(),
    'durationSeconds': durationSeconds,
    'distanceMeters': distanceMeters,
  };

  factory HikeSession.fromJson(Map<String, dynamic> j) => HikeSession(
    id: j['id'] as String,
    trailId: (j['trailId'] as num).toInt(),
    trailName: (j['trailName'] ?? '') as String,
    startTime: DateTime.parse(j['startTime'] as String),
    durationSeconds: (j['durationSeconds'] as num).toInt(),
    distanceMeters: (j['distanceMeters'] as num).toDouble(),
  );

  /// Helpers do zapisu/odczytu listy w jednym Stringu (np. w SharedPreferences)
  static String encodeList(List<HikeSession> sessions) {
    final list = sessions.map((s) => s.toJson()).toList();
    return jsonEncode(list);
  }

  static List<HikeSession> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => HikeSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
