import 'package:flutter/material.dart';
import '../services/token_store.dart';
import '../auth/login_screen.dart';
import '../services/users_api.dart';
import 'safety_setup_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _email;
  Map<String, dynamic>? _me;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = await TokenStore.getEmail();
    Map<String, dynamic>? me;
    try {
      if (email != null) {
        me = await UsersApi().getMe();
      }
    } catch (_) {
      me = null;
    }
    if (!mounted) return;
    setState(() {
      _email = email;
      _me = me;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await TokenStore.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      LoginScreen.route,
      (route) => false,
    );
  }

  // --- OBSŁUGA ZMIANY HASŁA ---
  Future<void> _showChangePasswordDialog() async {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zmiana hasła'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Stare hasło'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nowe hasło (min. 6 znaków)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await UsersApi().changePassword(
                  oldPassword: oldPassCtrl.text,
                  newPassword: newPassCtrl.text,
                );
                if (!mounted) return;
                Navigator.pop(ctx); // Zamknij dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hasło zostało zmienione 🔐')),
                );
              } catch (e) {
                // Usuwamy "Exception: " z komunikatu błędu dla estetyki
                final msg = e.toString().replaceAll("Exception:", "").trim();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Błąd: $msg'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Zmień'),
          ),
        ],
      ),
    );
  }

  // --- OBSŁUGA USUWANIA KONTA ---
  Future<void> _showDeleteAccountDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć konto?', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Tej operacji nie można cofnąć.\n'
          'Utracisz wszystkie zapisane trasy, odznaki i dane profilu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń na zawsze'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await UsersApi().deleteAccount();
        await TokenStore.clear(); // Czyścimy token z telefonu
        if (!mounted) return;

        // Wyrzucamy na ekran główny
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konto zostało usunięte 👋')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd usuwania: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final loggedIn = _email != null;

    if (!loggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text('Zaloguj się, aby zobaczyć profil'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, LoginScreen.route),
              child: const Text('Zaloguj się'),
            ),
          ],
        ),
      );
    }

    // Wyciągamy inicjał do awatara
    final letter = _email!.isNotEmpty ? _email![0].toUpperCase() : '?';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // 1. NAGŁÓWEK PROFILU (Awatar + Email)
          CircleAvatar(
            radius: 45,
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(
              letter,
              style: const TextStyle(fontSize: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _email!,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[900],
            ),
          ),
          const Text(
            'Użytkownik CrownHike',
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 30),

          // 2. KARTA BEZPIECZEŃSTWA (ICE)
          _SafetyCard(
            me: _me,
            onEdit: () async {
              await Navigator.pushNamed(context, SafetySetupScreen.route);
              _load(); // Odśwież dane po powrocie z edycji
            },
          ),

          const SizedBox(height: 30),

          // 3. SEKCJA: ZARZĄDZANIE KONTEM
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ustawienia konta',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(height: 10),

          ListTile(
            leading: const Icon(Icons.password, color: Colors.blueGrey),
            title: const Text('Zmień hasło'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showChangePasswordDialog,
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text(
              'Usuń konto',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: _showDeleteAccountDialog,
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          const SizedBox(height: 30),

          // 4. PRZYCISK WYLOGUJ
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Wyloguj się'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                side: BorderSide(color: Colors.grey.shade400),
                foregroundColor: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// --- POMOCNICZE WIDGETY ---

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.me, required this.onEdit});

  final Map<String, dynamic>? me;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    String val(String key) => (me?[key] ?? '').toString();

    final phone = val('phone');
    final iceName = val('emergency_contact_name');
    final icePhone = val('emergency_contact_phone');
    final blood = val('blood_type');
    final allergies = val('allergies');
    final meds = val('medications');

    final street = val('address_street');
    final city = val('address_city');
    final hasAddress = street.isNotEmpty || city.isNotEmpty;
    final fullAddress = [
      street,
      val('address_house_number'),
      val('address_postal_code'),
      city,
    ].where((s) => s.isNotEmpty).join(', ');

    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.medical_information, color: Colors.red.shade700),
                const SizedBox(width: 10),
                Text(
                  'Karta ICE / Bezpieczeństwo',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red.shade900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: onEdit,
                  tooltip: 'Edytuj dane',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (phone.isNotEmpty)
                  _InfoRow(Icons.phone_android, 'Twój telefon', phone),
                if (iceName.isNotEmpty || icePhone.isNotEmpty) ...[
                  const Divider(),
                  _InfoRow(
                    Icons.contact_phone,
                    'Kontakt ICE',
                    '$iceName\n$icePhone',
                  ),
                ],
                if (blood.isNotEmpty ||
                    allergies.isNotEmpty ||
                    meds.isNotEmpty) ...[
                  const Divider(),
                  if (blood.isNotEmpty)
                    _InfoRow(
                      Icons.bloodtype,
                      'Grupa krwi',
                      blood,
                      isBold: true,
                    ),
                  if (allergies.isNotEmpty)
                    _InfoRow(
                      Icons.warning_amber,
                      'Alergie',
                      allergies,
                      color: Colors.orange.shade900,
                    ),
                  if (meds.isNotEmpty) _InfoRow(Icons.medication, 'Leki', meds),
                ],
                if (hasAddress) ...[
                  const Divider(),
                  _InfoRow(Icons.home, 'Adres', fullAddress),
                ],
                if (phone.isEmpty && !hasAddress && blood.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Brak danych bezpieczeństwa.\nKliknij edytuj, aby uzupełnić.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isBold;
  final Color? color;

  const _InfoRow(
    this.icon,
    this.label,
    this.value, {
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    color: color ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
