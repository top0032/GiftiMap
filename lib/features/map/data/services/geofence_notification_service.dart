import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    hide NotificationVisibility;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/store_model.dart';
import 'geofence_task_handler.dart';
import '../../../../core/services/background_callback.dart';

class GeofenceNotificationService {
  static final GeofenceNotificationService _instance =
      GeofenceNotificationService._internal();
  factory GeofenceNotificationService() => _instance;
  GeofenceNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 알림 중복 방지용 시간 저장 키
  static const String _lastNotificationPrefix = 'last_noti_time_';
  static const Duration _notificationCooldown = Duration(hours: 1);
  SharedPreferences? _prefs;

  // [추가] 메모리 기반 즉시 쿨타임 체크 (Race Condition 방지)
  static final Map<String, DateTime> _memoryCooldownMap = {};

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
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // 2. 안드로이드 알림 권한 요청 (포그라운드일 때만)
    if (!_isBackground) {
      await Permission.notification.request();
    }

    // 3. Geofencing API 설정 (시연용으로 민감도 최대로 상향)
    Geofencing.instance.setup(
      interval: 5000, // 5초마다 위치 갱신
      accuracy: 100,
      statusChangeDelay: 3000, // 3초 이상 머물러야 인식
      allowsMockLocation: true,
    );

