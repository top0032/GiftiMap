import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/models/store_model.dart';

class GeofenceNotificationService {
  static final GeofenceNotificationService _instance = GeofenceNotificationService._internal();
  factory GeofenceNotificationService() => _instance;
  GeofenceNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // 알림 중복 방지: 동일 매장에 대해서는 10분 동안 다시 알리지 않음
  final Map<String, DateTime> _lastNotificationTimes = {};
  static const Duration _notificationCooldown = Duration(minutes: 10);

  Future<void> initialize() async {
    // 1. 알림 플러그인 초기화
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotificationsPlugin.initialize(settings: initializationSettings);

    // 2. 안드로이드 알림 권한 및 위치 권한 요청
    await Permission.notification.request();
    await Permission.locationAlways.request();

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
        final storeId = region.id;
        final now = DateTime.now();
        
        // 쿨타임 체크: 10분 이내에 알림을 보낸 적이 있다면 무시
        if (_lastNotificationTimes.containsKey(storeId)) {
          final lastTime = _lastNotificationTimes[storeId]!;
          if (now.difference(lastTime) < _notificationCooldown) {
            print('Notification skipped for $storeId (cooldown)');
            return;
          }
        }

        String storeName = region.data as String? ?? '기프티콘 사용처';
        
        _lastNotificationTimes[storeId] = now; // 시간 갱신
        await showNotification(
          region.hashCode,
          '근처에 매장이 있어요! 🎁',
          '$storeName 근처입니다. 보관함의 기프티콘을 사용해 보세요!',
        );
      }
    });
  }

  Future<void> showNotification(int id, String title, String body) async {
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

  Future<void> setupGeofences(List<StoreModel> stores) async {
    // 이미 실행 중이라면 중지
    if (Geofencing.instance.isRunningService) {
      await Geofencing.instance.stop();
    }

    // 조건부 실행: 매장이 없으면 백그라운드 서비스 시작하지 않음 (배터리 최적화)
    if (stores.isEmpty) return;

    // 최대 10개 매장 제한 (배터리 최적화)
    final targetStores = stores.take(10).toList();
    final Set<GeofenceRegion> regions = {};

    for (var store in targetStores) {
      final region = GeofenceRegion.circular(
        id: store.id,
        data: store.placeName, // 매장명을 data 필드에 저장하여 알림에 활용
        center: LatLng(store.latitude, store.longitude),
        radius: 200.0, // 반경 200m로 확대 (인식률 향상)
      );
      regions.add(region);
    }

    try {
      // 새로운 지오펜스로 시작
      await Geofencing.instance.start(regions: regions);
      print('Geofencing started with ${regions.length} regions');

      // [추가] 초기 실행 시 현재 위치가 이미 울타리 안인지 수동 체크
      final currentPos = await Geolocator.getCurrentPosition();
      for (var store in targetStores) {
        final distance = Geolocator.distanceBetween(
          currentPos.latitude, currentPos.longitude,
          store.latitude, store.longitude
        );
        
        if (distance <= 200.0) { 
           final storeId = store.id;
           final now = DateTime.now();

           // 여기서도 쿨타임 체크 (중복 알림 방지)
           if (_lastNotificationTimes.containsKey(storeId)) {
             final lastTime = _lastNotificationTimes[storeId]!;
             if (now.difference(lastTime) < _notificationCooldown) continue;
           }

           print('User is already inside ${store.placeName} (Distance: ${distance.toInt()}m)');
           _lastNotificationTimes[storeId] = now;
           await showNotification(
             store.id.hashCode,
             '근처에 매장이 있어요! 🎁',
             '${store.placeName} 근처입니다. 보관함의 기프티콘을 사용해 보세요!',
           );
           break; 
        }
      }
    } catch (e) {
      print('Geofencing start error: $e');
    }
  }
}
