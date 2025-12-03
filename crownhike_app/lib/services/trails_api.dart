import 'dart:convert';
import '../models/trail.dart';
import 'api_client.dart';

class TrailsApi {
  Future<Trail> getById(int id) async {
    final res = await ApiClient.I.get('/trails/$id');
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    return Trail.fromJson(data['data']);
  }
}
