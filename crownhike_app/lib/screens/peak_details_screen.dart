// lib/screens/peak_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/peak.dart';
import '../services/location_service.dart';
import 'active_hike_screen.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart'
    as fmctp;

class PeakDetailsScreen extends StatefulWidget {
  static const route = '/peakDetails';

  const PeakDetailsScreen({super.key});

  @override
  State<PeakDetailsScreen> createState() => _PeakDetailsScreenState();
}

class _PeakDetailsScreenState extends State<PeakDetailsScreen> {
  final MapController _mapController = MapController();

  Peak? _peak;

  double? _userLat;
  double? _userLng;
  bool _loadingLocation = true;
  String? _locationError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Odbieramy Peak tylko raz
    if (_peak == null) {
      final args = ModalRoute.of(context)!.settings.arguments;

      if (args is Peak) {
        _peak = args;
      } else if (args is Map<String, dynamic>) {
        // awaryjnie, gdyby gdzieś był jeszcze stary sposób przekazywania
        _peak = Peak(
          id: args['id'] as int,
          name: args['name'] as String,
          region: (args['region'] ?? '') as String,
          elevationM: args['elevationM'] as int?,
          lat: (args['lat'] as num?)?.toDouble(),
          lng: (args['lng'] as num?)?.toDouble(),
          description: args['description'] as String?,
          difficulty: args['difficulty'] as String?,
          mainTrailColor: args['main_trail_color'] as String?,
        );
      }

      // od razu zaczynamy ładować pozycję użytkownika
      _loadUserLocation();
    }
  }

  Future<void> _loadUserLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos == null) {
        setState(() {
          _loadingLocation = false;
          _locationError = 'Brak dostępu do lokalizacji.';
        });
        return;
      }

      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        _loadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _loadingLocation = false;
        _locationError = 'Błąd pobierania lokalizacji: $e';
      });
    }
  }

  String _difficultyLabel(String diff) {
    switch (diff) {
      case 'EASY':
        return 'łatwy';
      case 'MODERATE':
        return 'umiarkowany';
      case 'HARD':
        return 'trudny';
      case 'EXPERT':
        return 'bardzo trudny';
      default:
        return diff;
    }
  }

  String _trailColorLabel(String color) {
    switch (color) {
      case 'RED':
        return 'szlak czerwony';
      case 'BLUE':
        return 'szlak niebieski';
      case 'GREEN':
        return 'szlak zielony';
      case 'YELLOW':
        return 'szlak żółty';
      case 'BLACK':
        return 'szlak czarny';
      case 'MIXED':
        return 'szlak mieszany';
      default:
        return color;
    }
  }

  Color _trailColorVisual(String? color) {
    switch (color) {
      case 'RED':
        return Colors.red;
      case 'BLUE':
        return Colors.blue;
      case 'GREEN':
        return Colors.green;
      case 'YELLOW':
        return Colors.amber;
      case 'BLACK':
        return Colors.black87;
      case 'MIXED':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final peak = _peak;
    if (peak == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final lat = peak.lat;
    final lng = peak.lng;
    final hasCoords = lat != null && lng != null;

    final userLat = _userLat;
    final userLng = _userLng;
    final hasUser = userLat != null && userLng != null;

    // Punkt startowy mapy – jeśli są współrzędne szczytu, ustawiamy na szczyt
    final LatLng mapCenter = hasCoords
        ? LatLng(lat, lng)
        : const LatLng(49.3, 20.0); // jakiś sensowny default (Tatry)

    const double initialZoom = 11.0;

    final elevationText = peak.elevationM != null
        ? '${peak.elevationM} m n.p.m.'
        : '- m n.p.m.';

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF), // Indigo 50
      appBar: AppBar(title: Text(peak.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // REGION
            Text(
              peak.region.isNotEmpty ? peak.region : 'Tatry',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            // WYSOKOŚĆ + TRUDNOŚĆ + KOLOR SZLAKU W JEDNYM BLOKU
            Row(
              children: [
                const Icon(Icons.terrain, size: 20),
                const SizedBox(width: 8),
                Text(
                  elevationText,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (peak.difficulty != null && peak.difficulty!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.fitness_center, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Trudność: ${_difficultyLabel(peak.difficulty!)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),

            if (peak.mainTrailColor != null &&
                peak.mainTrailColor!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _trailColorVisual(peak.mainTrailColor),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _trailColorLabel(peak.mainTrailColor!),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // OPIS
            Text('Opis', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              peak.description?.isNotEmpty == true
                  ? peak.description!
                  : 'Brak opisu dla tego szczytu.',
            ),
            const SizedBox(height: 24),

            // MAPA
            if (hasCoords) ...[
              Text(
                'Położenie na mapie',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              SizedBox(
                height: 260,
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
                          initialZoom: initialZoom,
                          interactionOptions: const InteractionOptions(
                            flags:
                                InteractiveFlag.drag |
                                InteractiveFlag.pinchZoom |
                                InteractiveFlag.doubleTapZoom,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                            userAgentPackageName: 'com.example.crownhike_app',
                            tileProvider:
                                fmctp.CancellableNetworkTileProvider(),
                          ),

                          // MARKERY
                          MarkerLayer(
                            markers: [
                              // Szczyt
                              Marker(
                                point: LatLng(lat, lng),
                                width: 40,
                                height: 40,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  Icons.place,
                                  size: 36,
                                  color: Colors.red,
                                ),
                              ),

                              // Użytkownik – jeśli znamy jego pozycję
                              if (hasUser)
                                Marker(
                                  point: LatLng(userLat, userLng),
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.8),
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

                          // LINIA UŻYTKOWNIK → SZCZYT
                          if (hasUser)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [
                                    LatLng(userLat, userLng),
                                    LatLng(lat, lng),
                                  ],
                                  strokeWidth: 3,
                                  color: Colors.blueAccent,
                                ),
                              ],
                            ),
                        ],
                      ),

                      // PRZYCISKI STEROWANIA MAPĄ
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Column(
                          children: [
                            // Przybliż/oddal
                            Card(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    tooltip: 'Przybliż',
                                    onPressed: () {
                                      final zoom =
                                          _mapController.camera.zoom + 1;
                                      _mapController.move(
                                        _mapController.camera.center,
                                        zoom,
                                      );
                                    },
                                  ),
                                  const Divider(height: 1),
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    tooltip: 'Oddal',
                                    onPressed: () {
                                      final zoom =
                                          _mapController.camera.zoom - 1;
                                      _mapController.move(
                                        _mapController.camera.center,
                                        zoom,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Centrowanie na szczyt
                            Card(
                              child: IconButton(
                                icon: const Icon(Icons.flag),
                                tooltip: 'Pokaż szczyt',
                                onPressed: () {
                                  _mapController.move(LatLng(lat, lng), 13);
                                },
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Centrowanie na użytkownika
                            Card(
                              child: IconButton(
                                icon: const Icon(Icons.my_location),
                                tooltip: 'Pokaż moją pozycję',
                                onPressed: hasUser
                                    ? () {
                                        _mapController.move(
                                          LatLng(userLat, userLng),
                                          13,
                                        );
                                      }
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Dopasuj widok (szczyt + użytkownik)
                            Card(
                              child: IconButton(
                                icon: const Icon(Icons.fit_screen),
                                tooltip: 'Dopasuj widok',
                                onPressed: hasUser
                                    ? () {
                                        final bounds = LatLngBounds.fromPoints([
                                          LatLng(lat, lng),
                                          LatLng(userLat, userLng),
                                        ]);

                                        final camera = CameraFit.bounds(
                                          bounds: bounds,
                                          padding: const EdgeInsets.all(40),
                                        );

                                        _mapController.fitCamera(camera);
                                      }
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.my_location, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Szerokość: ${lat.toStringAsFixed(5)}\n'
                      'Długość:  ${lng.toStringAsFixed(5)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // przejście do ekranu aktywnej wędrówki
                    Navigator.pushNamed(
                      context,
                      ActiveHikeScreen.route,
                      arguments: peak, // przekazujemy cały obiekt Peak
                    );
                  },
                  icon: const Icon(Icons.directions_walk),
                  label: const Text('Rozpocznij wędrówkę'),
                ),
              ),

              const SizedBox(height: 8),

              if (_loadingLocation)
                const Text(
                  'Pobieranie Twojej lokalizacji…',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                )
              else if (_locationError != null)
                Text(
                  _locationError!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                )
              else if (hasUser)
                const Text(
                  'Widoczna niebieska linia pokazuje prostą trasę\n'
                  'od Twojej aktualnej pozycji do szczytu.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ] else ...[
              Text(
                'Brak danych o położeniu tego szczytu.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
