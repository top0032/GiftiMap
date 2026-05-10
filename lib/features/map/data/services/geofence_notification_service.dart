import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/store_model.dart';
import 'geofence_task_handler.dart';
import '../../../../core/services/background_callback.dart';

class GeofenceNotificationService {
  static final GeofenceNotificationService _instance = GeofenceNotificationService._internal();
  factory GeofenceNotificationService() => _instance;
  GeofenceNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // 알림 중복 방지용 시간 저장 키
  static const String _lastNotificationPrefix = 'last_noti_time_';
  static const Duration _notificationCooldown = Duration(hours: 1);

  bool _isInitialized = false;
  bool _isBackground = false;

  Future<void> initialize({bool isBackground = false}) async {
    if (_isInitialized) return;
    _isBackground = isBackground;
    // Windows 플랫폼에서는 알림 기능을 지원하지 않거나 설정이 다르므로 건너뜜.
    if (!kIsWeb && Platform.isWindows) {
      debugPrint('Windows 플랫폼에서는 알림 초기화를 건너뜜');
      return;
    }

    // 1. 알림 플러그인 초기화
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotificationsPlugin.initialize(settings: initializationSettings);

    // 2. 안드로이드 알림 권한 및 위치 권한 요청 (포그라운드일 때만)
    if (!_isBackground) {
      await Permission.notification.request();
      await Permission.locationAlways.request();
    }

    // 3. Geofencing API 설정 (배터리 및 빈도 최적화)
    Geofencing.instance.setup(
      interval: 15000, // 15초마다 위치 갱신 (너무 잦은 알림 방지)
      accuracy: 100, 
      statusChangeDelay: 10000, // 10초 이상 머물러야 인식 (오인식 방지)
      allowsMockLocation: true,
    );

    // 4. 상태 변경 리스너 등록
    Geofencing.instance.addGeofenceStatusChangedListener((GeofenceRegion region, GeofenceStatus status, Location location) async {
      print('Geofence status changed: ${region.id} - $status');
      
      if (status == GeofenceStatus.enter || status == GeofenceStatus.dwell) {
        // 쿨타임 체크는 이제 showNotification 내부에서 수행함
        String storeName = region.data as String? ?? '기프티콘 사용처';
        
        await showNotification(
          region.hashCode,
          '근처에 매장이 있어요! 🎁',
          '$storeName 근처입니다. 보관함의 기프티콘을 사용해 보세요!',
          storeId: region.id, // 매장 ID 전달
        );
      }
    });

    _isInitialized = true;
    
    // 포그라운드 서비스 초기화 (메인 아이솔레이트에서만 수행)
    if (!kIsWeb && !Platform.isWindows) {
      _initForegroundTask();
    }
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'giftimap_foreground_service',
        channelName: 'GiftiMap Background Service',
        channelDescription: '지오펜싱 및 위치 추적을 위한 서비스입니다.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 10000, // 10초 간격으로 단축 (이동 시 감지 확률 업)
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> startForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    await FlutterForegroundTask.startService(
      notificationTitle: '매장 탐색 서비스 작동 중',
      notificationText: '주변 매장을 탐색하고 있습니다.',
      callback: startCallback,
    );
  }

  Future<void> stopForegroundService() async {
    await FlutterForegroundTask.stopService();
  }

  Future<void> showNotification(int id, String title, String body, {String? storeId}) async {
    if (!kIsWeb && Platform.isWindows) return;

    // 매장 ID가 있다면 쿨타임 체크 (저장소 기반 영구 유지)
    if (storeId != null) {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_lastNotificationPrefix$storeId';
      final lastTimeStr = prefs.getString(key);
      final now = DateTime.now();

      if (lastTimeStr != null) {
        final lastTime = DateTime.parse(lastTimeStr);
        if (now.difference(lastTime) < _notificationCooldown) {
          print('--- [Notification Skipped] Store $storeId is in cooldown ---');
          return;
        }
      }
      // 현재 시간 저장
      await prefs.setString(key, now.toIso8601String());
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'giftimap_geofence_channel',
      'Geofence Notifications',
      channelDescription: '주변 매장 접근 시 알림을 보냅니다.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await _localNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> setupGeofences(List<StoreModel> stores, {double radius = 200.0}) async {
    // Windows에서는 지오펜싱 기능을 지원하지 않으므로 종료
    if (!kIsWeb && Platform.isWindows) return;

    // 이미 실행 중이라면 중지
    if (Geofencing.instance.isRunningService) {
      await Geofencing.instance.stop();
    }

    // 조건부 실행: 매장이 없으면 백그라운드 서비스 시작하지 않음 (배터리 최적화)
    if (stores.isEmpty) return;

    // 최대 10개 매장 제한 (배터리 최적화)
    final targetStores = stores.take(10).toList();
    
    // [추가] 백그라운드 엔진 공유용 매장 데이터 저장
    final prefs = await SharedPreferences.getInstance();
    final storesJson = targetStores.map((s) => {
      'id': s.id,
      'name': s.placeName,
      'lat': s.latitude,
      'lng': s.longitude,
    }).toList();
    await prefs.setString('geofence_target_stores', jsonEncode(storesJson));
    await prefs.setDouble('geofence_radius', radius);

    final Set<GeofenceRegion> regions = {};

    for (var store in targetStores) {
      final region = GeofenceRegion.circular(
        id: store.id,
        data: store.placeName, // 매장명을 data 필드에 저장하여 알림에 활용
        center: LatLng(store.latitude, store.longitude),
        radius: radius, // 설정된 반경 사용 (기본 200m)
      );
      regions.add(region);
    }

    try {
      // 새로운 지오펜스로 시작
      await Geofencing.instance.start(regions: regions);
      print('Geofencing started with ${regions.length} regions');

      // 포그라운드 서비스 시작 (앱 종료 대비)
      await startForegroundService();

      // 2. 만약 마지막 위치가 너무 오래되었거나 없다면 새로고침
      Position? currentPos;
      try {
        currentPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (e) {
        print('--- Background Location Fetch Timeout/Error: $e ---');
        // 위치 획득 실패 시 이번 회차는 스킵하고 다음 10초 뒤를 기약함
        return;
      }
      
      for (var store in targetStores) {
        final distance = Geolocator.distanceBetween(
          currentPos.latitude, currentPos.longitude,
          store.latitude, store.longitude
        );
        
        if (distance <= radius) { 
          // 초기 체크 시에도 지점별 쿨타임과 알림 로직 통합 호출
          await showNotification(
            store.id.hashCode,
            '근처에 매장이 있어요! 🎁',
            '${store.placeName} 근처입니다. 보관함의 기프티콘을 사용해 보세요!',
            storeId: store.id,
          );
        }
      }
    } catch (e) {
      print('Geofencing start error: $e');
    }
  }
}
