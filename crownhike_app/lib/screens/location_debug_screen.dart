import 'dart:async'; // TimeoutException
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Position, Geolocator

import '../services/location_service.dart';

class LocationDebugScreen extends StatefulWidget {
  static const route = '/debugLocation';

  const LocationDebugScreen({super.key});

  @override
  State<LocationDebugScreen> createState() => _LocationDebugScreenState();
}

class _LocationDebugScreenState extends State<LocationDebugScreen> {
  double? lat;
  double? lng;
  double? alt;
  bool loading = false;
  String? error;

  Future<void> _refresh() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // Najpierw uprawnienia (nasz serwis)
      final ok = await LocationService.instance.ensurePermission();
      if (!ok) {
        setState(() {
          loading = false;
          error =
              'Brak uprawnień lub usługi lokalizacji są wyłączone.\n'
              'Sprawdź ustawienia systemu/przeglądarki.';
        });
        return;
      }

      // Potem realne pobieranie pozycji z twardym timeoutem 10 s
      final Position pos = await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 10),
      );

      setState(() {
        lat = pos.latitude;
        lng = pos.longitude;
        alt = pos.altitude;
        loading = false;
      });
    } on TimeoutException {
      setState(() {
        loading = false;
        error =
            'Nie udało się pobrać lokalizacji (timeout).\n'
            'Na laptopach lokalizacja bywa blokowana w systemie lub przeglądarce.\n'
            'Spróbuj później lub na telefonie/emulatorze.';
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = 'Błąd przy pobieraniu lokalizacji: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moja lokalizacja')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: loading
              ? const CircularProgressIndicator()
              : error != null
              ? Text(error!, textAlign: TextAlign.center)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Latitude:  ${lat ?? "---"}'),
                    Text('Longitude: ${lng ?? "---"}'),
                    Text('Altitude:  ${alt?.toStringAsFixed(1) ?? "---"} m'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text("Odśwież"),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
