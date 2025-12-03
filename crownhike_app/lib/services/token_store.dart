import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const _kToken = 'auth_token';
  static const _kEmail = 'auth_email';

  static Future<void> save({required String token, String? email}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, token);
    if (email != null) await sp.setString(_kEmail, email);
  }

  static Future<String?> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kToken);
  }

  static Future<String?> getEmail() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kEmail);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
    await sp.remove(_kEmail);
  }
}
