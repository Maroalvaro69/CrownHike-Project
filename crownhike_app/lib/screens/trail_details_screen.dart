import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../services/location_service.dart';
import '../services/hikes_store.dart';
import '../models/hike_session.dart';
import '../services/token_store.dart';
import '../auth/login_screen.dart';

const _uuid = Uuid();

class TrailDetailsScreen extends StatefulWidget {
  static const String route = '/trailDetails';

  const TrailDetailsScreen({super.key});

  @override
  State<TrailDetailsScreen> createState() => _TrailDetailsScreenState();
}

class _TrailDetailsScreenState extends State<TrailDetailsScreen> {
  bool _starting = false; // czy trwa pobieranie pozycji startowej
  bool _tracking = false; // czy wędrówka jest aktywna
  DateTime? _startTime;

  double? _startLat;
  double? _startLng;
  double? _startAlt;

  // bieżący stan śledzenia
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  double _distanceMeters = 0.0;
  double? _lastLat;
  double? _lastLng;

  String? _error;

  // --- logika startu wędrówki ---
  Future<void> _startHike() async {
    // 1. Sprawdź, czy użytkownik jest zalogowany
    final email = await TokenStore.getEmail();
    if (!mounted) return;

    if (email == null) {
      // user niezalogowany – pokaż dialog i ewentualnie przejdź do logowania
      final goLogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logowanie wymagane'),
          content: const Text(
            'Aby rozpocząć wędrówkę i zapisać ją w historii, '
            'musisz być zalogowany.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Zaloguj'),
            ),
          ],
        ),
      );

      if (goLogin == true) {
        await Navigator.pushNamed(context, LoginScreen.route);
      }
      // i tak nie startujemy wędrówki – user musi kliknąć raz jeszcze
      return;
    }

    // 2. Dalej zostaje Twoja dotychczasowa logika startu
    setState(() {
      _starting = true;
      _error = null;
    });

    final pos = await LocationService.instance.getCurrentPosition();

    if (!mounted) return;

    if (pos == null) {
      setState(() {
        _starting = false;
        _error =
            'Nie udało się pobrać lokalizacji.\n'
            'Sprawdź uprawnienia i włącz usługi lokalizacji.';
      });
      return;
    }

    _timer?.cancel();

    final now = DateTime.now();

    setState(() {
      _starting = false;
      _tracking = true;
      _startTime = now;

      _startLat = pos.latitude;
      _startLng = pos.longitude;
      _startAlt = pos.altitude;

      _lastLat = pos.latitude;
      _lastLng = pos.longitude;

      _elapsed = Duration.zero;
      _distanceMeters = 0.0;
    });

    // co 5 sekund dopytujemy o pozycję
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _onTick();
    });
  }

  // --- pojedynczy „krok” trackingu ---
  Future<void> _onTick() async {
    if (!_tracking || _startTime == null) return;

    final pos = await LocationService.instance.getCurrentPosition();
    if (!mounted || pos == null) return;

    final now = DateTime.now();

    double additional = 0.0;
    if (_lastLat != null && _lastLng != null) {
      additional = _distanceMetersBetween(
        _lastLat!,
        _lastLng!,
        pos.latitude,
        pos.longitude,
      );
    }

    setState(() {
      _elapsed = now.difference(_startTime!);
      _distanceMeters += additional;
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
    });
  }

  // --- zatrzymanie wędrówki + zapis sesji ---
  Future<void> _stopHike() async {
    _timer?.cancel();

    if (_tracking && _startTime != null) {
      // pobierz dane szlaku z argumentów routingu
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      final trailId = (args?['id'] as int?) ?? 0;
      final trailName = (args?['name'] as String?) ?? 'Szlak';

      final session = HikeSession(
        id: _uuid.v4(),
        trailId: trailId,
        trailName: trailName,
        startTime: _startTime!,
        durationSeconds: _elapsed.inSeconds,
        distanceMeters: _distanceMeters,
      );

      await HikesStore.instance.addSession(session);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wędrówka zapisana w historii')),
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _tracking = false;
      _startTime = null;
      _startLat = null;
      _startLng = null;
      _startAlt = null;

      _elapsed = Duration.zero;
      _distanceMeters = 0.0;
      _lastLat = null;
      _lastLng = null;

      _error = null;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- pomocnicze: dystans Haversine ---
  double _distanceMetersBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // w metrach
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * math.pi / 180.0;

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(d.inHours);
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final name = args?['name'] as String? ?? 'Szlak';
    final region = args?['region'] as String?;
    final difficulty = args?['difficulty'] as String? ?? 'moderate';
    final distanceKm = (args?['distanceKm'] as double?) ?? 0.0;
    final ascent = (args?['ascent'] as int?) ?? 0;
    final description = args?['description'] as String?;

    final chips = <String>[];
    if (region != null && region.isNotEmpty) chips.add(region);
    chips.add(difficulty);
    if (distanceKm > 0) chips.add('${distanceKm.toStringAsFixed(1)} km');
    if (ascent > 0) chips.add('↑ $ascent m');

    final traveledKm = _distanceMeters / 1000.0;

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chips.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: chips.map((c) => Chip(label: Text(c))).toList(),
              ),
            const SizedBox(height: 16),
            Text('Opis', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              (description != null && description.isNotEmpty)
                  ? description
                  : 'Brak opisu dla tego szlaku.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // --- Sekcja przycisku wędrówki ---
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],

            if (!_tracking)
              ElevatedButton.icon(
                onPressed: _starting ? null : _startHike,
                icon: _starting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  _starting ? 'Rozpoczynanie…' : 'Rozpocznij wędrówkę',
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _stopHike,
                icon: const Icon(Icons.stop),
                label: const Text('Zakończ wędrówkę'),
              ),

            const SizedBox(height: 16),

            if (_tracking && _startTime != null) ...[
              Text(
                'Aktywna wędrówka',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('Start: ${_startTime!.toLocal()}'),
              if (_startLat != null && _startLng != null)
                Text(
                  'Pozycja startowa: ${_startLat!.toStringAsFixed(5)}, ${_startLng!.toStringAsFixed(5)}',
                ),
              if (_startAlt != null)
                Text('Wysokość startowa: ${_startAlt!.toStringAsFixed(1)} m'),
              const SizedBox(height: 8),
              Text('Czas trwania: ${_formatDuration(_elapsed)}'),
              Text('Przebyty dystans: ${traveledKm.toStringAsFixed(2)} km'),
            ],
          ],
        ),
      ),
    );
  }
}
