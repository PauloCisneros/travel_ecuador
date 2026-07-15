import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/visita_service.dart';

class DashboardCache {
  static const Duration _ttl = Duration(minutes: 5);
  static const String _prefix = 'dashboard_stats_';

  static String _key(String uid) => '$_prefix$uid';

  static Future<void> save(String uid, DashboardStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), jsonEncode(stats.toMap()));
  }

  static Future<DashboardStats?> get(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key(uid));

    if (jsonStr == null) return null;

    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final stats = DashboardStats.fromMap(map);
      if (DashboardCache.isFresh(stats)) {
        return stats;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> invalidate(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
  }

  static bool isFresh(DashboardStats stats) {
    return DateTime.now().difference(stats.fetchedAt) < _ttl;
  }
}