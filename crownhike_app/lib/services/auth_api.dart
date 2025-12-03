import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_client.dart';
import 'token_store.dart';

class AuthApi {
  /// Rejestracja użytkownika
  Future<(bool ok, String? error)> register({
    required String name, // <- to będzie username
    required String email,
    required String password,
  }) async {
    final payload = {
      'username': name, // <-- KLUCZ WYMAGANY PRZEZ BACKEND
      'email': email,
      'password': password,
      // można zostawić nadmiarowe – backend i tak je zignoruje:
      'name': name,
      'confirm_password': password,
    };

    final res = await ApiClient.I.post(
      '/users/register',
      body: jsonEncode(payload),
    );

    try {
      final data = jsonDecode(res.body);
      if (res.statusCode == 201 || (data is Map && data['ok'] == true)) {
        return (true, null);
      }
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'HTTP ${res.statusCode}';
      return (false, msg);
    } catch (_) {
      return (false, 'HTTP ${res.statusCode}');
    }
  }

  /// Logowanie → zapis tokena
  Future<(bool ok, String? error)> login({
    required String email,
    required String password,
  }) async {
    final http.Response res = await ApiClient.I.post(
      '/users/login',
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      // dopasuj klucz tokena do swojego backendu (często: "token")
      final token = (data['token'] ?? data['accessToken'])?.toString();
      if (token != null && token.isNotEmpty) {
        await TokenStore.save(token: token, email: email);
        return (true, null);
      }
      return (false, 'Brak tokena w odpowiedzi');
    }

    try {
      final data = jsonDecode(res.body);
      return (false, data['error']?.toString() ?? 'HTTP ${res.statusCode}');
    } catch (_) {
      return (false, 'HTTP ${res.statusCode}');
    }
  }

  Future<void> logout() => TokenStore.clear();
}
