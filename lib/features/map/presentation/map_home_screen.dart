import 'package:flutter/material.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/theme.dart';

class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({super.key});

  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen> {
  KakaoMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
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
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상단 2/3: 지도 및 버튼 영역
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              // 1. 카카오맵 실제 렌더링
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
                            markers: [
                              Marker(
                                markerId: 'my_location',
                                latLng: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                              ),
                            ],
                          ),
              ),

              // 2. 상단 레이더 / 검색 뱃지 (SafeArea)
              SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RadarBadge(),
                        _ProfileButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 하단 1/3: 주변 가맹점 모달 (지도를 가리지 않음)
        Expanded(
          flex: 1,
          child: Container(
            width: double.infinity,
            color: AppTheme.backgroundLight, // 패널 뒷배경
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 40),
              child: _NearbyGifticonPanel(),
            ),
          ),
        ),
      ],
    );
  }
}

class _RadarBadge extends StatelessWidget {
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
          // 깜빡이는 효과를 줘도 좋은 아이콘
          Icon(Icons.radar_rounded, color: AppTheme.primaryTeal, size: 20),
          const SizedBox(width: 8),
          const Text(
            '주변 가맹점 탐색 중',
            style: TextStyle(
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
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite.withOpacity(0.95), // 반투명 느낌
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
              Text(
                '총 2개의 사용할 수 있는\n기프티콘이 반경 300m 이내에 있어요!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondaryNavy,
                  height: 1.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.directions_walk_rounded, color: AppTheme.primaryTeal),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 가맹점 임시 리스트
          _StoreListItem(title: '스타벅스 강남역점', distance: '120m', badgeText: '아메리카노 2장'),
          const SizedBox(height: 8),
          _StoreListItem(title: 'CU 편의점', distance: '280m', badgeText: '바나나우유 1개'),
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
                ),
                Text(
                  distance,
                  style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          )
        ],
      ),
    );
  }
}
