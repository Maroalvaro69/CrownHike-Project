import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';

class TrailsScreen extends StatefulWidget {
  const TrailsScreen({super.key});

  @override
  State<TrailsScreen> createState() => _TrailsScreenState();
}

class _TrailsScreenState extends State<TrailsScreen> {
  final _query = TextEditingController();
  List<RemoteHike> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHikes();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadHikes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiClient.I.getAuth('/hikes');
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>)
          .map((e) => RemoteHike.fromJson(e as Map<String, dynamic>))
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

  List<RemoteHike> get _filtered {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all
        .where(
          (h) =>
              h.peakName.toLowerCase().contains(q) ||
              (h.peakRange?.toLowerCase().contains(q) ?? false),
        )
        .toList();
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
              onPressed: _loadHikes,
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
          TextField(
            controller: _query,
            decoration: InputDecoration(
              hintText: 'Szukaj wędrówki…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Brak zapisanych wędrówek'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final h = filtered[i];
                      final chips = <String>[];

                      if (h.peakRange != null && h.peakRange!.isNotEmpty) {
                        chips.add(h.peakRange!);
                      }
                      if (h.peakHeightM != null) {
                        chips.add('${h.peakHeightM} m n.p.m.');
                      }
                      chips.add('${h.trackDistanceKm.toStringAsFixed(2)} km');

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.hiking),
                          title: Text(h.peakName),
                          subtitle: Text(
                            '${_fmtDate(h.startedAt)} • '
                            '${_fmtDuration(h.duration)}\n'
                            '${chips.join(' • ')}',
                          ),
                          isThreeLine: true,
                          // tutaj później możemy zrobić przejście do detali / mapy
                          onTap: () {
                            // TODO: ekran szczegółów wędrówki z mapą
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

  String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} '
        '${two(d.hour)}:${two(d.minute)}';
  }

  String _fmtDuration(Duration dur) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(dur.inHours);
    final m = two(dur.inMinutes.remainder(60));
    final s = two(dur.inSeconds.remainder(60));
    return '$h:$m:$s';
  }
}

/// Prosty model wędrówki zwracanej z backendu /hikes
class RemoteHike {
  final int id;
  final int peakId;
  final String peakName;
  final int? peakHeightM;
  final String? peakRange;
  final DateTime startedAt;
  final int durationSec;
  final double trackDistanceKm;
  final double? straightDistanceKm;

  RemoteHike({
    required this.id,
    required this.peakId,
    required this.peakName,
    required this.startedAt,
    required this.durationSec,
    required this.trackDistanceKm,
    this.peakHeightM,
    this.peakRange,
    this.straightDistanceKm,
  });

  Duration get duration => Duration(seconds: durationSec);
  double get trackDistanceKmDouble => trackDistanceKm;

  factory RemoteHike.fromJson(Map<String, dynamic> j) {
    double _toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return RemoteHike(
      id: (j['id'] as num).toInt(),
      peakId: (j['peak_id'] as num).toInt(),
      peakName: (j['peak_name'] ?? '') as String,
      peakHeightM: j['peak_height_m'] != null
          ? (j['peak_height_m'] as num).toInt()
          : null,
      peakRange: j['peak_range'] as String?,
      startedAt: DateTime.parse(j['started_at'].toString()),
      durationSec: (j['duration_sec'] as num).toInt(),
      trackDistanceKm: _toDouble(j['track_distance_km']),
      straightDistanceKm: j['straight_distance_km'] != null
          ? _toDouble(j['straight_distance_km'])
          : null,
    );
  }

  double get trackDistanceKmRounded => trackDistanceKm;
}
