import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'token_store.dart';

/// Klient API do komunikacji z backendem CrownHike.
///
/// Automatycznie wybiera odpowiedni adres:
/// - Web/Chrome → http://localhost:3000
/// - Emulator Androida → http://10.0.2.2:3000
/// - iOS Simulator / urządzenia lokalne → http://localhost:3000
class ApiClient {
  ApiClient._();
  static final ApiClient I = ApiClient._();

  String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000'; // Web/Chrome
    } else {
      return 'http://10.0.2.2:3000'; // Android emulator
    }
  }

  /// Wykonuje zapytanie GET
  Future<http.Response> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return http.get(uri, headers: {'Accept': 'application/json'});
  }

  /// Wykonuje zapytanie POST (opcjonalnie z JSON body)
  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final h = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (headers != null) ...headers,
    };
    return http.post(uri, headers: h, body: body);
  }

  Future<http.Response> getAuth(
    String path, {
    Map<String, String>? query,
  }) async {
    final token = await TokenStore.getToken();
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  Future<http.Response> putAuth(String path, {Object? body}) async {
    final token = await TokenStore.getToken();
    final uri = Uri.parse('$baseUrl$path');
    return http.put(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: body,
    );
  }

  Future<http.Response> postAuth(String path, {Object? body}) async {
    final token = await TokenStore.getToken();
    final uri = Uri.parse('$baseUrl$path');

    return http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: body,
    );
  }

  Future<http.Response> deleteAuth(String path) async {
    final token = await TokenStore.getToken();
    final uri = Uri.parse('$baseUrl$path');
    return http.delete(
      uri,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }
}
