import 'package:flutter/foundation.dart';

class AuthState extends ChangeNotifier {
  static final AuthState instance = AuthState._();
  AuthState._();

  bool _isLoggedIn = false;
  String? _displayName;

  bool get isLoggedIn => _isLoggedIn;
  String? get displayName => _displayName;

  void login({required String email}) {
    _isLoggedIn = true;
    _displayName = email.split('@').first;
    notifyListeners();
  }

  void register({required String name, required String email}) {
    _isLoggedIn = true;
    _displayName = name.isNotEmpty ? name : email.split('@').first;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _displayName = null;
    notifyListeners();
  }
}
