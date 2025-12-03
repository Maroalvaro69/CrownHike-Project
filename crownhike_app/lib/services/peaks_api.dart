import 'dart:convert';

import '../models/peak.dart';
import 'api_client.dart';

class PeaksApi {
  /// Lista wszystkich (lub przefiltrowanych) szczytów
  Future<List<Peak>> getAll({
    String? difficulty,
    String? mainTrailColor,
    String? mountainRange,
    String? search,
  }) async {
    final query = <String, String>{};

    if (difficulty != null && difficulty.isNotEmpty) {
      query['difficulty'] = difficulty;
    }
    if (mainTrailColor != null && mainTrailColor.isNotEmpty) {
      query['main_trail_color'] = mainTrailColor;
    }
    if (mountainRange != null && mountainRange.isNotEmpty) {
      query['mountain_range'] = mountainRange;
    }
    if (search != null && search.isNotEmpty) {
      query['search'] = search;
    }

    final res = await ApiClient.I.get(
      '/peaks',
      query: query.isEmpty ? null : query,
    );

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['data'] as List<dynamic>;

    return list.map((e) => Peak.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Szczegóły jednego szczytu
  Future<Peak> getById(int id) async {
    final res = await ApiClient.I.get('/peaks/$id');

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return Peak.fromJson(body['data'] as Map<String, dynamic>);
  }
}
