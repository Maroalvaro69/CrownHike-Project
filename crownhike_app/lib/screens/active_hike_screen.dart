// lib/screens/active_hike_screen.dart
import 'dart:async';
import 'dart:convert'; // Potrzebne do jsonDecode

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance, LengthUnit;

import '../models/peak.dart';
import '../services/location_service.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart'
    as fmctp;

import '../services/api_client.dart';

class ActiveHikeScreen extends StatefulWidget {
  static const route = '/activeHike';

  const ActiveHikeScreen({super.key});

  @override
  State<ActiveHikeScreen> createState() => _ActiveHikeScreenState();
}

class _ActiveHikeScreenState extends State<ActiveHikeScreen> {
  static const double _movementThresholdMeters = 10.0;

  final _locationService = LocationService.instance;
  final MapController _mapController = MapController();

  Peak? _peak;
  LatLng? _peakLatLng;

  bool _loading = true;
  String? _error;

  // NOWE: Czy trwa pobieranie trasy?
  bool _loadingRoute = false;
  // NOWE: Lista punktów wyznaczonego szlaku (Planowana trasa)
  List<LatLng> _routePath = [];

  bool _paused = false;
  // Lista punktów faktycznego śladu (Gdzie użytkownik przeszedł)
  final List<LatLng> _track = [];

  Timer? _locationTimer;
  Timer? _uiTimer;

  DateTime? _hikeStartAt;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStartAt;
  DateTime? _lastMovementAt;
  bool _safetyDialogShown = false;

  double? get _straightDistanceKm {
    if (_track.isEmpty || _peakLatLng == null) return null;
    const distance = Distance();
    final km = distance.as(LengthUnit.Kilometer, _track.first, _peakLatLng!);
    return km;
  }

  double get _trackDistanceKm {
    if (_track.length < 2) return 0.0;
    const distance = Distance();
    double sum = 0.0;
    for (var i = 1; i < _track.length; i++) {
      sum += distance.as(LengthUnit.Kilometer, _track[i - 1], _track[i]);
    }
    return sum;
  }

  Duration get _elapsed {
    if (_hikeStartAt == null) return Duration.zero;
    var base = DateTime.now().difference(_hikeStartAt!);
    if (_pauseStartAt != null) {
      base -= DateTime.now().difference(_pauseStartAt!);
    }
    return base - _pausedDuration;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_peak != null) return;

    final args = ModalRoute.of(context)!.settings.arguments;
    _peak = args as Peak;

    if (_peak!.lat != null && _peak!.lng != null) {
      _peakLatLng = LatLng(_peak!.lat!, _peak!.lng!);
    }

