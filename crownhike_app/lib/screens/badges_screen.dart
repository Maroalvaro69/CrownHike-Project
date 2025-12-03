// lib/screens/badges_screen.dart
import 'package:flutter/material.dart';

import '../models/badge.dart' as models;
import '../services/badges_api.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final _api = BadgesApi();

  bool _loading = true;
  String? _error;

  List<models.Badge> _all = [];
  List<models.Badge> _my = [];

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final all = await _api.getAllBadges();
      final mine = await _api.getMyBadges();

      setState(() {
        _all = all;
        _my = mine;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showBadgeDialog(models.Badge badge, bool earned) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                earned ? Icons.verified : Icons.verified_outlined,
                color: earned ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(badge.name)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (badge.requiredPeaks != null) ...[
                Text(
                  'Wymagania:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Zdobądź co najmniej ${badge.requiredPeaks} różnych szczytów.',
                ),
                const SizedBox(height: 12),
              ],
              Text(badge.description),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zamknij'),
            ),
          ],
        );
      },
    );
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
            Text(
              'Błąd ładowania odznak:\n$_error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadBadges,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      );
    }

    // z listy moich odznak bierzemy tylko ich id
    final Set<int> earnedIds = _my.map((b) => b.id).toSet();

    final earned = _all
        .where((b) => earnedIds.contains(b.id))
        .toList(growable: false);
    final notEarned = _all
        .where((b) => !earnedIds.contains(b.id))
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: _loadBadges,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Twoje odznaki', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (earned.isEmpty)
            const Text('Nie zdobyłeś jeszcze żadnych odznak.')
          else
            _BadgesSection(
              badges: earned,
              earnedIds: earnedIds,
              onTap: (badge) => _showBadgeDialog(badge, true),
            ),
          const SizedBox(height: 24),
          Text(
            'Wszystkie dostępne odznaki',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _BadgesSection(
            badges: notEarned,
            earnedIds: earnedIds,
            onTap: (badge) => _showBadgeDialog(badge, false),
          ),
        ],
      ),
    );
  }
}

class _BadgesSection extends StatelessWidget {
  const _BadgesSection({
    required this.badges,
    required this.earnedIds,
    required this.onTap,
  });

  final List<models.Badge> badges;
  final Set<int> earnedIds;
  final void Function(models.Badge badge) onTap;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const Text(
        'Brak odznak w tej sekcji.',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      children: [
        for (final badge in badges)
          Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                earnedIds.contains(badge.id)
                    ? Icons.verified
                    : Icons.verified_outlined,
                color: earnedIds.contains(badge.id)
                    ? Colors.green
                    : Colors.grey,
              ),
              title: Text(badge.name),
              subtitle: _buildSubtitle(badge),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onTap(badge),
            ),
          ),
      ],
    );
  }

  Widget? _buildSubtitle(models.Badge badge) {
    final buffer = <String>[];

    if (badge.requiredPeaks != null) {
      buffer.add('Wymagane szczyty: ${badge.requiredPeaks}');
    }

    if (badge.description.isNotEmpty) {
      buffer.add(badge.description);
    }

    if (buffer.isEmpty) return null;
    return Text(buffer.join(' • '));
  }
}
