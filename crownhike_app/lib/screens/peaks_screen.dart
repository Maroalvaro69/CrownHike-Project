import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/peak.dart';
import '../services/api_client.dart';
import 'peak_details_screen.dart';

class PeaksScreen extends StatefulWidget {
  const PeaksScreen({super.key});

  @override
  State<PeaksScreen> createState() => _PeaksScreenState();
}

class _PeaksScreenState extends State<PeaksScreen> {
  final _query = TextEditingController();
  List<Peak> _all = [];
  bool _loading = true;
  String? _error;

  // FILTRY
  String? _difficultyFilter; // EASY / MODERATE / HARD / EXPERT / null
  String?
  _trailColorFilter; // RED / BLUE / GREEN / YELLOW / BLACK / MIXED / null
  String? _rangeFilter; // Tatry Wysokie / Tatry Zachodnie / ... / null

  @override
  void initState() {
    super.initState();
    _loadPeaks();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadPeaks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = <String, String>{'page': '1', 'limit': '100'};

      if (_difficultyFilter != null) {
        query['difficulty'] = _difficultyFilter!;
      }
      if (_trailColorFilter != null) {
        query['main_trail_color'] = _trailColorFilter!;
      }
      if (_rangeFilter != null) {
        query['mountain_range'] = _rangeFilter!;
      }

      final res = await ApiClient.I.get('/peaks', query: query);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }
      final data = jsonDecode(res.body);
      final list = (data['data'] as List)
          .map((e) => Peak.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Peak> get _filtered {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  // mapowanie kodów trudności na ładny tekst
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

  // mapowanie koloru szlaku na ładny opis
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Błąd: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadPeaks,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      );
    }

    final filtered = _filtered;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // WYSZUKIWANIE PO NAZWIE
          TextField(
            controller: _query,
            decoration: InputDecoration(
              hintText: 'Szukaj szczytu…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // FILTRY (trudność, kolor szlaku, pasmo)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String?>(
                  value: _difficultyFilter,
                  decoration: const InputDecoration(
                    labelText: 'Trudność',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Wszystkie'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'EASY',
                      child: Text('Łatwe'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'MODERATE',
                      child: Text('Umiarkowane'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'HARD',
                      child: Text('Trudne'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'EXPERT',
                      child: Text('Bardzo trudne'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _difficultyFilter = value;
                    });
                    _loadPeaks();
                  },
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String?>(
                  value: _trailColorFilter,
                  decoration: const InputDecoration(
                    labelText: 'Kolor szlaku',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Wszystkie'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'RED',
                      child: Text('Czerwony'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'BLUE',
                      child: Text('Niebieski'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'GREEN',
                      child: Text('Zielony'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'YELLOW',
                      child: Text('Żółty'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'BLACK',
                      child: Text('Czarny'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'MIXED',
                      child: Text('Mieszany'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _trailColorFilter = value;
                    });
                    _loadPeaks();
                  },
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String?>(
                  value: _rangeFilter,
                  decoration: const InputDecoration(
                    labelText: 'Pasmo',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Wszystkie'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'Tatry Wysokie',
                      child: Text('Tatry Wysokie'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'Tatry Zachodnie',
                      child: Text('Tatry Zachodnie'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'Tatry Bielskie',
                      child: Text('Tatry Bielskie'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'Tatry Liptowskie',
                      child: Text('Tatry Liptowskie'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _rangeFilter = value;
                    });
                    _loadPeaks();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Brak szczytów'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      final chips = <String>[];

                      if (p.region.isNotEmpty) {
                        chips.add(p.region);
                      }

                      if (p.elevationM != null) {
                        chips.add('${p.elevationM} m n.p.m.');
                      }

                      if (p.difficulty != null && p.difficulty!.isNotEmpty) {
                        chips.add(
                          'Trudność: ${_difficultyLabel(p.difficulty!)}',
                        );
                      }

                      if (p.mainTrailColor != null &&
                          p.mainTrailColor!.isNotEmpty) {
                        chips.add(_trailColorLabel(p.mainTrailColor!));
                      }

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.terrain),
                          title: Text(p.name),
                          subtitle: chips.isEmpty
                              ? null
                              : Text(chips.join(' • ')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              PeakDetailsScreen.route,
                              arguments: p,
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
