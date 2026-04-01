import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';

class GifticonListScreen extends StatelessWidget {
  const GifticonListScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: 5,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _GifticonCard(
                    brand: '스타벅스',
                    itemName: '아이스 카페 아메리카노 T',
                    dDay: index == 0 ? 'D-3' : 'D-${10 + index * 5}',
                    isUrgent: index == 0,
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

  const _GifticonCard({
    required this.brand,
    required this.itemName,
    required this.dDay,
    this.isUrgent = false,
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
          onTap: () {
            // TODO: 상세 화면 넘어가기 (생체 인증)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('상세 화면은 개발 중입니다.')),
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