    _startTracking();
  }

  Future<void> _startTracking() async {
    final ok = await _locationService.ensurePermission();
    if (!ok) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Brak dostępu do lokalizacji. Włącz lokalizację w ustawieniach, aby śledzić wędrówkę.';
      });
      return;
    }

    _hikeStartAt = DateTime.now();
    _lastMovementAt = _hikeStartAt;

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });

    // --- TRYB TESTOWY START ---
    // Zamiast prawdziwego GPS (który jest w domu), udajemy, że jesteśmy w Palenicy Białczańskiej.
    // Dzięki temu dystans będzie mały (ok. 10 km) i trasa się wyznaczy.

    // Współrzędne parkingu Palenica Białczańska
    const fakeLat = 49.2560;
    const fakeLng = 20.1020;

    // Dodajemy fałszywy punkt startowy
    _track.add(const LatLng(fakeLat, fakeLng));
    _lastMovementAt = DateTime.now();

    // Pobieramy trasę dla tej fałszywej lokalizacji
    _fetchRoute(fakeLat, fakeLng);

    // --- TRYB TESTOWY KONIEC ---

    /* ORYGINALNY KOD (Odkomentuj, gdy będziesz już w górach):
    final firstPos = await _locationService.getCurrentPosition();
    if (firstPos != null) {
      _track.add(LatLng(firstPos.latitude, firstPos.longitude));
      _lastMovementAt = DateTime.now();
      _fetchRoute(firstPos.latitude, firstPos.longitude);
    }
    */

    if (!mounted) return;
    setState(() {
      _loading = false;
    });

    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_paused) {
        _checkSafetyTimeout();
        //_updatePosition();
      }
    });
  }

  // NOWE: Funkcja pobierająca trasę z Twojego Backendu (który pyta ORS)
  Future<void> _fetchRoute(double startLat, double startLng) async {
    if (_peak == null) return;

    // Tylko jeśli jeszcze nie mamy trasy
    if (_routePath.isNotEmpty) return;

    setState(() => _loadingRoute = true);

    try {
      debugPrint('[ActiveHike] Fetching route for peak ${_peak!.id}...');
      final res = await ApiClient.I.getAuth(
        '/peaks/${_peak!.id}/route?lat=$startLat&lng=$startLng',
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final data = json['data'];
        final List<dynamic> pointsRaw = data['path'];

        final List<LatLng> loadedPath = pointsRaw
            .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
            .toList();

        debugPrint('[ActiveHike] Route loaded: ${loadedPath.length} points');

        if (mounted) {
          setState(() {
            _routePath = loadedPath;
          });

          // Opcjonalnie: dopasuj kamerę, żeby pokazać całą trasę
          if (loadedPath.isNotEmpty) {
            final bounds = LatLngBounds.fromPoints(loadedPath);
            // Dodajemy margines, żeby trasa nie dotykała krawędzi ekranu
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(50),
              ),
            );
          }
        }
      } else {
        debugPrint('[ActiveHike] Route error: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('[ActiveHike] Route exception: $e');
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  Future<void> _updatePosition() async {
    final pos = await _locationService.getCurrentPosition();
    if (!mounted || pos == null) return;

    final newPoint = LatLng(pos.latitude, pos.longitude);

    if (_track.isEmpty) {
      setState(() {
        _track.add(newPoint);
        _lastMovementAt = DateTime.now();
        _safetyDialogShown = false;
      });
      return;
    }

    const distanceCalc = Distance();
    final movedMeters = distanceCalc.as(
      LengthUnit.Meter,
      _track.last,
      newPoint,
    );

    if (movedMeters >= _movementThresholdMeters) {
      setState(() {
        _track.add(newPoint);
        _lastMovementAt = DateTime.now();
        _safetyDialogShown = false;
      });
    }
  }

  Future<void> _checkSafetyTimeout() async {
    if (_safetyDialogShown || _paused) return;
    if (_lastMovementAt == null) return;

    final diff = DateTime.now().difference(_lastMovementAt!);
    if (diff < const Duration(minutes: 5)) return;

    _safetyDialogShown = true;
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Czy wszystko w porządku?'),
        content: const Text(
          'Od 5 minut nie widać ruchu w Twojej lokalizacji.\n\n'
          'Jeśli wszystko jest OK, potwierdź poniżej.\n'
          'Jeśli potrzebujesz pomocy, wybierz odpowiednią opcję.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(false);
            },
            child: const Text(
              'Potrzebuję pomocy',
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Wszystko OK'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() {
        _lastMovementAt = DateTime.now();
        _safetyDialogShown = false;
      });
    } else {
      _triggerEmergency();
    }
  }

  Future<void> _triggerEmergency() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ALARM: wysłano zgłoszenie ratunkowe.'),
        duration: Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _uiTimer?.cancel();
    super.dispose();
  }

  void _finishHike() async {
    if (_hikeStartAt == null || _track.isEmpty || _peak == null) {
      _locationTimer?.cancel();
      _uiTimer?.cancel();
      Navigator.of(context).pop();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zakończyć wędrówkę?'),
        content: const Text(
          'Czy na pewno chcesz zakończyć wędrówkę i zapisać ją w swoim profilu?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Zakończ i zapisz'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _locationTimer?.cancel();
    _uiTimer?.cancel();

    final peak = _peak!;
    final elapsed = _elapsed;
    final straightDistance = _straightDistanceKm;
    final trackDistance = _trackDistanceKm;

    final payload = {
      'peakId': peak.id,
      'startedAt': _hikeStartAt!.toUtc().toIso8601String(),
      'durationSec': elapsed.inSeconds,
      'trackDistanceKm': trackDistance,
      'straightDistanceKm': straightDistance,
      'track': _track
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await ApiClient.I.postAuth(
        '/hikes',
        body: jsonEncode(payload),
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wędrówka została zapisana na serwerze.'),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Błąd zapisu wędrówki (${res.statusCode}): ${res.body}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zapisać wędrówki: $e')),
      );
    }
  }

  void _togglePause() {
    setState(() {
      if (!_paused) {
        _paused = true;
        _pauseStartAt = DateTime.now();
      } else {
        if (_pauseStartAt != null) {
          _pausedDuration += DateTime.now().difference(_pauseStartAt!);
        }
        _pauseStartAt = null;
        _paused = false;
        _lastMovementAt = DateTime.now();
        _safetyDialogShown = false;
      }
    });
  }

  void _zoomIn() {
    final camera = _mapController.camera;
    final newZoom = (camera.zoom + 1).clamp(3.0, 18.0);
    _mapController.move(camera.center, newZoom);
  }

  void _zoomOut() {
    final camera = _mapController.camera;
    final newZoom = (camera.zoom - 1).clamp(3.0, 18.0);
    _mapController.move(camera.center, newZoom);
  }

  void _goToMyLocation() {
    if (_track.isEmpty) return;
    final camera = _mapController.camera;
    _mapController.move(_track.last, camera.zoom);
  }

  void _goToPeak() {
    if (_peakLatLng == null) return;
    final camera = _mapController.camera;
    _mapController.move(_peakLatLng!, camera.zoom);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wędrówka')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    _loading = true;
                    _error = null;
                    setState(() {});
                    _startTracking();
                  },
                  child: const Text('Spróbuj ponownie'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final peak = _peak!;
    final peakLatLng = _peakLatLng;
    final mapCenter =
        peakLatLng ??
        (_track.isNotEmpty ? _track.first : const LatLng(49.0, 20.0));
    final straightDistance = _straightDistanceKm;
    final trackDistance = _trackDistanceKm;
    final elapsed = _elapsed;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Wędrówka: ${peak.name}'),
        backgroundColor: const Color(0xFF172554),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(peak.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            if (peak.elevationM != null)
              Text(
                '${peak.elevationM} m n.p.m.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 4),
            Text(
              'Czas wędrówki: ${_formatDuration(elapsed)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Dystans po śladzie: ${trackDistance.toStringAsFixed(2)} km',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (straightDistance != null) ...[
              const SizedBox(height: 4),
              Text(
                'Dystans w linii prostej: ${straightDistance.toStringAsFixed(1)} km',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],

            // STATUS POBIERANIA TRASY
            if (_loadingRoute)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: const [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Wyznaczanie szlaku...",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // MAPA
            SizedBox(
              height: 360,
              child: Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: mapCenter,
                        initialZoom: 8.5,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'com.example.crownhike_app',
                          tileProvider: fmctp.CancellableNetworkTileProvider(),
                        ),

                        // 1. WARSTWA: PLANOWANA TRASA (Szlak - Niebieski, przezroczysty)
                        if (_routePath.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePath,
                                strokeWidth: 6.0,
                                color: Colors.blue.withValues(
                                  alpha: 0.6,
                                ), // Trasa "pod spodem"
                              ),
                            ],
                          ),

                        // 2. WARSTWA: TWÓJ ŚLAD (Realna droga - Czerwony, ostry)
                        if (_track.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _track,
                                strokeWidth: 4.0,
                                color: Colors.red, // Twój aktualny ślad
                              ),
                            ],
                          ),

                        // 3. WARSTWA: LINIA PROSTA (opcjonalnie, jeśli trasa się nie załaduje)
                        if (_track.isNotEmpty &&
                            peakLatLng != null &&
                            _routePath.isEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: [..._track, peakLatLng],
                                strokeWidth: 2,
                                color: Colors.grey.withValues(alpha: 0.5),
                              ),
                            ],
                          ),

                        // Marker szczytu
                        if (peakLatLng != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: peakLatLng,
                                width: 40,
                                height: 40,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  Icons.place,
                                  size: 36,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),

                        // Marker użytkownika
                        if (_track.isNotEmpty)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _track.last,
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.8),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    // PRZYCISKI MAPY
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Column(
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'zoom_in_active',
                            onPressed: _zoomIn,
                            child: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'zoom_out_active',
                            onPressed: _zoomOut,
                            child: const Icon(Icons.remove),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'my_location_active',
                            onPressed: _goToMyLocation,
                            child: const Icon(Icons.my_location),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'go_peak_active',
                            onPressed: _goToPeak,
                            child: const Icon(Icons.flag),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            if (_routePath.isNotEmpty)
              const Text(
                '🔵 Niebieska linia: Wyznaczony szlak (sugerowana trasa).\n'
                '🔴 Czerwona linia: Twój aktualny ślad.',
                style: TextStyle(fontSize: 12),
              )
            else
              const Text(
                'Widoczna przerywana linia pokazuje prosty kierunek do szczytu.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),

            const SizedBox(height: 24),

            // PRZYCISKI AKCJI
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _togglePause,
                    icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                    label: Text(_paused ? 'Wznów wędrówkę' : 'Pauzuj wędrówkę'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _finishHike,
                    icon: const Icon(Icons.flag),
                    label: const Text('Zakończ wędrówkę'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
