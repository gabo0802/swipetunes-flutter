import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipetunes/models/swipe_log_entry.dart';

class SwipeHistoryStorage {
  static const String _historyKey = 'swipe_history_v1';
  static const int maxEntries = 50;

  Future<List<SwipeLogEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((entry) => SwipeLogEntry.fromJson(entry as Map<String, dynamic>))
          .take(maxEntries)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<SwipeLogEntry> history) async {
    final prefs = await SharedPreferences.getInstance();
    final capped =
        history.take(maxEntries).map((entry) => entry.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(capped));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
