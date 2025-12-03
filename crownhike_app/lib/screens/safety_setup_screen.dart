import 'package:flutter/material.dart';
import '../services/users_api.dart';

class SafetySetupScreen extends StatefulWidget {
  static const route = '/safetySetup';
  const SafetySetupScreen({super.key});

  @override
  State<SafetySetupScreen> createState() => _SafetySetupScreenState();
}

class _SafetySetupScreenState extends State<SafetySetupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Kontakt
  final _phone = TextEditingController();
  final _emgName = TextEditingController();
  final _emgPhone = TextEditingController();

  // Medyczne
  final _bloodType = TextEditingController();
  final _allergies = TextEditingController(); // NOWE
  final _medications = TextEditingController(); // NOWE

  // Inne
  final _todaysPlan = TextEditingController(); // NOWE
  bool _allowLocation = true;

  // Adres
  final _street = TextEditingController();
  final _houseNumber = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final me = await UsersApi().getMe();

      // Kontakt
      _phone.text = (me['phone'] ?? '') as String;
      _emgName.text = (me['emergency_contact_name'] ?? '') as String;
      _emgPhone.text = (me['emergency_contact_phone'] ?? '') as String;

      // Medyczne
      _bloodType.text = (me['blood_type'] ?? '') as String;
      _allergies.text = (me['allergies'] ?? '') as String; // NOWE
      _medications.text = (me['medications'] ?? '') as String; // NOWE

      // Inne
      _todaysPlan.text = (me['todays_plan'] ?? '') as String; // NOWE
      _allowLocation = (me['allow_location_sharing'] ?? 1) == 1;

      // Adres
      _street.text = (me['address_street'] ?? '') as String;
      _houseNumber.text = (me['address_house_number'] ?? '') as String;
      _postalCode.text = (me['address_postal_code'] ?? '') as String;
      _city.text = (me['address_city'] ?? '') as String;
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _emgName.dispose();
    _emgPhone.dispose();
    _bloodType.dispose();
    _allergies.dispose();
    _medications.dispose();
    _todaysPlan.dispose();
    _street.dispose();
    _houseNumber.dispose();
    _postalCode.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await UsersApi().updateMe(
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        emergencyContactName: _emgName.text.trim().isEmpty
            ? null
            : _emgName.text.trim(),
        emergencyContactPhone: _emgPhone.text.trim().isEmpty
            ? null
            : _emgPhone.text.trim(),

        bloodType: _bloodType.text.trim().isEmpty
            ? null
            : _bloodType.text.trim().toUpperCase(),
        allergies: _allergies.text.trim().isEmpty
            ? null
            : _allergies.text.trim(),
        medications: _medications.text.trim().isEmpty
            ? null
            : _medications.text.trim(),
        todaysPlan: _todaysPlan.text.trim().isEmpty
            ? null
            : _todaysPlan.text.trim(),

        allowLocationSharing: _allowLocation,

        addressStreet: _street.text.trim().isEmpty ? null : _street.text.trim(),
        addressHouseNumber: _houseNumber.text.trim().isEmpty
            ? null
            : _houseNumber.text.trim(),
        addressPostalCode: _postalCode.text.trim().isEmpty
            ? null
            : _postalCode.text.trim(),
        addressCity: _city.text.trim().isEmpty ? null : _city.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dane bezpieczeństwa zapisane ✔')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bezpieczeństwo (krok 2/2)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Uzupełnij Kartę Bezpieczeństwa.\n'
                'Te dane mogą uratować Ci życie w górach.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),

              _SectionHeader('Kontakt'),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Twój telefon',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emgName,
                decoration: const InputDecoration(
                  labelText: 'Kontakt ICE (Imię)',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emgPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Kontakt ICE (Telefon)',
                  prefixIcon: Icon(Icons.phone_in_talk),
                ),
              ),

              const SizedBox(height: 20),
              _SectionHeader('Medyczne'),
              TextFormField(
                controller: _bloodType,
                decoration: const InputDecoration(
                  labelText: 'Grupa krwi (np. A Rh+)',
                  prefixIcon: Icon(Icons.bloodtype),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _allergies,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Alergie (np. jad pszczeli, penicylina)',
                  prefixIcon: Icon(Icons.warning_amber),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _medications,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Przyjmowane leki (np. insulina)',
                  prefixIcon: Icon(Icons.medication),
                ),
              ),

              const SizedBox(height: 20),
              _SectionHeader('Dodatkowe info'),
              TextFormField(
                controller: _todaysPlan,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Stałe uwagi / Plan (opcjonalne)',
                  prefixIcon: Icon(Icons.note),
                ),
              ),

              const SizedBox(height: 20),
              _SectionHeader('Adres zamieszkania'),
              TextFormField(
                controller: _street,
                decoration: const InputDecoration(
                  labelText: 'Ulica',
                  prefixIcon: Icon(Icons.home),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _houseNumber,
                decoration: const InputDecoration(
                  labelText: 'Nr domu / mieszkania',
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _postalCode,
                decoration: const InputDecoration(
                  labelText: 'Kod pocztowy',
                  prefixIcon: Icon(Icons.local_post_office),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(
                  labelText: 'Miasto',
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),

              const SizedBox(height: 20),
              SwitchListTile(
                value: _allowLocation,
                onChanged: (v) => setState(() => _allowLocation = v),
                title: const Text('Udostępniaj lokalizację służbom'),
              ),
              const SizedBox(height: 20),

              FilledButton(onPressed: _continue, child: const Text('Zapisz')),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Pominę teraz'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