    // 4. 상태 변경 리스너 등록
    Geofencing.instance.addGeofenceStatusChangedListener((
      GeofenceRegion region,
      GeofenceStatus status,
      Location location,
    ) async {
      debugPrint('Geofence status changed: ${region.id} - $status');

      if (status == GeofenceStatus.enter || status == GeofenceStatus.dwell) {
        // JSON 데이터 파싱 (매장명, 브랜드명)
        String storeName = '기프티콘 사용처';
        String? brandName;

        try {
          final Map<String, dynamic> data = jsonDecode(region.data as String);
          storeName = data['name'] ?? storeName;
          brandName = data['brand'];
        } catch (e) {
          storeName = region.data as String? ?? storeName;
        }

        await showNotification(
          region.hashCode,
          '근처에 매장이 있어요! 🎁',
          '$storeName 근처입니다. 보관함의 기프티콘을 사용해 보세요!',
          storeId: region.id,
          brandName: brandName, // 브랜드명 전달하여 쿨타임 적용
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
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
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
        interval: 5000, // 5초 간격으로 단축 (시연용 초고감도)
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> startForegroundService() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        debugPrint('--- Foreground Service is already running ---');
        return;
      }

      final result = await FlutterForegroundTask.startService(
        notificationTitle: 'GiftiMap 탐색 서비스 작동 중',
        notificationText: '주변 매장을 탐색하고 있습니다.',
        callback: startCallback,
      );
      debugPrint('--- Foreground Service Start Result: $result ---');
    } catch (e) {
      debugPrint('--- Foreground Service Start Error: $e ---');
    }
  }

  Future<void> stopForegroundService() async {
    await FlutterForegroundTask.stopService();
  }

  Future<void> showNotification(
    int id,
    String title,
    String body, {
    String? storeId,
    String? brandName,
  }) async {
    if (!kIsWeb && Platform.isWindows) return;

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final now = DateTime.now();

    // 0. 메모리 기반 즉시 중복 차단 (10초 내 동일 브랜드/매장 요청 무시)
    final String memKey = brandName ?? storeId ?? 'unknown';
    if (_memoryCooldownMap.containsKey(memKey)) {
      final lastTime = _memoryCooldownMap[memKey]!;
      if (now.difference(lastTime) < const Duration(seconds: 10)) {
        return;
      }
    }
    _memoryCooldownMap[memKey] = now;

    // 1. 브랜드 기반 쿨타임 체크 (가장 넓은 범위)
    int finalNotiId = id; // 기본 ID
    if (brandName != null) {
      // 브랜드 이름을 정규화 (대문자 변환 및 공백 제거) 하여 일관성 유지
      final String normalizedBrand = brandName.trim().toUpperCase();
      
      // 브랜드별로 알림 ID를 고정하여, 새로운 알림이 기존 알림을 덮어쓰도록 함 (Overwrite)
      finalNotiId = normalizedBrand.hashCode;
      
      final brandKey = 'last_brand_noti_$normalizedBrand';
      final lastBrandTimeStr = prefs.getString(brandKey);
      if (lastBrandTimeStr != null) {
        final lastTime = DateTime.parse(lastBrandTimeStr);
        if (now.difference(lastTime) < const Duration(minutes: 30)) {
          debugPrint(
            '--- [Notification Skipped] Brand $brandName is in cooldown ---',
          );
          return;
        }
      }
      await prefs.setString(brandKey, now.toIso8601String());
    }

    // 2. 매장 ID 기반 쿨타임 체크 (특정 지점)
    if (storeId != null) {
      final key = '$_lastNotificationPrefix$storeId';
      final lastTimeStr = prefs.getString(key);
      if (lastTimeStr != null) {
        final lastTime = DateTime.parse(lastTimeStr);
        if (now.difference(lastTime) < _notificationCooldown) {
          debugPrint(
            '--- [Notification Skipped] Store $storeId is in cooldown ---',
          );
          return;
        }
      }
      await prefs.setString(key, now.toIso8601String());
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'giftimap_geofence_channel',
          'Geofence Notifications',
          channelDescription: '주변 매장 접근 시 알림을 보냅니다.',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          ticker: '주변 매장 접근 알림',
          category:
              AndroidNotificationCategory.message, // 메시지 카테고리로 지정하여 우선순위 상향
          visibility: NotificationVisibility.public, // 잠금 화면에서도 내용 표시
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await _localNotificationsPlugin.show(
      id: finalNotiId, // 브랜드별 고유 ID 사용 (동일 브랜드 알림 덮어쓰기)
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  /// [시연용] 모든 알림 쿨타임 초기화
  Future<void> clearAllCooldowns() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // 다른 Isolate와의 동기화 강제
    
    // 1. SharedPreferences의 모든 쿨타임 키 삭제
    final keys = prefs.getKeys();
    final List<String> keysToRemove = [];
    
    for (String key in keys) {
      if (key.startsWith(_lastNotificationPrefix) || 
          key.startsWith('last_brand_noti_')) {
        keysToRemove.add(key);
      }
    }
    
    for (String key in keysToRemove) {
      await prefs.remove(key);
    }
    
    // 2. 메모리 쿨타임 비우기
    _memoryCooldownMap.clear();
    
    debugPrint('--- [Demonstration] All Notification Cooldowns Cleared! ---');
  }

  Future<void> setupGeofences(
    List<StoreModel> stores, {
    required List<String> brandNames,
    double radius = 200.0,
  }) async {
    // Windows에서는 지오펜싱 기능을 지원하지 않으므로 종료
    if (!kIsWeb && Platform.isWindows) return;

    // 이미 실행 중이라면 중지
    if (Geofencing.instance.isRunningService) {
      await Geofencing.instance.stop();
    }

    // 조건부 실행: 매장도 없고 추적할 브랜드도 없으면 백그라운드 서비스 시작하지 않음
    if (stores.isEmpty && brandNames.isEmpty) return;

    // 최대 10개 매장 제한 (배터리 최적화)
    final targetStores = stores.take(10).toList();

    // [추가] 백그라운드 엔진 공유용 매장 데이터 저장
    final prefs = await SharedPreferences.getInstance();
    final storesJson = targetStores
        .map(
          (s) => {
            'id': s.id,
            'name': s.placeName,
            'brand': s.matchedBrand, // 브랜드명 추가
            'lat': s.latitude,
            'lng': s.longitude,
          },
        )
        .toList();
    await prefs.setString('geofence_target_stores', jsonEncode(storesJson));
    await prefs.setString(
      'geofence_target_brands',
      jsonEncode(brandNames),
    ); // 브랜드 목록 저장
    await prefs.setDouble('geofence_radius', radius);

    final Set<GeofenceRegion> regions = {};

    for (var store in targetStores) {
      final region = GeofenceRegion.circular(
        id: store.id,
        data: jsonEncode({
          'name': store.placeName,
          'brand': store.matchedBrand,
        }), // 매장명과 브랜드명을 함께 저장
        center: LatLng(store.latitude, store.longitude),
        radius: radius,
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
          currentPos.latitude,
          currentPos.longitude,
          store.latitude,
          store.longitude,
        );

        if (distance <= radius) {
          // 초기 체크 시에도 브랜드명 전달하여 중복 알림 방지 및 덮어쓰기 적용
          await showNotification(
            store.id.hashCode,
            '근처에 매장이 있어요! 🎁',
            '${store.placeName} 근처입니다. 보관함의 기프티콘을 사용해 보세요!',
            storeId: store.id,
            brandName: store.matchedBrand, // [수정] 브랜드명 전달 필수
          );
        }
      }
    } catch (e) {
      print('Geofencing start error: $e');
    }
  }
}
