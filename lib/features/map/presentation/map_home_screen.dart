import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/theme.dart';
import '../data/services/kakao_local_api_service.dart';
import '../data/services/geofence_notification_service.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../domain/models/store_model.dart';
import '../../gifticon/presentation/providers/gifticon_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../settings/presentation/providers/settings_provider.dart';
import '../../../core/services/security_service.dart';
import '../../../core/utils/map_launcher.dart';

class MapHomeScreen extends ConsumerStatefulWidget {
  const MapHomeScreen({super.key});

  @override
  ConsumerState<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends ConsumerState<MapHomeScreen>
    with WidgetsBindingObserver {
  KakaoMapController? _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  StreamSubscription<Position>? _positionSubscription; // 위치 스트림 구독 추가
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isSearchingStores = false;
  bool _showStores = true;
  String? _selectedStoreId;
  List<StoreModel> _nearbyStores = [];
  final KakaoLocalApiService _apiService = KakaoLocalApiService();
  String? _selectedFilterBrand; // 브랜드 필터 상태 추가
  StoreModel? _selectedStore; // 선택된 매장 정보 추가
  bool _showQuickRoute = false; // 빠른 길찾기 오버레이 표시 여부

  bool _showNotice = false;
  String _noticeText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 옵저버 등록
    _determinePosition();
    _initGeofencing();
    _startPositionUpdates(); // 실시간 위치 업데이트 시작

    // 최초 실행 시 권한 및 최적화 체크
    _checkPermissionsStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 옵저버 해제
    _positionSubscription?.cancel(); // 위치 구독 해제
    _sheetController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 설정 화면에서 돌아왔을 때(Resumed) 권한 다시 체크
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsStatus();
    }
  }

  Future<void> _checkPermissionsStatus() async {
    final locationStatus = await Permission.locationAlways.status;
    final batteryIgnored =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;

    if (!locationStatus.isGranted || !batteryIgnored) {
      if (mounted) {
        setState(() {
          _showNotice = true;
          _noticeText = "📍위치 '항상 허용' | 🔋배터리 '제한 없음' 설정 시 알림을 받을 수 있어요 (클릭)";
        });
      }
    } else {
      if (mounted) {
        setState(() => _showNotice = false);
      }
    }
  }

  Future<void> _initGeofencing() async {
    // 1. 알림 권한 요청
    await Permission.notification.request();
    
    // 2. 기본 위치 권한 요청 (앱 사용 중 허용)
    await Permission.location.request();

    // 3. 서비스 초기화 및 시작 시도
    await GeofenceNotificationService().initialize();
    
    if (_currentPosition != null) {
      _fetchNearbyStores();
    }
  }

  Future<void> _determinePosition() async {
    // ... 기존 코드와 동일 ...
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
        });
        _fetchNearbyStores();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// [추가] 실시간 위치 변화 감지 및 자동 재탐색
  void _startPositionUpdates() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // 50m 이상 이동 시 이벤트 발생 (시연용 고감도)
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        
        // 위치가 바뀌면 주변 매장 새로고침 및 지오펜싱 업데이트
        _fetchNearbyStores();
        
        debugPrint('--- [Foreground] Position Updated: ${position.latitude}, ${position.longitude} ---');
      }
    });
  }

  Future<void> _fetchNearbyStores() async {
    // ... 기존 코드와 동일 ...
    if (_currentPosition == null) return;

    setState(() => _isSearchingStores = true);

    final gifticonState = ref.read(gifticonListProvider);
    if (!gifticonState.hasValue || gifticonState.value!.isEmpty) {
      if (mounted) {
        setState(() {
          _nearbyStores = [];
          _isSearchingStores = false;
        });
      }
      return;
    }

    final gifticons = gifticonState.value!;
    final brandNames = gifticons
        .where((g) => g.isUsed != true)
        .map((g) => g.brandName.trim())
        .where((brand) => brand != '알 수 없는 브랜드' && brand.isNotEmpty)
        .toSet()
        .toList();

    List<StoreModel> allStores = [];
    for (String? brand in brandNames) {
      if (brand == null) continue;
      final stores = await _apiService.searchNearbyStores(
        brandName: brand,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radius: 1000,
      );
      allStores.addAll(stores);
    }

    // 매장이 아닌 장소(주차장, ATM, 물류센터 등) 제외 키워드
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

    final filteredStores = allStores.where((store) {
      // 1. 제외 키워드가 포함되어 있는지 확인
      final isNotStore = excludeKeywords.any(
        (keyword) => store.placeName.contains(keyword),
      );

      // 2. 해당 브랜드의 사용 가능한 기프티콘이 있는지 확인
      final hasGifticon = gifticons.any(
        (g) => g.brandName == store.matchedBrand && g.isUsed != true,
      );

      return !isNotStore && hasGifticon;
    }).toList();

    filteredStores.sort((a, b) => a.distance.compareTo(b.distance));

    // 설정에서 지오펜싱 반경 가져오기
    final settings = ref.read(settingsControllerProvider).value;
    final radius = settings?.geofenceRadius ?? 200.0;

    await GeofenceNotificationService().setupGeofences(
      filteredStores,
      brandNames: brandNames.whereType<String>().toList(),
      radius: radius,
    );

    // [추가] 매장이 당장 없더라도 기프티콘이 있다면 포그라운드 서비스 강제 시작
    if (brandNames.isNotEmpty) {
      await GeofenceNotificationService().startForegroundService();
    }

    if (mounted) {
      setState(() {
        _nearbyStores = filteredStores;
        _isSearchingStores = false;
      });
    }
  }

  ScrollController? _innerScrollController;

  Future<void> _moveToStore(StoreModel store) async {
    if (mounted) {
      setState(() {
        _selectedStoreId = store.id;
      });
    }
    if (_mapController != null) {
      // 1. 내부 리스트 스크롤을 맨 위로 초기화
      _innerScrollController?.jumpTo(0);

      // 2. 패널을 최소 높이로 축소 (지도를 가리지 않게)
      if (_sheetController.isAttached) {
        await _sheetController.animateTo(
          0.11,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      // 3. 지도 중심 이동
      await _mapController!.setCenter(LatLng(store.latitude, store.longitude));
    }
  }

  // [복구] 마커 탭 핸들러
  void _onMarkerTapped(StoreModel store) {
    setState(() {
      _selectedStore = store;
      _selectedStoreId = store.id;
      _showQuickRoute = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Provider의 상태 변화를 구독 (기프티콘 추가/삭제 시 재검색 유도)
    ref.listen(gifticonListProvider, (previous, next) {
      if (next.hasValue && _currentPosition != null) {
        _fetchNearbyStores();
      }
    });

    List<Marker> mapMarkers = [];
    if (_currentPosition != null) {
      // 내 위치 마커
      mapMarkers.add(
        Marker(
          markerId: 'my_location',
          latLng: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          markerImageSrc:
              'https://t1.daumcdn.net/localimg/localimages/07/mapapidoc/marker_red.png',
        ),
      );

      // 검색된 주변 매장 마커
      final gifticons = ref.read(gifticonListProvider).value ?? [];
      final Set<String> existingIds = {'my_location'};

      for (var store in _nearbyStores) {
        if (existingIds.contains(store.id)) continue;

        // 1. 특정 매장이 선택된 경우, 그 매장이 아니면 무시
        if (_selectedStoreId != null && store.id != _selectedStoreId) {
          continue;
        }

        // 2. 브랜드 필터가 설정된 경우, 해당 브랜드가 아니면 무시
        if (_selectedFilterBrand != null &&
            store.matchedBrand != _selectedFilterBrand) {
          continue;
        }

        // 3. 특정 매장이 선택되지 않았고, 발견(showStores) 상태도 아니면 무시
        if (_selectedStoreId == null && !_showStores) {
          continue;
        }

        existingIds.add(store.id);

        final safePlaceName = store.placeName
            .replaceAll("'", "\\'")
            .replaceAll('"', '&quot;');

        final matchedCount = gifticons
            .where((g) => g.brandName == store.matchedBrand && g.isUsed != true)
            .length;

        final infoText = matchedCount > 0
            ? '$safePlaceName ($matchedCount개)'
            : safePlaceName;

        // 선택된 매장일 경우 파란색(기본), 아니면 별모양? 사용자가 '딱 그 매장만' 나오게 해달라고 했으므로
        // 굳이 별 모양이 필요 없고 그냥 마커만 보여주면 됨.
        mapMarkers.add(
          Marker(
            markerId: store.id,
            latLng: LatLng(store.latitude, store.longitude),
            infoWindowContent:
                '<div style="padding:10px; min-width:150px; text-align:center;">'
                '<div style="font-weight:bold; font-size:14px; margin-bottom:4px; color:#1A237E;">$infoText</div>'
                '<div style="font-size:11px; color:#666;">기프티콘 사용 가능 매장</div>'
                '</div>',
          ),
        );
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. 전체 지도 배경
          Positioned.fill(
            child: _isLoading
                ? Container(
                    color: AppTheme.backgroundLight,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                  )
                : _currentPosition == null
                ? Container(
                    color: AppTheme.backgroundLight,
                    child: const Center(child: Text('위치를 불러올 수 없습니다.')),
                  )
                : KakaoMap(
                    onMapCreated: (controller) => _mapController = controller,
                    onMarkerTap: (markerId, latLng, zoomLevel) {
                      // 마커 클릭 시 해당 위치로 중심 이동 및 선택 상태 업데이트
                      if (markerId != 'my_location') {
                        _mapController?.setCenter(latLng);
                        
                        // [복구] 선택된 매장 정보 찾기 및 오버레이 표시
                        final store = _nearbyStores.firstWhere((s) => s.id == markerId);
                        _onMarkerTapped(store);
                      }
                    },
                    center: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    markers: mapMarkers.isEmpty ? null : mapMarkers,
                  ),
          ),

          // 2. 상단 레이더 배지 및 프로필
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RadarBadge(
                      isSearching: _isSearchingStores,
                      storeCount: _nearbyStores.length,
                      isExpanded: _showStores,
                      onToggle: () {
                        setState(() {
                          _showStores = !_showStores;
                          _selectedStoreId = null; // 레이더 배지 토글 시 선택 초기화
                        });
                      },
                      onReset: () async {
                        // [시연용] 모든 쿨타임 초기화
                        await GeofenceNotificationService().clearAllCooldowns();
                        
                        // 즉시 지오펜싱 및 알림 체크 다시 수행
                        if (_currentPosition != null) {
                          _fetchNearbyStores();
                        }

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('시연용: 쿨타임 초기화 및 즉시 재탐색 수행'),
                              duration: Duration(seconds: 1),
                              backgroundColor: AppTheme.primaryTeal,
                            ),
                          );
                        }
                      },
                    ),
                    _ProfileButton(),
                  ],
                ),
              ),
            ),
          ),

          // 3. 내 위치 버튼 (바텀 시트 바로 위에 배치)
          Positioned(
            bottom: 100, // 스와이프 패널의 최소 높이보다 살짝 위
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: AppTheme.surfaceWhite,
              elevation: 4,
              child: const Icon(Icons.my_location, color: AppTheme.primaryTeal),
              onPressed: () {
                if (_currentPosition != null && _mapController != null) {
                  setState(() {
                    _selectedStoreId = null; // 내 위치로 돌아갈 때 선택 초기화
                  });
                  _mapController!.setCenter(
                    LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                  );
                  _fetchNearbyStores();
                } else {
                  _determinePosition();
                }
              },
            ),
          ),

          // 4. 스와이프 가능한 주변 가맹점 패널 (네비게이션 바 위에서 시작)
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.11, // 최소 높이
            minChildSize: 0.11,
            maxChildSize: 0.7, // 좀 더 시원하게 볼 수 있도록 최대 높이 확대
            snap: true,
            snapSizes: const [0.11, 0.7],
            builder: (context, scrollController) {
              _innerScrollController = scrollController;
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 드래그 핸들 (가로 막대기)
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 실제 내용 영역 (ListView를 사용하여 드래그 연동 안정화)
                    Expanded(
                      child: _NearbyGifticonPanel(
                        stores: _nearbyStores,
                        isSearching: _isSearchingStores,
                        ref: ref,
                        onStoreTap: _moveToStore,
                        scrollController: scrollController,
                        selectedFilterBrand: _selectedFilterBrand,
                        onFilterChanged: (brand) {
                          setState(() {
                            _selectedFilterBrand = brand;
                            _selectedStoreId = null; // 필터 변경 시 개별 매장 선택 해제
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // 하단 안내 배너 (설정이 필요할 때만 노출)
          if (_showNotice) _buildBottomNotice(),

          // 5. [복구] 빠른 길찾기 오버레이 (마커 클릭 시)
          if (_showQuickRoute && _selectedStore != null)
            Positioned(
              bottom: 120, // 바텀 시트 핸들 위쪽
              left: 20,
              right: 20,
              child: _buildQuickRouteOverlay(),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNotice() {
    return Positioned(
      bottom: 85, // 지도를 최대한 가리지 않게 하단으로 조정
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () async => await openAppSettings(),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: Colors.black.withOpacity(0.5), // 심플한 반투명 회색/검정 배경
          child: Text(
            _noticeText.replaceAll('\n', ' '), // 한 줄로 표시
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  /// [복구] 마커 클릭 시 나타나는 빠른 길찾기 카드
  Widget _buildQuickRouteOverlay() {
    if (_selectedStore == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryNavy,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedStore!.matchedBrand,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedStore!.placeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _showQuickRoute = false;
                    _selectedStoreId = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    MapLauncher.launchRoute(
                      lat: _selectedStore!.latitude,
                      lng: _selectedStore!.longitude,
                      name: _selectedStore!.placeName,
                    );
                  },
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('길찾기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RadarBadge extends StatelessWidget {
  final bool isSearching;
  final int storeCount;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onReset; // 초기화 콜백 추가

  const _RadarBadge({
    required this.isSearching,
    required this.storeCount,
    required this.isExpanded,
    required this.onToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isExpanded ? 16 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            isSearching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryTeal,
                    ),
                  )
                : const Icon(
                    Icons.radar_rounded,
                    color: AppTheme.primaryTeal,
                    size: 20,
                  ),
            if (isExpanded) ...[
              const SizedBox(width: 8),
              Text(
                isSearching ? '주변 가맹점 탐색 중...' : '가맹점 $storeCount곳 발견',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTheme.secondaryNavy,
                ),
              ),
              const SizedBox(width: 8),
              // [시연용] 초기화 버튼
              GestureDetector(
                onTap: () {
                  onReset();
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // authStateProvider를 감시하여 사용자 정보가 바뀌면 화면을 다시 그립니다.
    final user = ref.watch(authStateProvider).value;

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                // 프로필 이미지
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.primaryTeal.withOpacity(0.1),
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? const Icon(
                          Icons.person,
                          size: 40,
                          color: AppTheme.primaryTeal,
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                // 사용자 이름 (Consumer를 사용하여 팝업 내부에서도 실시간 업데이트)
                Consumer(
                  builder: (context, ref, child) {
                    final currentName =
                        ref.watch(displayNameProvider) ??
                        user?.displayName ??
                        '사용자';
                    print('[UI_CHECK] Inside Dialog Name: $currentName');
                    return Text(
                      currentName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryNavy,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                // 사용자 이메일
                Text(
                  user?.email ??
                      (user?.isAnonymous == true
                          ? '익명 계정 (카카오 연동됨)'
                          : '이메일 정보 없음'),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                const Divider(),
                // 앱 나가기 버튼
                ListTile(
                  leading: const Icon(
                    Icons.exit_to_app_rounded,
                    color: AppTheme.secondaryNavy,
                  ),
                  title: const Text(
                    '앱 나가기',
                    style: TextStyle(
                      color: AppTheme.secondaryNavy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    SystemNavigator.pop();
                  },
                ),
                // 로그아웃 버튼
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text(
                    '로그아웃',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(authControllerProvider.notifier).signOut();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '닫기',
                  style: TextStyle(color: AppTheme.secondaryNavy),
                ),
              ),
            ],
          ),
        );
      },
      child: CircleAvatar(
        backgroundColor: AppTheme.surfaceWhite,
        radius: 22,
        backgroundImage: user?.photoURL != null
            ? NetworkImage(user!.photoURL!)
            : null,
        child: user?.photoURL == null
            ? const Icon(Icons.person_rounded, color: AppTheme.secondaryNavy)
            : null,
      ),
    );
  }
}

class _NearbyGifticonPanel extends StatefulWidget {
  final List<StoreModel> stores;
  final bool isSearching;
  final WidgetRef ref;
  final Function(StoreModel)? onStoreTap;
  final ScrollController scrollController;
  final String? selectedFilterBrand; // 필터 상태 추가
  final Function(String?)? onFilterChanged; // 필터 변경 콜백 추가

  const _NearbyGifticonPanel({
    required this.stores,
    required this.isSearching,
    required this.ref,
    this.onStoreTap,
    required this.scrollController,
    this.selectedFilterBrand,
    this.onFilterChanged,
  });

  @override
  State<_NearbyGifticonPanel> createState() => _NearbyGifticonPanelState();
}

class _NearbyGifticonPanelState extends State<_NearbyGifticonPanel> {
  @override
  Widget build(BuildContext context) {
    // ref.watch를 사용하여 기프티콘 리스트 변화를 실시간으로 감시
    final gifticons = widget.ref.watch(gifticonListProvider).value ?? [];

    // 필터링할 브랜드 추출 (현재 찾은 매장들과 일치하는 내 기프티콘 브랜드들)
    final Set<String> availableBrands = {};
    if (!widget.isSearching && widget.stores.isNotEmpty) {
      for (var store in widget.stores) {
        final matched = gifticons.where(
          (g) => g.brandName == store.matchedBrand && g.isUsed != true,
        );
        if (matched.isNotEmpty) {
          availableBrands.add(store.matchedBrand);
        }
      }
    }

    // 선택된 브랜드에 따라 매장 필터링
    final displayedStores = widget.selectedFilterBrand == null
        ? widget.stores
        : widget.stores
              .where((s) => s.matchedBrand == widget.selectedFilterBrand)
              .toList();

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      // 시트가 최소 높이일 때도 드래그가 끊기지 않도록 설정
      physics: const ClampingScrollPhysics(),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.isSearching
                    ? '내 기프티콘 매장 찾는 중...'
                    : widget.stores.isEmpty
                    ? '반경 1km 내 사용 가능한 매장이 없습니다.'
                    : '내 주변 1km 이내 사용 가능한 매장 ${widget.stores.length}곳',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondaryNavy,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!widget.isSearching && widget.stores.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_walk_rounded,
                  color: AppTheme.primaryTeal,
                ),
              ),
          ],
        ),

        // 브랜드 필터 버튼 리스트
        if (!widget.isSearching && availableBrands.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // '전체' 버튼
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: const Text(
                      '전체',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    selected: widget.selectedFilterBrand == null,
                    onSelected: (selected) {
                      if (selected) {
                        widget.onFilterChanged?.call(null);
                      }
                    },
                    selectedColor: AppTheme.primaryTeal,
                    labelStyle: TextStyle(
                      color: widget.selectedFilterBrand == null
                          ? Colors.white
                          : AppTheme.secondaryNavy,
                    ),
                    backgroundColor: Colors.grey.shade100,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.transparent),
                    ),
                  ),
                ),
                // 각 브랜드별 버튼
                ...availableBrands.map(
                  (brand) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        brand,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      selected: widget.selectedFilterBrand == brand,
                      onSelected: (selected) {
                        widget.onFilterChanged?.call(selected ? brand : null);
                      },
                      selectedColor: AppTheme.primaryTeal,
                      labelStyle: TextStyle(
                        color: widget.selectedFilterBrand == brand
                            ? Colors.white
                            : AppTheme.secondaryNavy,
                      ),
                      backgroundColor: Colors.grey.shade100,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Colors.transparent),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        if (widget.isSearching)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppTheme.primaryTeal),
            ),
          ),

        if (!widget.isSearching && displayedStores.isNotEmpty)
          ...displayedStores.map((store) {
            // 해당 매장 브랜드와 일치하는 내 '사용 가능한' 기프티콘 목록 필터링
            final matchedGifticons = gifticons
                .where(
                  (g) => g.brandName == store.matchedBrand && g.isUsed != true,
                )
                .toList();

            String badgeText;
            if (matchedGifticons.isEmpty) {
              badgeText = '사용 가능';
            } else if (matchedGifticons.length == 1) {
              badgeText = matchedGifticons.first.productName;
            } else {
              badgeText =
                  '${matchedGifticons.first.productName} 외 ${matchedGifticons.length - 1}개';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _StoreListItem(
                title: store.placeName,
                brand: store.matchedBrand, // 브랜드명 추가
                distance: '${store.distance.toInt()}m',
                badgeText: badgeText,
                onLocationTap: () => widget.onStoreTap?.call(store),
                onRouteTap: () => MapLauncher.launchRoute(
                  lat: store.latitude,
                  lng: store.longitude,
                  name: store.placeName,
                ),
                onGifticonTap: () async {
                  if (matchedGifticons.isNotEmpty) {
                    final isSecurityOn = widget.ref.read(
                      securityToggleProvider,
                    );
                    bool isAuthenticated = false;

                    if (!isSecurityOn) {
                      isAuthenticated = true;
                    } else {
                      final securityService = widget.ref.read(
                        securityServiceProvider,
                      );
                      final isAvailable = await securityService
                          .isBiometricAvailable();

                      if (isAvailable) {
                        isAuthenticated = await securityService.authenticate(
                          reason: '기프티콘을 확인하려면 인증이 필요합니다.',
                        );
                      } else {
                        // 생체 인식을 사용할 수 없는 기기인 경우 통과 (또는 기존 앱 정책에 따라)
                        isAuthenticated = true;
                      }
                    }

                    if (!isAuthenticated) return;
                    if (!mounted) return;

                    if (matchedGifticons.length == 1) {
                      context.push(
                        '/wallet/detail',
                        extra: matchedGifticons.first,
                      );
                    } else {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  '${store.placeName} 기프티콘 선택',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ...matchedGifticons.map(
                                (g) => ListTile(
                                  leading: const Icon(
                                    Icons.card_giftcard_rounded,
                                    color: AppTheme.primaryTeal,
                                  ),
                                  title: Text(
                                    g.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text('유효기간: ${g.expirationDate}'),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.push('/wallet/detail', extra: g);
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            );
          }),
      ],
    );
  }
}

class _StoreListItem extends StatelessWidget {
  final String title;
  final String brand; // 브랜드 필드 추가
  final String distance;
  final String badgeText;
  final VoidCallback? onLocationTap;
  final VoidCallback? onRouteTap;
  final VoidCallback? onGifticonTap;

  const _StoreListItem({
    required this.title,
    required this.brand, // 브랜드 필수 인자 추가
    required this.distance,
    required this.badgeText,
    this.onLocationTap,
    this.onRouteTap,
    this.onGifticonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppTheme.primaryTeal,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 브랜드 및 매장명 (상단에 넓게 배치)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryNavy,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        brand,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.secondaryNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 2. 거리 및 뱃지
                Row(
                  children: [
                    Text(
                      distance,
                      style: const TextStyle(
                        color: AppTheme.primaryTeal,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 3. 버튼들 (별도 행으로 분리하여 가독성 확보)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onLocationTap,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              '위치보기',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.secondaryNavy,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: onRouteTap,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryNavy,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              '길찾기',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: onGifticonTap,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              '기프티콘',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
