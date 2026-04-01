import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;
  const AppScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // 현재 라우트 가져오기
    final String location = GoRouterState.of(context).uri.toString();
    
    // 네비게이션용 인덱스
    int currentIndex = location == '/' ? 0 : 1;

    return Scaffold(
      extendBody: true, // 바텀 네비게이션 아래로 내용이 이어지도록 투명 지원
      body: child,
      // 둥글고 떠있는 아름다운 FAB (등록 버튼)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 카메라 촬영 / 바코드 스캔 화면으로 이동
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('기프티콘 등록 기능은 준비중입니다.')),
          );
        },
        backgroundColor: AppTheme.primaryTeal,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // 커스텀 네비게이션 바 (Glassmorphism & Floating style)
      bottomNavigationBar: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppTheme.secondaryNavy.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomAppBar(
            padding: EdgeInsets.zero,
            color: Colors.transparent, // 투명하게 해서 Container의 둥근 모서리와 색상이 보이게 함
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.map_rounded,
                    label: '주변 찾기',
                    isSelected: currentIndex == 0,
                    onTap: () => context.go('/'),
                  ),
                  const SizedBox(width: 48), // 가운데 FAB 공간 확보
                  _NavItem(
                    icon: Icons.card_giftcard_rounded,
                    label: '보관함',
                    isSelected: currentIndex == 1,
                    onTap: () => context.go('/wallet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(4),
            child: Icon(
              icon,
              color: isSelected ? AppTheme.primaryTeal : Colors.grey.shade400,
              size: isSelected ? 28 : 24,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.primaryTeal : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
