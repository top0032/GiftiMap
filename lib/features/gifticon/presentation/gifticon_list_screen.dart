import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import 'providers/gifticon_provider.dart';

class GifticonListScreen extends ConsumerWidget {
  const GifticonListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gifticonsAsyncValue = ref.watch(gifticonListProvider);

    return Container(
      color: AppTheme.backgroundLight,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      text: '내 지갑에\n',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.secondaryNavy,
                        height: 1.2,
                      ),
                      children: [
                        TextSpan(
                          text: '총 5개의 선물',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                        const TextSpan(text: '이 있어요'),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: AppTheme.surfaceWhite,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.secondaryNavy),
                      onPressed: () {},
                    ),
                  )
                ],
              ),
            ),
            
            Expanded(
              child: gifticonsAsyncValue.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal)),
                error: (error, stack) => Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.\n$error', textAlign: TextAlign.center)),
                data: (gifticons) {
                  if (gifticons.isEmpty) {
                    return const Center(child: Text('보관함이 비어있습니다.\n하단의 + 버튼을 눌러 기프티콘을 추가해보세요!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
                  }
                  
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: gifticons.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final gifticon = gifticons[index];
                      // 단순 임시 D-Day 계산 (향후 날짜 파싱 로직 추가 필요)
                      final dDay = 'D-?'; 
                      
                      return _GifticonCard(
                        brand: gifticon.brandName,
                        itemName: gifticon.productName,
                        dDay: dDay,
                        isUrgent: false,
                        onDelete: () {
                          ref.read(gifticonListProvider.notifier).deleteGifticon(gifticon.id);
                        },
                        onTap: () {
                          context.push('/wallet/detail', extra: gifticon);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            
            // 바텀 네비게이션 여백
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _GifticonCard extends StatelessWidget {
  final String brand;
  final String itemName;
  final String dDay;
  final bool isUrgent;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const _GifticonCard({
    required this.brand,
    required this.itemName,
    required this.dDay,
    this.isUrgent = false,
    this.onDelete,
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
          onLongPress: () {
            if (onDelete != null) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('삭제하시겠습니까?'),
                  content: const Text('이 기프티콘을 보관함에서 삭제합니다.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete!();
                      },
                      child: const Text('삭제', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                )
              );
            }
          },
          onTap: onTap ?? () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('상세 화면은 개발 중입니다. (길게 누르면 삭제 가능)')),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 임시 이미지 영역
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
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
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        itemName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.secondaryNavy,
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
                              color: isUrgent ? Colors.red.shade50 : AppTheme.primaryTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dDay,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isUrgent ? Colors.red.shade600 : AppTheme.primaryTeal,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '바코드 보기 >',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade400,
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
