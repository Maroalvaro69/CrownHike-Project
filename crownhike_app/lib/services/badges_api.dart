import 'dart:convert';

import '../models/badge.dart';
import 'api_client.dart';

class BadgesApi {
  /// Lista wszystkich dostępnych odznak (PUBLICZNA)
  Future<List<Badge>> getAllBadges() async {
    final res = await ApiClient.I.get('/api/badges');

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['data'] as List<dynamic>;

    return list.map((e) => Badge.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Lista odznak ZDOBYTYCH przez ZALOGOWANEGO użytkownika
  Future<List<Badge>> getMyBadges() async {
    // UŻYWAMY getAuth – wtedy dołącza się Bearer <token>
    final res = await ApiClient.I.getAuth('/api/badges/user');

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['data'] as List<dynamic>;

    return list.map((e) => Badge.fromJson(e as Map<String, dynamic>)).toList();
  }
}
