import 'package:flutter/material.dart';

import 'screens/trails_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/peaks_screen.dart';
import 'screens/peak_details_screen.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'screens/trail_details_screen.dart';
import 'services/downloads_store.dart';
import 'services/hikes_store.dart';
import 'services/token_store.dart'; // Potrzebne do sprawdzania logowania
import 'screens/safety_setup_screen.dart' show SafetySetupScreen;
import 'screens/location_debug_screen.dart';
import 'screens/active_hike_screen.dart';
import 'screens/badges_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DownloadsStore.instance.init();
  await HikesStore.instance.init();

  runApp(const CrownHikeApp());
}

class CrownHikeApp extends StatelessWidget {
  const CrownHikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // GŁÓWNY KOLOR: Głęboki, górski granat
    const seedColor = Color(0xFF1E3A8A);

    return MaterialApp(
      title: 'CrownHike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
          surface: const Color(0xFFF0F9FF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF0F9FF),

        // APP BAR
        appBarTheme: const AppBarTheme(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),

        // KARTY
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        ),

        // POLA TEKSTOWE
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: seedColor.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: seedColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          labelStyle: TextStyle(color: seedColor.withValues(alpha: 0.8)),
        ),

        // NAWIGACJA DOLNA
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFDBEAFE),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontWeight: FontWeight.w700,
                color: seedColor,
              );
            }
            return TextStyle(color: seedColor.withValues(alpha: 0.7));
          }),
        ),

        // PRZYCISKI
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const _HomeShell(),
      routes: {
        LoginScreen.route: (_) => const LoginScreen(),
        RegisterScreen.route: (_) => const RegisterScreen(),
        TrailDetailsScreen.route: (_) => const TrailDetailsScreen(),
        SafetySetupScreen.route: (_) => const SafetySetupScreen(),
        PeakDetailsScreen.route: (_) => const PeakDetailsScreen(),
        ActiveHikeScreen.route: (_) => const ActiveHikeScreen(),
        LocationDebugScreen.route: (_) => const LocationDebugScreen(),
      },
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 1;

  // Status autoryzacji: null = sprawdzam, false = niezalogowany, true = zalogowany
  bool? _isAuthorized;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  /// Sprawdza, czy użytkownik jest zalogowany przy starcie
  Future<void> _checkAuth() async {
    final token = await TokenStore.getToken();

    if (token != null && token.isNotEmpty) {
      // Mamy token -> wpuszczamy do aplikacji
      setState(() => _isAuthorized = true);
    } else {
      // Brak tokena -> wymuszamy logowanie
      setState(() => _isAuthorized = false);
      _goToLogin();
    }
  }

  Future<void> _goToLogin() async {
    // Czekamy chwilę, żeby nie kolidować z budowaniem widgetu
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    // Przechodzimy do logowania
    await Navigator.pushNamed(context, LoginScreen.route);

    // Po powrocie z ekranu logowania sprawdzamy ponownie
    final newToken = await TokenStore.getToken();
    if (newToken != null && newToken.isNotEmpty) {
      setState(() => _isAuthorized = true);
    } else {
      // Użytkownik cofnął z logowania bez sukcesu -> blokujemy dostęp
      setState(() => _isAuthorized = false);
    }
  }

  final _tabs = const [
    TrailsScreen(),
    PeaksScreen(),
    BadgesScreen(),
    DownloadsScreen(),
    ProfileScreen(),
  ];

  final _titles = const [
    'Moje Wędrówki',
    'Szczyty',
    'Odznaki',
    'Pobrane',
    'Profil',
  ];

  @override
  Widget build(BuildContext context) {
    // 1. Ekran ładowania (podczas sprawdzania tokena)
    if (_isAuthorized == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 2. Ekran blokady (jeśli użytkownik nie jest zalogowany i cofnął ekran logowania)
    if (_isAuthorized == false) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
                const SizedBox(height: 24),
                const Text(
                  'Dostęp tylko dla zalogowanych',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aby korzystać z map, szczytów i odznak, musisz posiadać konto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _goToLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('Zaloguj się'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      RegisterScreen.route,
                    ).then((_) => _checkAuth());
                  },
                  child: const Text('Nie masz konta? Zarejestruj się'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Właściwa aplikacja (tylko dla zalogowanych)
    final backgroundColors = [
      const Color(0xFFE0F2FE),
      const Color(0xFFDBEAFE),
      const Color(0xFFD1E4F3),
      const Color(0xFFE3F2FD),
      const Color(0xFFF1F5F9),
    ];

    return Scaffold(
      backgroundColor: backgroundColors[_index],
      appBar: AppBar(title: Text(_titles[_index])),
      body: _tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.hiking), label: 'Wędrówki'),
          NavigationDestination(icon: Icon(Icons.landscape), label: 'Szczyty'),
          NavigationDestination(icon: Icon(Icons.verified), label: 'Odznaki'),
          NavigationDestination(icon: Icon(Icons.download), label: 'Pobrane'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
