import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// UWAGA: to działa tylko na Web; na mobile brak 'dart:html'.
// Na razie celowo – później zrobimy ładny conditional import.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class DownloadsStore extends ChangeNotifier {
  static final DownloadsStore instance = DownloadsStore._();
  DownloadsStore._();

  final List<Map<String, Object?>> _items = [];
  bool _initialized = false;

  List<Map<String, Object?>> get items => List.unmodifiable(_items);

  static const _prefsKey = 'downloads';
  static const _localStorageKey = 'downloads';

  Future<void> init() async {
    if (_initialized) return;

    // 1) Próba z SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const <String>[];

    debugPrint('[DownloadsStore] init(): prefs raw length=${raw.length}');

    List<Map<String, Object?>> loaded = [];
    try {
      loaded = raw
          .map((s) => Map<String, Object?>.from(jsonDecode(s) as Map))
          .toList();
    } catch (e) {
      debugPrint('[DownloadsStore] init(): decode from prefs FAILED: $e');
    }

    // 2) Jeżeli pusto i jesteśmy na Web – spróbuj z localStorage
    if (loaded.isEmpty && kIsWeb) {
      try {
        final origin = html.window.location.origin;
        final ls = html.window.localStorage[_localStorageKey];
        debugPrint(
          '[DownloadsStore] init(): web origin=$origin, localStorage has=${ls != null}',
        );
        if (ls != null && ls.isNotEmpty) {
          final list = (jsonDecode(ls) as List)
              .map(
                (s) =>
                    Map<String, Object?>.from(jsonDecode(s as String) as Map),
              )
              .toList();
          loaded = list;
          debugPrint(
            '[DownloadsStore] init(): loaded from localStorage count=${loaded.length}',
          );
        }
      } catch (e) {
        debugPrint('[DownloadsStore] init(): read localStorage FAILED: $e');
      }
    }

    _items
      ..clear()
      ..addAll(loaded);

    _initialized = true;
    debugPrint('[DownloadsStore] init(): items=${_items.length}');
    notifyListeners();
  }

  Future<void> _save() async {
    final list = _items.map((m) => jsonEncode(m)).toList();

    // SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, list);
      debugPrint(
        '[DownloadsStore] _save(): saved to prefs count=${list.length}',
      );
    } catch (e) {
      debugPrint('[DownloadsStore] _save(): prefs save FAILED: $e');
    }

    // localStorage (Web)
    if (kIsWeb) {
      try {
        final jsonList = jsonEncode(list);
        html.window.localStorage[_localStorageKey] = jsonList;
        final origin = html.window.location.origin;
        debugPrint(
          '[DownloadsStore] _save(): saved to localStorage (origin=$origin) count=${list.length}',
        );
      } catch (e) {
        debugPrint('[DownloadsStore] _save(): localStorage save FAILED: $e');
      }
    }
  }

  Future<void> add(Map<String, Object?> trail) async {
    final name = trail['name'] as String?;
    final exists = _items.any((t) => t['name'] == name);
    if (!exists) {
      _items.add(Map<String, Object?>.from(trail));
      await _save();
      notifyListeners();
    } else {
      debugPrint('[DownloadsStore] add(): already exists "$name" – skip');
    }
  }

  Future<void> removeAt(int index) async {
    _items.removeAt(index);
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    await _save();
    notifyListeners();
  }
}
