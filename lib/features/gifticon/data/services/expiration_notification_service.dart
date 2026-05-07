import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../domain/models/gifticon_model.dart';
import '../../../settings/data/repositories/settings_repository.dart';

class ExpirationNotificationService {
  static final ExpirationNotificationService _instance = ExpirationNotificationService._internal();
  factory ExpirationNotificationService() => _instance;
  ExpirationNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final SettingsRepository _settingsRepository = SettingsRepository();

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

    // 권한 요청 추가
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // 알림 권한 요청 (Android 13+)
      await androidImplementation?.requestNotificationsPermission();
      // 정확한 알람 권한 요청 (Android 12+)
      await androidImplementation?.requestExactAlarmsPermission();
    } else if (Platform.isIOS) {
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  /// 기프티콘 만료 알림 예약 (사용자 설정에 따름)
  Future<void> scheduleExpirationNotifications(GifticonModel gifticon) async {
    if (!kIsWeb && Platform.isWindows) return;
    if (gifticon.isUsed == true) return;

    final settings = await _settingsRepository.getNotificationSettings();
    if (!settings.isEnabled) return;

    final expirationDate = gifticon.parsedExpirationDate;
    if (expirationDate == null) return;

    for (final alert in settings.alerts) {
      final daysBefore = alert.daysBefore;
      final scheduledDate = expirationDate.subtract(Duration(days: daysBefore));
      final finalScheduledDate = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        alert.hour,
        alert.minute,
        0,
      );

      if (finalScheduledDate.isBefore(DateTime.now())) continue;

      final notificationId = _generateNotificationId(gifticon.id, daysBefore);

      final body = daysBefore == 0 
          ? '${gifticon.brandName} - ${gifticon.productName} 유효기간이 오늘 만료됩니다! ⏰'
          : '${gifticon.brandName} - ${gifticon.productName} 유효기간이 $daysBefore일 남았습니다.';

      await _localNotificationsPlugin.zonedSchedule(
        id: notificationId,
        title: daysBefore == 0 ? '기프티콘 오늘 만료! 🚨' : '기프티콘 만료 임박! 🎁',
        body: body,
        scheduledDate: tz.TZDateTime.from(finalScheduledDate, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'expiration_channel',
            '유효기간 만료 알림',
            channelDescription: '기프티콘 유효기간 만료 전 알림을 보냅니다.',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  /// 기프티콘 만료 알림 취소
  Future<void> cancelExpirationNotifications(String gifticonId) async {
    if (!kIsWeb && Platform.isWindows) return;
    
    final settings = await _settingsRepository.getNotificationSettings();
    // 설정된 모든 알림 시점에 대해 취소 시도
    for (final alert in settings.alerts) {
      final notificationId = _generateNotificationId(gifticonId, alert.daysBefore);
      await _localNotificationsPlugin.cancel(id: notificationId);
    }
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

