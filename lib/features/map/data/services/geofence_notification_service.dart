import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/models/store_model.dart';

class GeofenceNotificationService {
  static final GeofenceNotificationService _instance = GeofenceNotificationService._internal();
  factory GeofenceNotificationService() => _instance;
  GeofenceNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

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

    // 3. Geofencing API 설정 (배터리 최적화 포함)
    Geofencing.instance.setup(
      interval: 10000, // 10초마다 위치 갱신
      accuracy: 100, // Balanced accuracy
      statusChangeDelay: 5000,
      allowsMockLocation: false,
    );

    // 4. 상태 변경 리스너 등록
    Geofencing.instance.addGeofenceStatusChangedListener((GeofenceRegion region, GeofenceStatus status, Location location) async {
      if (status == GeofenceStatus.enter) {
        // 알림 발송!
        // region.data에 우리가 넣은 StoreModel.placeName이 있다면 활용 가능
        String storeName = region.data as String? ?? '기프티콘 사용처';
        
        await showNotification(
          '근처에 매장이 있어요! 🎁',
          '$storeName 근처입니다. 보관함의 기프티콘을 사용해 보세요!',
        );
      }
    });
  }

  Future<void> showNotification(String title, String body) async {
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
      id: DateTime.now().millisecond,
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
        radius: 100.0, // 반경 100m
      );
      regions.add(region);
    }

    try {
      // 새로운 지오펜스로 시작
      await Geofencing.instance.start(regions: regions);
    } catch (e) {
      print('Geofencing start error: $e');
    }
  }
}
