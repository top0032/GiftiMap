import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:geolocator/geolocator.dart';
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
    await GeofenceNotificationService().initialize();
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
        .map((g) => g.brandName)
        .where((brand) => brand != '알 수 없는 브랜드' && brand != null)
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
          latLng: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          // 추후 커스텀 아이콘으로 변경 가능
        ),
      );
      
      // 검색된 주변 매장 마커
      for (var store in _nearbyStores) {
        mapMarkers.add(
          Marker(
            markerId: store.id,
            latLng: LatLng(store.latitude, store.longitude),
            infoWindowContent: '<div style="padding:4px;">${store.placeName}</div>',
          ),
        );
      }
    }

    return Column(
      children: [
        // 상단 2/3: 지도 및 버튼 영역
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              Positioned.fill(
                child: _isLoading
                    ? Container(
                        color: AppTheme.backgroundLight,
                        child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal)),
                      )
                    : _currentPosition == null
                        ? Container(
                            color: AppTheme.backgroundLight,
                            child: const Center(child: Text('위치를 불러올 수 없습니다.')),
                          )
                        : KakaoMap(
                            onMapCreated: (controller) => _mapController = controller,
                            center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            markers: mapMarkers.isEmpty ? null : mapMarkers,
                          ),
              ),

              SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RadarBadge(isSearching: _isSearchingStores, storeCount: _nearbyStores.length),
                        _ProfileButton(),
                      ],
                    ),
                  ),
                ),
              ),
              
              // 내 위치로 돌아가기 & 새로고침 버튼
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: AppTheme.surfaceWhite,
                  child: const Icon(Icons.my_location, color: AppTheme.primaryTeal),
                  onPressed: () {
                    if (_currentPosition != null && _mapController != null) {
                      _mapController!.setCenter(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
                      _fetchNearbyStores(); // 검색도 새로고침
                    } else {
                      _determinePosition();
                    }
                  },
                ),
              )
            ],
          ),
        ),

        // 하단 1/3: 주변 가맹점 모달
        Expanded(
          flex: 1,
          child: Container(
            width: double.infinity,
            color: AppTheme.backgroundLight,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 40),
              child: _NearbyGifticonPanel(stores: _nearbyStores, isSearching: _isSearchingStores, ref: ref),
            ),
          ),
        ),
      ],
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
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isSearching 
            ? const SizedBox(
                width: 16, height: 16, 
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTeal)
              )
            : const Icon(Icons.radar_rounded, color: AppTheme.primaryTeal, size: 20),
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

  const _NearbyGifticonPanel({required this.stores, required this.isSearching, required this.ref});

  @override
  Widget build(BuildContext context) {
    final gifticons = ref.read(gifticonListProvider).value ?? [];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryNavy.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isSearching 
                    ? '내 기프티콘 사용처를\n찾는 중입니다...'
                    : stores.isEmpty
                      ? '주변 반경 1km 이내에\n사용 가능한 가맹점이 없습니다.'
                      : '총 ${stores.length}개의 사용할 수 있는\n기프티콘 매장이 반경 1km 이내에 있어요!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.secondaryNavy,
                    height: 1.3,
                  ),
                ),
              ),
              if (!isSearching && stores.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_walk_rounded, color: AppTheme.primaryTeal),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (isSearching)
             const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppTheme.primaryTeal))),
             
          if (!isSearching && stores.isNotEmpty)
            ...stores.take(5).map((store) {
              // 해당 매장 브랜드와 일치하는 내 기프티콘 개수 계산
              final matchedGifticons = gifticons.where((g) => g.brandName == store.matchedBrand).toList();
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
      ),
    );
  }
}

class _StoreListItem extends StatelessWidget {
  final String title;
  final String distance;
  final String badgeText;

  const _StoreListItem({required this.title, required this.distance, required this.badgeText});

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
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  distance,
                  style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.w600, fontSize: 13),
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
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        ],
      ),
    );
  }
}
