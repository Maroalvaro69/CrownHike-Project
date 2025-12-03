import 'dart:developer' as dev;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:html' as html;

import '../models/hike_session.dart';

/// Magazyn zakończonych wędrówek użytkownika.
/// Działa podobnie jak DownloadsStore – trzyma listę w pamięci
/// i zapisuje ją w SharedPreferences (mobile) lub localStorage (web).
class HikesStore {
  HikesStore._();

  static final HikesStore instance = HikesStore._();

  static const _storageKey = 'hike_sessions';

  List<HikeSession> _items = [];

  /// Publiczny, niemodyfikowalny widok na listę sesji.
  List<HikeSession> get items => List.unmodifiable(_items);

  /// Wczytanie sesji z pamięci trwałej.
  Future<void> init() async {
    String? raw;

    if (kIsWeb) {
      final storage = html.window.localStorage;
      raw = storage[_storageKey];
      dev.log('[HikesStore] init() web: has=${raw != null}');
    } else {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_storageKey);
      dev.log('[HikesStore] init() mobile/desktop: has=${raw != null}');
    }

    _items = HikeSession.decodeList(raw);
    dev.log('[HikesStore] loaded count=${_items.length}');
  }

  Future<void> _save() async {
    final raw = HikeSession.encodeList(_items);

    if (kIsWeb) {
      html.window.localStorage[_storageKey] = raw;
      dev.log('[HikesStore] save() web: len=${raw.length}');
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, raw);
      dev.log('[HikesStore] save() prefs: len=${raw.length}');
    }
  }

  /// Dodaje nową zakończoną wędrówkę i zapisuje ją.
  Future<void> addSession(HikeSession session) async {
    _items.add(session);
    await _save();
  }

  /// Czyści wszystkie zapisane wędrówki (np. dla debugowania).
  Future<void> clear() async {
    _items.clear();
    await _save();
  }
}
