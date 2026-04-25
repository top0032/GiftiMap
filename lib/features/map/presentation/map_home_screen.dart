import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/theme.dart';
import '../data/services/kakao_local_api_service.dart';
import '../data/services/geofence_notification_service.dart';
import '../domain/models/store_model.dart';
import '../../gifticon/presentation/providers/gifticon_provider.dart';

class MapHomeScreen extends ConsumerStatefulWidget {
  const MapHomeScreen({super.key});

  @override
  ConsumerState<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends ConsumerState<MapHomeScreen> {
  KakaoMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isSearchingStores = false;
  List<StoreModel> _nearbyStores = [];
  final KakaoLocalApiService _apiService = KakaoLocalApiService();

  @override
  void initState() {
    super.initState();
    _initGeofencing();
    _determinePosition();
  }

  Future<void> _initGeofencing() async {
    // 백그라운드 위치 권한 상태 확인 (이미 main에서 초기화됨)
    final status = await Permission.locationAlways.status;
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('알림을 받으려면 위치 권한을 "항상 허용"으로 설정해주세요.'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: '설정', onPressed: openAppSettings),
        ),
      );
    }
  }

  Future<void> _determinePosition() async {
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
        // 위치를 가져온 직후 주변 매장 검색
        _fetchNearbyStores();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchNearbyStores() async {
    if (_currentPosition == null) return;

    setState(() => _isSearchingStores = true);

    // 1. 내 보관함에서 기프티콘 브랜드 목록 가져오기
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
    // 중복 제거된 브랜드명 추출
    final brandNames = gifticons
        .map((g) => g.brandName.trim()) // 공백 제거
        .where((brand) => brand != '알 수 없는 브랜드' && brand.isNotEmpty)
        .toSet()
        .toList();

    List<StoreModel> allStores = [];

    // 2. 각 브랜드별로 로컬 API 검색
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

    // 3. 거리순 정렬
    allStores.sort((a, b) => a.distance.compareTo(b.distance));

    // 4. 지오펜싱(배터리 최적화 알림) 설정
    await GeofenceNotificationService().setupGeofences(allStores);

    if (mounted) {
      setState(() {
        _nearbyStores = allStores;
        _isSearchingStores = false;
      });
    }
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
          // 내 위치는 빨간색 마커 이미지로 구분 (카카오 기본 마커와 차별화)
          markerImageSrc:
              'https://t1.daumcdn.net/localimg/localimages/07/mapapidoc/marker_red.png',
        ),
      );

      // 검색된 주변 매장 마커
      final Set<String> existingIds = {'my_location'};
      for (var store in _nearbyStores) {
        // 이미 추가된 마커 ID가 있다면 건너뛰기 (중복 마커 추가 에러 방지)
        if (existingIds.contains(store.id)) continue;
        existingIds.add(store.id);

        // JavaScript 실행 시 따옴표(') 등으로 인한 마커 렌더링(함수) 예외 오류 방지 처리
        final safePlaceName = store.placeName
            .replaceAll("'", "\\'")
            .replaceAll('"', '&quot;');

        mapMarkers.add(
          Marker(
            markerId: store.id,
            latLng: LatLng(store.latitude, store.longitude),
            infoWindowContent: '<div style="padding:4px;">$safePlaceName</div>',
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
            initialChildSize: 0.11, // 최소 높이
            minChildSize: 0.11,
            maxChildSize: 0.7, // 좀 더 시원하게 볼 수 있도록 최대 높이 확대
            snap: true,
            snapSizes: const [0.11, 0.7],
            builder: (context, scrollController) {
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

                    // 실제 내용 영역
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                        child: _NearbyGifticonPanel(
                          stores: _nearbyStores,
                          isSearching: _isSearchingStores,
                          ref: ref,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RadarBadge extends StatelessWidget {
  final bool isSearching;
  final int storeCount;

  const _RadarBadge({required this.isSearching, required this.storeCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          const SizedBox(width: 8),
          Text(
            isSearching ? '주변 가맹점 탐색 중...' : '가맹점 $storeCount곳 발견',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.secondaryNavy,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: AppTheme.surfaceWhite,
      radius: 22,
      child: IconButton(
        icon: const Icon(Icons.person_rounded, color: AppTheme.secondaryNavy),
        onPressed: () {},
      ),
    );
  }
}

class _NearbyGifticonPanel extends StatelessWidget {
  final List<StoreModel> stores;
  final bool isSearching;
  final WidgetRef ref;

  const _NearbyGifticonPanel({
    required this.stores,
    required this.isSearching,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final gifticons = ref.read(gifticonListProvider).value ?? [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isSearching
                    ? '내 기프티콘 매장 찾는 중...'
                    : stores.isEmpty
                    ? '반경 1km 내 사용 가능한 매장이 없습니다.'
                    : '내 주변 1km 이내 사용 가능한 매장 ${stores.length}곳',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondaryNavy,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isSearching && stores.isNotEmpty)
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
        const SizedBox(height: 16),

        if (isSearching)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppTheme.primaryTeal),
            ),
          ),

        if (!isSearching && stores.isNotEmpty)
          ...stores.take(5).map((store) {
            // 해당 매장 브랜드와 일치하는 내 기프티콘 개수 계산
            final matchedGifticons = gifticons
                .where((g) => g.brandName == store.matchedBrand)
                .toList();
            final badgeText = matchedGifticons.isNotEmpty
                ? '${matchedGifticons.first.productName ?? '쿠폰'} 등 ${matchedGifticons.length}개'
                : '사용 가능';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _StoreListItem(
                title: store.placeName,
                distance: '${store.distance.toInt()}m',
                badgeText: badgeText,
              ),
            );
          }),
      ],
    );
  }
}

class _StoreListItem extends StatelessWidget {
  final String title;
  final String distance;
  final String badgeText;

  const _StoreListItem({
    required this.title,
    required this.distance,
    required this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  distance,
                  style: const TextStyle(
                    color: AppTheme.primaryTeal,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
