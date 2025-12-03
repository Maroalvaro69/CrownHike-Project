import 'package:flutter/material.dart';
import '../services/downloads_store.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final _store = DownloadsStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChange);
    _store.init();
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    _store.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _store.items;

    if (items.isEmpty) {
      return const Center(
        child: Text('Brak pobranych tras', style: TextStyle(fontSize: 18)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final t = items[i];
          final distanceKm = (t['distanceKm'] as double).toStringAsFixed(1);
          final ascent = t['ascent'];
          final difficulty = t['difficulty'];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.offline_pin),
              title: Text(t['name'] as String),
              subtitle: Text('$distanceKm km • ↑ $ascent m • $difficulty'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async => _store.removeAt(i), // <-- async
                tooltip: 'Usuń z pobranych',
              ),
            ),
          );
        },
      ),
    );
  }
}
