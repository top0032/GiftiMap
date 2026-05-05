import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../domain/models/gifticon_model.dart';

class ExpirationNotificationService {
  static final ExpirationNotificationService _instance = ExpirationNotificationService._internal();
  factory ExpirationNotificationService() => _instance;
  ExpirationNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (!kIsWeb && Platform.isWindows) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // 알림 클릭 시 처리 로직
      },
    );
  }

  /// 기프티콘 만료 알림 예약 (7일전, 3일전, 1일전)
  Future<void> scheduleExpirationNotifications(GifticonModel gifticon) async {
    if (!kIsWeb && Platform.isWindows) return;
    if (gifticon.isUsed == true) return;

    // [테스트용] 등록 5초 후 즉시 알림 테스트 (정상 작동 확인용)
    await _scheduleTestNotification(gifticon);

    final expirationDate = _parseExpirationDate(gifticon.expirationDate);
    if (expirationDate == null) {
      debugPrint('날짜 파싱 실패: ${gifticon.expirationDate}');
      return;
    }

    final notificationDays = [7, 3, 1];
    
    for (int daysBefore in notificationDays) {
      final scheduledDate = expirationDate.subtract(Duration(days: daysBefore));
      final finalScheduledDate = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        9, 0, 0,
      );

      if (finalScheduledDate.isBefore(DateTime.now())) continue;

      final notificationId = _generateNotificationId(gifticon.id, daysBefore);

      await _localNotificationsPlugin.zonedSchedule(
        id: notificationId,
        title: '기프티콘 만료 임박! 🎁',
        body: '${gifticon.brandName} - ${gifticon.productName} 유효기간이 $daysBefore일 남았습니다.',
        scheduledDate: tz.TZDateTime.from(finalScheduledDate, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'expiration_channel',
            'Expiration Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> _scheduleTestNotification(GifticonModel gifticon) async {
    try {
      await _localNotificationsPlugin.zonedSchedule(
        id: (gifticon.id.hashCode).abs() % 0x7FFFFFFF,
        title: '테스트 알림: 기프티콘 등록 완료! ✅',
        body: '${gifticon.brandName} 기프티콘이 등록되었습니다. (5초 후 알림)',
        scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel',
            'Test Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('테스트 알림 예약 실패: $e');
    }
  }

  /// 특정 기프티콘의 모든 알림 취소
  Future<void> cancelExpirationNotifications(String gifticonId) async {
    if (!kIsWeb && Platform.isWindows) return;
    
    final notificationDays = [7, 3, 1];
    for (int daysBefore in notificationDays) {
      final notificationId = _generateNotificationId(gifticonId, daysBefore);
      await _localNotificationsPlugin.cancel(id: notificationId);
    }
    // 테스트 알림도 취소
    await _localNotificationsPlugin.cancel(id: (gifticonId.hashCode).abs() % 0x7FFFFFFF);
  }

  DateTime? _parseExpirationDate(String dateStr) {
    try {
      final regex = RegExp(r'(\d{4})[./년\s\-]*(\d{1,2})[./월\s\-]*(\d{1,2})');
      final match = regex.firstMatch(dateStr);
      
      if (match != null && match.groupCount >= 3) {
        final year = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final day = int.parse(match.group(3)!);
        return DateTime(year, month, day);
      }

      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) return parsed;
      
    } catch (_) {}
    return null;
  }

  int _generateNotificationId(String gifticonId, int daysBefore) {
    return (gifticonId.hashCode ^ daysBefore.hashCode).abs() % 0x7FFFFFFF;
  }
}
