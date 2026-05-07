import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/theme.dart';
import '../data/services/kakao_local_api_service.dart';
import '../data/services/geofence_notification_service.dart';
import '../domain/models/store_model.dart';
import '../../gifticon/presentation/providers/gifticon_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class MapHomeScreen extends ConsumerStatefulWidget {
  const MapHomeScreen({super.key});

  @override
  ConsumerState<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends ConsumerState<MapHomeScreen> {
  KakaoMapController? _mapController;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isSearchingStores = false;
  bool _showStores = false;
  String? _selectedStoreId;
  List<StoreModel> _nearbyStores = [];
  final KakaoLocalApiService _apiService = KakaoLocalApiService();

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _initGeofencing();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
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

    final filteredStores = allStores.where((store) {
      return gifticons.any((g) => g.brandName == store.matchedBrand && g.isUsed != true);
    }).toList();

    filteredStores.sort((a, b) => a.distance.compareTo(b.distance));
    await GeofenceNotificationService().setupGeofences(filteredStores);

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
        
        // 특정 매장이 선택된 경우, 그 매장이 아니면 무시
        if (_selectedStoreId != null && store.id != _selectedStoreId) {
          continue;
        }
        
        // 특정 매장이 선택되지 않았고, 발견(showStores) 상태도 아니면 무시
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
                      // 마커 클릭 시 해당 위치로 중심 이동
                      if (markerId != 'my_location') {
                        _mapController?.setCenter(latLng);
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
  final bool isExpanded;
  final VoidCallback onToggle;

  const _RadarBadge({
    required this.isSearching,
    required this.storeCount,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: isExpanded ? 16 : 12, vertical: 10),
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
                      ? const Icon(Icons.person, size: 40, color: AppTheme.primaryTeal)
                      : null,
                ),
                const SizedBox(height: 16),
                // 사용자 이름 (Consumer를 사용하여 팝업 내부에서도 실시간 업데이트)
                Consumer(
                  builder: (context, ref, child) {
                    final currentName = ref.watch(displayNameProvider) ?? user?.displayName ?? '사용자';
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
                  user?.email ?? (user?.isAnonymous == true ? '익명 계정 (카카오 연동됨)' : '이메일 정보 없음'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                // 로그아웃 버튼
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text(
                    '로그아웃',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
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
                child: const Text('닫기', style: TextStyle(color: AppTheme.secondaryNavy)),
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

class _NearbyGifticonPanel extends StatelessWidget {
  final List<StoreModel> stores;
  final bool isSearching;
  final WidgetRef ref;
  final Function(StoreModel)? onStoreTap;
  final ScrollController scrollController;

  const _NearbyGifticonPanel({
    required this.stores,
    required this.isSearching,
    required this.ref,
    this.onStoreTap,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // ref.watch를 사용하여 기프티콘 리스트 변화를 실시간으로 감시
    final gifticons = ref.watch(gifticonListProvider).value ?? [];

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      // 시트가 최소 높이일 때도 드래그가 끊기지 않도록 설정
      physics: const ClampingScrollPhysics(),
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
          ...stores.map((store) {
            // 해당 매장 브랜드와 일치하는 내 '사용 가능한' 기프티콘 목록 필터링
            final matchedGifticons = gifticons
                .where((g) => g.brandName == store.matchedBrand && g.isUsed != true)
                .toList();
            
            String badgeText;
            if (matchedGifticons.isEmpty) {
              badgeText = '사용 가능';
            } else if (matchedGifticons.length == 1) {
              badgeText = matchedGifticons.first.productName;
            } else {
              badgeText = '${matchedGifticons.first.productName} 외 ${matchedGifticons.length - 1}개';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _StoreListItem(
                title: store.placeName,
                distance: '${store.distance.toInt()}m',
                badgeText: badgeText,
                onLocationTap: () => onStoreTap?.call(store),
                onGifticonTap: () {
                  if (matchedGifticons.isNotEmpty) {
                    if (matchedGifticons.length == 1) {
                      context.push('/wallet/detail', extra: matchedGifticons.first);
                    } else {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text('${store.placeName} 기프티콘 선택', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                              ...matchedGifticons.map((g) => ListTile(
                                leading: const Icon(Icons.card_giftcard_rounded, color: AppTheme.primaryTeal),
                                title: Text(g.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('유효기간: ${g.expirationDate}'),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push('/wallet/detail', extra: g);
                                },
                              )),
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
  final String distance;
  final String badgeText;
  final VoidCallback? onLocationTap;
  final VoidCallback? onGifticonTap;

  const _StoreListItem({
    required this.title,
    required this.distance,
    required this.badgeText,
    this.onLocationTap,
    this.onGifticonTap,
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.storefront_rounded, color: Colors.grey, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: onLocationTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('위치보기', style: TextStyle(fontSize: 12, color: AppTheme.secondaryNavy, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: onGifticonTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTeal,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('기프티콘 보기', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      distance,
                      style: const TextStyle(
                        color: AppTheme.primaryTeal,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
