import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movie.dart';

class StorageService {
  static const String _keyWatchlist = 'flix_watchlist';
  static const String _keySearchHistory = 'flix_search_history';
  static const String _keyCustomBackend = 'flix_custom_backend';
  static const String _keyBaseUrl = 'flix_base_url';

  // Watchlist
  static Future<List<Movie>> getWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyWatchlist);
    if (raw == null) return [];
    try {
      final list = json.decode(raw) as List;
      return list.map((e) => Movie.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> isWatchlisted(String slug) async {
    final list = await getWatchlist();
    return list.any((m) => m.slug == slug);
  }

  static Future<void> toggleWatchlist(Movie movie) async {
    final list = await getWatchlist();
    final idx = list.indexWhere((m) => m.slug == movie.slug);
    if (idx != -1) {
      list.removeAt(idx);
    } else {
      list.insert(0, movie);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWatchlist, json.encode(list.map((m) => m.toJson()).toList()));
  }

  // Search History
  static Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keySearchHistory) ?? [];
  }

  static Future<void> addSearchQuery(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_keySearchHistory) ?? [];
    history.remove(query);
    history.insert(0, query);
    if (history.length > 20) {
      history.removeLast();
    }
    await prefs.setStringList(_keySearchHistory, history);
  }

  static Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySearchHistory);
  }

  // Settings
  static Future<String?> getCustomBackend() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomBackend);
  }

  static Future<void> setCustomBackend(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_keyCustomBackend);
    } else {
      await prefs.setString(_keyCustomBackend, url.trim());
    }
  }

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaseUrl) ?? 'https://9xflix.esq/m/';
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, url.trim());
  }
}
