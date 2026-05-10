import 'dart:isolate';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'geofence_notification_service.dart';

/// 백그라운드에서 실행될 작업 핸들러입니다.
class GeofenceTaskHandler extends TaskHandler {
  SendPort? _sendPort;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;
    print('--- GeofenceTaskHandler Started ---');

    // 백그라운드 아이솔레이트에서도 Flutter 바인딩 초기화 필수
    WidgetsFlutterBinding.ensureInitialized();

    // 서비스 초기화 (백그라운드 모드)
    final service = GeofenceNotificationService();
    await service.initialize(isBackground: true);
    print('--- GeofenceNotificationService Initialized in Background ---');
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // 5초마다 현재 위치 확인 (수동 지오펜싱)
    try {
      final prefs = await SharedPreferences.getInstance();
      final storesJson = prefs.getString('geofence_target_stores');
      if (storesJson == null) return;

      final List<dynamic> stores = jsonDecode(storesJson);
      if (stores.isEmpty) return;

      final radius = prefs.getDouble('geofence_radius') ?? 200.0;

      // 1. 마지막으로 알려진 위치를 먼저 시도 (더 빠르고 안정적)
      Position? currentPos = await Geolocator.getLastKnownPosition();

      // 2. 만약 마지막 위치가 너무 오래되었거나 없다면 새로고침
      currentPos ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      final now = DateTime.now();
      final timeStr =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      // 상단 상주 알림 문구 업데이트 (최소 중요도이므로 알림창을 내려야 보입니다)
      FlutterForegroundTask.updateService(
        notificationTitle: '매장 탐색 서비스 작동 중',
        notificationText: '주변 매장을 탐색하고 있습니다.',
      );

      // [추가] 속도 기반 필터링: 시속 20km(약 5.5m/s) 이상이면 이동 수단 이용 중으로 간주
      final double speedKph = currentPos.speed * 3.6; // m/s -> km/h 변환
      if (speedKph > 20) {
        print('--- Speed too fast ($speedKph km/h): Skipping notifications ---');
        return;
      }

      print(
        '--- Background Check: ${currentPos.latitude}, ${currentPos.longitude} ---',
      );

      for (var store in stores) {
        // 명시적으로 double로 변환하여 계산 오류 방지
        final double storeLat = (store['lat'] as num).toDouble();
        final double storeLng = (store['lng'] as num).toDouble();

        final distance = Geolocator.distanceBetween(
          currentPos.latitude,
          currentPos.longitude,
          storeLat,
          storeLng,
        );

        if (distance <= radius) {
          print('--- Manual Geofence Triggered: ${store['name']} ---');
          // 알림 서비스 인스턴스를 통해 알림 발송 (중복 체크는 서비스 내에서 처리됨)
          await GeofenceNotificationService().showNotification(
            store['id'].hashCode,
            '근처에 매장이 있어요! 🎁',
            '${store['name']} 근처입니다. 보관함의 기프티콘을 사용해 보세요!',
            storeId: store['id'],
          );
          // break 제거: 주변에 여러 매장이 있을 경우 모두 알림을 보냅니다.
        }
      }
    } catch (e) {
      print('--- Background Check Error: $e ---');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    print('--- GeofenceTaskHandler Destroyed ---');
  }

  @override
  void onNotificationPressed() {
    // 알림 클릭 시 앱으로 진입
    FlutterForegroundTask.launchApp();
  }
}
