import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/theme.dart';
import '../../features/gifticon/presentation/providers/ocr_provider.dart';

class AppScaffold extends ConsumerWidget {
  final Widget child;
  const AppScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // OCR 결과 상태 리스너 (결과 나오면 팝업 띄우기)
    ref.listen(ocrStateProvider, (previous, next) {
      if (next is AsyncLoading) {
        // 옵션: 로딩 인디케이터 표시 (여기서는 생략하거나 간단히 스낵바 띄울 수 있음)
      } else if (next is AsyncData && next.value != null) {
        final result = next.value!;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('기프티콘 인식 완료'),
            content: Text('유효기간: ${result.expirationDate ?? '파싱 실패'}\n바코드: ${result.barcodeNumber ?? '파싱 실패'}\n\n원본 글자수: ${result.rawText.length}자'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              )
            ],
          ),
        );
      } else if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: ${next.error}')),
        );
      }
    });

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
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => SafeArea(
              child: Wrap(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('기프티콘 추가 방식 선택', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: AppTheme.primaryTeal),
                    title: const Text('카메라로 바로 촬영'),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(ocrStateProvider.notifier).scanImage(ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: AppTheme.primaryTeal),
                    title: const Text('갤러리에서 이미지 불러오기'),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(ocrStateProvider.notifier).scanImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ),
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
