import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/notification_settings.dart';

class SettingsRepository {
  static const String _keyPrefix = 'notification_settings_';

  String get _key {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return '$_keyPrefix$uid';
  }

  Future<NotificationSettings> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    
    if (jsonString == null) {
      return NotificationSettings.defaultSettings();
    }

    try {
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      return NotificationSettings.fromJson(jsonMap);
    } catch (e) {
      return NotificationSettings.defaultSettings();
    }
  }

  Future<void> saveNotificationSettings(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(settings.toJson());
    await prefs.setString(_key, jsonString);
  }
}
