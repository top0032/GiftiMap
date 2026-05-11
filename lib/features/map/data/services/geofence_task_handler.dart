import 'dart:isolate';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 추가
import 'geofence_notification_service.dart';
import 'kakao_local_api_service.dart'; // 추가

/// 백그라운드에서 실행될 작업 핸들러입니다.
class GeofenceTaskHandler extends TaskHandler {
  SendPort? _sendPort;
  SharedPreferences? _prefs;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;
    print('--- GeofenceTaskHandler Started ---');

    // 백그라운드 아이솔레이트에서도 Flutter 바인딩 초기화 필수
    WidgetsFlutterBinding.ensureInitialized();

    // 서비스 초기화 (백그라운드 모드)
    final service = GeofenceNotificationService();
    await service.initialize(isBackground: true);

    // 백그라운드 Isolate에서도 환경변수 로드 필수
    try {
      await dotenv.load(fileName: ".env");
      debugPrint('--- [Background] .env Loaded ---');
    } catch (e) {
      debugPrint('--- [Background] .env Load Error: $e ---');
    }

    _prefs = await SharedPreferences.getInstance();
    debugPrint('--- GeofenceTaskHandler: SharedPreferences Cached ---');
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // 5초마다 현재 위치 확인 (수동 지오펜싱)
    try {
      _prefs ??= await SharedPreferences.getInstance();

      // 1. 현재 위치 가져오기
      Position? currentPos;
      try {
        currentPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (e) {
        currentPos = await Geolocator.getLastKnownPosition();
      }

      if (currentPos == null) return;

      // 2. 이동 거리에 따른 주변 매장 목록 갱신 (필요 시)
      await _checkAndRefreshNearbyStores(currentPos);

      // 3. 갱신된 매장 목록 불러오기
      final storesJson = _prefs!.getString('geofence_target_stores');
      if (storesJson == null) return;
      final List<dynamic> stores = jsonDecode(storesJson);
      final radius = _prefs!.getDouble('geofence_radius') ?? 200.0;

      // [추가] 속도 기반 필터링
      final double speedKph = currentPos.speed * 3.6;
      if (speedKph > 30) return;

      // 거리 순으로 정렬하여 가장 가까운 매장부터 처리
      final List<Map<String, dynamic>> detectedStores = [];

      for (var store in stores) {
        final double storeLat = (store['lat'] as num).toDouble();
        final double storeLng = (store['lng'] as num).toDouble();

        final distance = Geolocator.distanceBetween(
          currentPos.latitude,
          currentPos.longitude,
          storeLat,
          storeLng,
        );

        if (distance <= radius) {
          store['distance'] = distance;
          detectedStores.add(Map<String, dynamic>.from(store));
        }
      }

      // 감지된 매장이 있다면 브랜드별로 가장 가까운 매장 하나씩만 선별
      if (detectedStores.isNotEmpty) {
        // 1. 브랜드별로 매장 그룹화
        final Map<String, Map<String, dynamic>> closestByBrand = {};

        for (var store in detectedStores) {
          final String brand = store['brand'] ?? 'unknown';
          final double distance = store['distance'] as double;

          if (!closestByBrand.containsKey(brand) ||
              distance < (closestByBrand[brand]!['distance'] as double)) {
            closestByBrand[brand] = store;
          }
        }

        // 2. 선별된 매장들에 대해 알림 발송
        for (var store in closestByBrand.values) {
          debugPrint(
            '--- [Background] Notification for closest ${store['brand']}: ${store['name']} ---',
          );
          await GeofenceNotificationService().showNotification(
            store['id'].hashCode,
            '근처에 매장이 있어요! 🎁',
            '${store['name']} 근처입니다. 보관함의 기프티콘을 사용해 보세요!',
            storeId: store['id'],
            brandName: store['brand'],
          );
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

  // --- [Private Methods] ---

  /// 마지막 검색 위치와 현재 위치를 비교하여 필요시 주변 매장을 다시 검색합니다.
  Future<void> _checkAndRefreshNearbyStores(Position currentPos) async {
    final double lastLat = _prefs!.getDouble('last_search_lat') ?? 0.0;
    final double lastLng = _prefs!.getDouble('last_search_lng') ?? 0.0;

    final distance = Geolocator.distanceBetween(
      currentPos.latitude,
      currentPos.longitude,
      lastLat,
      lastLng,
    );

    // 50m 이상 이동했거나 데이터가 아예 없는 경우 재검색 (시연용 초고감도)
    if (distance > 50 || (lastLat == 0.0 && lastLng == 0.0)) {
      debugPrint(
        '--- [Background] User moved $distance m. Refreshing stores... ---',
      );

      final brandsJson = _prefs!.getString('geofence_target_brands');
      if (brandsJson == null) return;

      final List<dynamic> brands = jsonDecode(brandsJson);
      if (brands.isEmpty) return;

      final apiService = KakaoLocalApiService();
      final List<dynamic> allNewStores = [];

      for (String brand in brands) {
        try {
          final stores = await apiService.searchNearbyStores(
            brandName: brand,
            latitude: currentPos.latitude,
            longitude: currentPos.longitude,
            radius: 5000, // 백그라운드 검색 반경 확대 (5km)
          );

          // 매장이 아닌 장소 제외 필터링 (메인 화면과 동일 로직)
          final excludeKeywords = [
            '주차장',
            'ATM',
            '무인택배',
            '물류',
            '본사',
            '사무소',
            '센터',
            '창고',
          ];
          final filtered = stores.where(
            (s) => !excludeKeywords.any((k) => s.placeName.contains(k)),
          );

          for (var s in filtered) {
            allNewStores.add({
              'id': s.id,
              'name': s.placeName,
              'brand': s.matchedBrand, // 브랜드 정보 추가
              'lat': s.latitude,
              'lng': s.longitude,
            });
          }
        } catch (e) {
          debugPrint('--- [Background Search Error] Brand $brand: $e ---');
        }
      }

      // --- [개선] 브랜드별 최단 거리 매장 하나만 선별 ---
      final Map<String, Map<String, dynamic>> finalStoresByBrand = {};
      for (var s in allNewStores) {
        final String brand = s['brand'];
        final double d = Geolocator.distanceBetween(
          currentPos.latitude,
          currentPos.longitude,
          s['lat'],
          s['lng'],
        );

        if (!finalStoresByBrand.containsKey(brand) ||
            d < finalStoresByBrand[brand]!['distance']) {
          s['distance'] = d;
          finalStoresByBrand[brand] = {
            'store': s,
            'distance': d,
          };
        }
      }

      final List<dynamic> limitedStores = finalStoresByBrand.values
          .map((v) => v['store'])
          .take(10) // 최대 10개 브랜드로 제한
          .toList();

      await _prefs!.setString(
        'geofence_target_stores',
        jsonEncode(limitedStores),
      );
      await _prefs!.setDouble('last_search_lat', currentPos.latitude);
      await _prefs!.setDouble('last_search_lng', currentPos.longitude);

      debugPrint(
        '--- [Background] Refresh Done: Found ${limitedStores.length} stores ---',
      );

      // --- [추가] 즉시 근접 체크 (지오펜싱 대기 없이 루프에서 즉시 알림) ---
      // 브랜드별로 최단 거리 매장 하나만 선별
      final Map<String, Map<String, dynamic>> nearestByBrand = {};

      for (var store in limitedStores) {
        final String brand = store['brand'];
        final double sLat = store['lat'];
        final double sLng = store['lng'];

        final double d = Geolocator.distanceBetween(
          currentPos.latitude,
          currentPos.longitude,
          sLat,
          sLng,
        );

        // 200m 이내인 경우만 고려
        if (d <= 200) {
          if (!nearestByBrand.containsKey(brand) ||
              d < nearestByBrand[brand]!['distance']) {
            nearestByBrand[brand] = {
              'store': store,
              'distance': d,
            };
          }
        }
      }

      // 선별된 브랜드별 최단 거리 매장에 대해 알림 발송 (이미 200m 이내인 경우)
      final notiService = GeofenceNotificationService();
      for (var data in finalStoresByBrand.values) {
        final store = data['store'];
        final distance = data['distance'];

        if (distance <= 200) {
          debugPrint('--- [Background Noti Trigger] Brand: ${store['brand']}, Dist: ${distance}m ---');
          
          await notiService.showNotification(
            store['brand'].hashCode, // 브랜드별 고유 ID (덮어쓰기 보장)
            '${store['brand']} 근처입니다.',
            '${store['name']}이(가) 가까이 있습니다. 기프티콘을 확인하세요!',
            storeId: store['id'],
            brandName: store['brand'],
          );
        }
      }
    }
  }

  @override
  void onNotificationPressed() {
    // 알림 클릭 시 앱으로 진입
    FlutterForegroundTask.launchApp();
  }
}
