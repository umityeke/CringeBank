import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';

class SearchHistoryService {
  static const String _searchHistoryKey = 'search_history_users';
  static const int _maxHistoryItems = 20;

  // Arama geçmiğine kullanıcı ekle
  static Future<void> addToHistory(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_searchHistoryKey);

      List<Map<String, dynamic>> history = [];
      if (historyJson != null) {
        final decoded = jsonDecode(historyJson) as List;
        history = decoded.map((e) => e as Map<String, dynamic>).toList();
      }

      // Aynı kullanıcı varsa önce kaldır
      history.removeWhere((item) => item['id'] == user.id);

      // Yeni kullanıcıyı en bağa ekle
      history.insert(0, {
        'id': user.id,
        'username': user.username,
        'displayName': user.displayName,
        'avatar': user.avatar,
        'krepScore': user.krepScore,
      });

      // Maksimum limit kontrolü
      if (history.length > _maxHistoryItems) {
        history = history.take(_maxHistoryItems).toList();
      }

      // Kaydet
      await prefs.setString(_searchHistoryKey, jsonEncode(history));
    } catch (e, stackTrace) {
      debugPrint('Add to search history error: $e');
      debugPrintStack(
        label: 'SearchHistoryService.addToHistory',
        stackTrace: stackTrace,
      );
    }
  }

  // Arama geçmiğini getir
  static Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_searchHistoryKey);

      if (historyJson == null) return [];

      final decoded = jsonDecode(historyJson) as List;
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (e, stackTrace) {
      debugPrint('Get search history error: $e');
      debugPrintStack(
        label: 'SearchHistoryService.getHistory',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // Arama geçmiğini temizle
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchHistoryKey);
    } catch (e, stackTrace) {
      debugPrint('Clear search history error: $e');
      debugPrintStack(
        label: 'SearchHistoryService.clearHistory',
        stackTrace: stackTrace,
      );
    }
  }

  // Geçmiğten kullanıcı sil
  static Future<void> removeFromHistory(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_searchHistoryKey);

      if (historyJson == null) return;

      final decoded = jsonDecode(historyJson) as List;
      List<Map<String, dynamic>> history = decoded
          .map((e) => e as Map<String, dynamic>)
          .toList();

      history.removeWhere((item) => item['id'] == userId);

      await prefs.setString(_searchHistoryKey, jsonEncode(history));
    } catch (e, stackTrace) {
      debugPrint('Remove from search history error: $e');
      debugPrintStack(
        label: 'SearchHistoryService.removeFromHistory',
        stackTrace: stackTrace,
      );
    }
  }
}
