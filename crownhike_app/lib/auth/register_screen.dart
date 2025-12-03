import 'package:flutter/material.dart';
import '../services/auth_api.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  static const route = '/register';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    final authApi = AuthApi();

    // 1. Rejestracja
    final (ok, err) = await authApi.register(
      name: name,
      email: email,
      password: password,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = ok ? null : err;
    });

    if (!ok) {
      // rejestracja nieudana
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_error ?? 'Rejestracja nieudana')));
      return;
    }

    // 2. AUTOMATYCZNE LOGOWANIE po udanej rejestracji
    final (loginOk, loginErr) = await authApi.login(
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (!loginOk) {
      // Konto utworzone, ale auto-login się wywalił – komunikat i powrót do logowania
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Konto utworzone, ale nie udało się zalogować: '
            '${loginErr ?? 'spróbuj zalogować się ręcznie.'}',
          ),
        ),
      );
      Navigator.pop(context); // wróć do ekranu logowania
      return;
    }

    // 3. Jeśli auto-logowanie się udało, token jest już zapisany w TokenStore
    // 3. Jeśli auto-logowanie się udało, token jest już zapisany.
    // Pytamy o konfigurację bezpieczeństwa.
    final goNow = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Konto utworzone'),
        content: const Text(
          'Czy chcesz teraz uzupełnić dane bezpieczeństwa (krok 2/2)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Później'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Tak'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    // Logika nawigacji:
    if (goNow == true) {
      // 1. Idziemy do SafetySetup i CZEKAMY (await) aż użytkownik skończy
      await Navigator.pushNamed(context, '/safetySetup');
    }

    if (!mounted) return;

    // 2. Niezależnie czy użytkownik wypełnił dane czy kliknął "Później":
    // Czyścimy historię widoków (żeby strzałka "Wstecz" nie wracała do rejestracji)
    // I przechodzimy do głównego ekranu aplikacji ('/').
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/', // Główny route (HomeShell)
      (route) => false, // Usuń wszystkie poprzednie ekrany z pamięci
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF), // Blue 50
      appBar: AppBar(title: const Text('Rejestracja')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Imię',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Podaj imię';
                    }

                    final nameRegExp = RegExp(
                      r'^[a-zA-ZąćęłńóśźżĄĆĘŁŃÓŚŹŻ ]+$',
                    );

                    if (!nameRegExp.hasMatch(value)) {
                      return 'Imię nie może zawierać cyfr ani znaków specjalnych';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Podaj adres e-mail';
                    }
                    if (!value.contains('@')) {
                      return 'Niepoprawny format e-maila';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Hasło',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Podaj hasło';
                    if (value.length < 6) {
                      return 'Hasło musi mieć min. 6 znaków';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _confirmController,
                  obscureText: !_isConfirmVisible,
                  decoration: InputDecoration(
                    labelText: 'Potwierdź hasło',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () => _isConfirmVisible = !_isConfirmVisible,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Potwierdź hasło';
                    }
                    if (value != _passwordController.text) {
                      return 'Hasła nie są takie same';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Zarejestruj się'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
