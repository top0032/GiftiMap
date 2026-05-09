import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../../core/theme/theme.dart';
import '../../../core/services/security_service.dart';
import 'providers/gifticon_provider.dart';
import '../domain/models/gifticon_model.dart';

enum GifticonSortOption {
  expiryAsc('유효기간 임박순'),
  recentDesc('최근 등록순'),
  brandAsc('브랜드 이름순');

  final String label;
  const GifticonSortOption(this.label);
}

class GifticonListScreen extends ConsumerStatefulWidget {
  const GifticonListScreen({super.key});

  @override
  ConsumerState<GifticonListScreen> createState() => _GifticonListScreenState();
}

class _GifticonListScreenState extends ConsumerState<GifticonListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isUnlocked = false; // 보관함 잠금 상태 관리
  GifticonSortOption _currentSortOption = GifticonSortOption.expiryAsc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    
    // 화면 진입 시 즉시 보안 인증 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    final isSecurityOn = ref.read(securityToggleProvider);
    if (!isSecurityOn) {
      if (mounted) {
        setState(() {
          _isUnlocked = true;
        });
      }
      return;
    }

    final success = await SecurityService().authenticate();
    if (success && mounted) {
      setState(() {
        _isUnlocked = true;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gifticonsAsyncValue = ref.watch(gifticonListProvider);
    final gifticons = gifticonsAsyncValue.value ?? [];
    final availableCount = gifticons.where((g) => g.isUsed != true).length;
    final usedCount = gifticons.where((g) => g.isUsed == true).length;
    
    final currentCount = _tabController.index == 0 ? availableCount : usedCount;
    final statusText = _tabController.index == 0 ? '사용가능' : '사용완료';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: _isUnlocked 
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            text: '보관함에 ',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.secondaryNavy,
                              height: 1.3,
                            ),
                            children: [
                              TextSpan(
                                text: '$currentCount개의\n',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryTeal,
                                ),
                              ),
                              TextSpan(
                                text: '$statusText 기프티콘이 있어요',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.secondaryNavy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      CircleAvatar(
                        backgroundColor: AppTheme.surfaceWhite,
                        radius: 24,
                        child: IconButton(
                          icon: const Icon(Icons.settings_rounded, color: AppTheme.secondaryNavy),
                          onPressed: () {
                            context.push('/settings');
                          },
                        ),
                      )
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TabBar(
                          controller: _tabController,
                          dividerColor: Colors.transparent,
                          indicatorColor: AppTheme.primaryTeal,
                          indicatorWeight: 3,
                          labelColor: AppTheme.primaryTeal,
                          unselectedLabelColor: Colors.grey,
                          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          tabs: const [
                            Tab(text: '사용 가능'),
                            Tab(text: '사용 완료'),
                          ],
                        ),
                      ),
                      PopupMenuButton<GifticonSortOption>(
                        icon: const Icon(Icons.sort_rounded, color: AppTheme.secondaryNavy),
                        tooltip: '정렬',
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (option) {
                          setState(() {
                            _currentSortOption = option;
                          });
                        },
                        itemBuilder: (context) => GifticonSortOption.values.map((option) {
                          return PopupMenuItem(
                            value: option,
                            child: Text(
                              option.label,
                              style: TextStyle(
                                fontWeight: _currentSortOption == option ? FontWeight.bold : FontWeight.normal,
                                color: _currentSortOption == option ? AppTheme.primaryTeal : AppTheme.secondaryNavy,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                
                Expanded(
                  child: gifticonsAsyncValue.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal)),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              '데이터를 불러오는 중 오류가 발생했습니다.\n$error',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => ref.invalidate(gifticonListProvider),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('새로고침'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryTeal,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    data: (gifticons) {
                      if (gifticons.isEmpty) {
                        return const Center(child: Text('보관함이 비어있습니다.\n하단의 + 버튼을 눌러 기프티콘을 추가해보세요!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
                      }
                      
                      final availableGifticons = gifticons.where((g) => g.isUsed != true).toList();
                      final usedGifticons = gifticons.where((g) => g.isUsed == true).toList();
                      
                      _sortGifticons(availableGifticons, _currentSortOption);
                      _sortGifticons(usedGifticons, _currentSortOption);
                      
                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _buildGifticonList(availableGifticons, context),
                          _buildGifticonList(usedGifticons, context, isArchive: true),
                        ],
                      );
                    },
                  ),
                ),
              ],
            )
          : _buildLockedUI(), // 미인증 시 잠금 화면 표시
      ),
      floatingActionButton: SizedBox(
        height: 44,
        child: FloatingActionButton.extended(
          onPressed: () {
            context.push('/wallet/add-manual');
          },
          backgroundColor: AppTheme.primaryTeal,
          elevation: 4,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          label: const Text('기프티콘 등록', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildLockedUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryTeal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, size: 64, color: AppTheme.primaryTeal),
          ),
          const SizedBox(height: 24),
          const Text(
            '보관함이 잠겨 있습니다',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.secondaryNavy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '기프티콘 목록을 확인하려면\n보안 인증이 필요합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _authenticate,
            icon: const Icon(Icons.fingerprint_rounded),
            label: const Text('인증하고 열기', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sortGifticons(List<GifticonModel> list, GifticonSortOption option) {
    list.sort((a, b) {
      switch (option) {
        case GifticonSortOption.expiryAsc:
          int getSortValue(GifticonModel g) {
            if (g.remainingDays == -999) return 99999; // 기한 없음은 맨 뒤로
            if (g.remainingDays < 0) return 10000 - g.remainingDays; // 만료된 것은 남은 기간이 0 이상인 것들 뒤에 배치 (최근 만료된 것부터)
            return g.remainingDays;
          }
          return getSortValue(a).compareTo(getSortValue(b));
        case GifticonSortOption.recentDesc:
          return b.createdAt.compareTo(a.createdAt);
        case GifticonSortOption.brandAsc:
          return a.brandName.compareTo(b.brandName);
      }
    });
  }

  Widget _buildGifticonList(List<GifticonModel> gifticons, BuildContext context, {bool isArchive = false}) {
    if (gifticons.isEmpty) {
      return Center(
        child: Text(
          isArchive ? '사용 완료된 기프티콘이 없습니다.' : '사용 가능한 기프티콘이 없습니다.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
      itemCount: gifticons.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final gifticon = gifticons[index];
        final remainingDays = gifticon.remainingDays;
        final isExpired = (gifticon.isUsed == true) || (remainingDays < 0 && remainingDays != -999);
        final isUrgent = (gifticon.isUsed != true) && (remainingDays >= 0 && remainingDays <= 14);
        
        return _GifticonCard(
          imageUrl: gifticon.imageUrl,
          brand: gifticon.brandName,
          itemName: gifticon.productName,
          dDay: gifticon.dDayString,
          isUrgent: isUrgent,
          isExpired: isExpired,
          onTap: () {
            context.push('/wallet/detail', extra: gifticon);
          },
        );
      },
    );
  }
}

class _GifticonCard extends StatelessWidget {
  final String? imageUrl;
  final String brand;
  final String itemName;
  final String dDay;
  final bool isUrgent;
  final bool isExpired;
  final VoidCallback? onTap;

  const _GifticonCard({
    this.imageUrl,
    required this.brand,
    required this.itemName,
    required this.dDay,
    this.isUrgent = false,
    this.isExpired = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryNavy.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ?? () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('상세 화면은 개발 중입니다.')),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 기프티콘 이미지 영역 (이미지가 있으면 표시, 없으면 기본 아이콘)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? (isExpired 
                          ? ColorFiltered(
                              colorFilter: const ColorFilter.matrix([
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0.2126, 0.7152, 0.0722, 0, 0,
                                0,      0,      0,      1, 0,
                              ]),
                              child: imageUrl!.startsWith('http')
                                  ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)))
                                  : Image.file(File(imageUrl!), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey))),
                            )
                          : (imageUrl!.startsWith('http')
                              ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)))
                              : Image.file(File(imageUrl!), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)))))
                      : const Center(
                          child: Icon(Icons.coffee_rounded, color: Colors.grey, size: 40),
                        ),
                ),
                const SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        brand,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isExpired ? Colors.grey.shade400 : AppTheme.secondaryNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        itemName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isExpired ? Colors.grey.shade400 : AppTheme.secondaryNavy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // 하단 상태 칩
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isExpired 
                                  ? Colors.grey.shade200 
                                  : (isUrgent ? Colors.red.shade50 : AppTheme.primaryTeal.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dDay,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isExpired 
                                    ? Colors.grey.shade500 
                                    : (isUrgent ? Colors.red.shade600 : AppTheme.primaryTeal),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '기프티콘 정보 보기 >',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isExpired ? Colors.grey.shade300 : Colors.grey.shade400,
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
