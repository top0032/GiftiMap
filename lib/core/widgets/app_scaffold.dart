import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/theme.dart';
import '../../features/gifticon/presentation/providers/ocr_provider.dart';
import '../../features/gifticon/domain/models/gifticon_model.dart';
import '../../features/gifticon/presentation/providers/gifticon_provider.dart';

class AppScaffold extends ConsumerWidget {
  final Widget child;
  const AppScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // OCR 결과 상태 리스너
    ref.listen(ocrStateProvider, (previous, next) {
      if (next is AsyncData && next.value != null) {
        final result = next.value!;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('기프티콘 인식 완료'),
            content: Text('유효기간: ${result.expirationDate ?? '파싱 실패'}\n바코드: ${result.barcodeNumber ?? '파싱 실패'}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                onPressed: () {
                  final newGifticon = GifticonModel(
                    id: '',
                    userId: '', // 저장소에서 실제 로그인한 사용자의 UID로 덮어씌워집니다.
                    brandName: result.brandName ?? '알 수 없는 브랜드',
                    productName: result.productName ?? '알 수 없는 상품',
                    expirationDate: result.expirationDate ?? '유효기간 없음',
                    barcodeNumber: result.barcodeNumber ?? '바코드 인식 실패',
                    createdAt: DateTime.now(),
                  );
                  ref.read(gifticonListProvider.notifier).addGifticon(newGifticon);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('보관함에 저장되었습니다! 🎁')));
                },
                child: const Text('저장하기', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      }
    });

    final String location = GoRouterState.of(context).uri.toString();
    int currentIndex = location == '/' ? 0 : 1;

    return Scaffold(
      extendBody: false,
      body: SafeArea(
        bottom: true, // 시스템 바 위로 모든 화면이 위치하도록 보호
        child: child,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.map_rounded,
                  label: '주변 찾기',
                  isSelected: currentIndex == 0,
                  onTap: () => context.go('/'),
                ),
                
                // 네비게이션 바 중앙에 배치된 등록 버튼
                GestureDetector(
                  onTap: () => _showAddOptions(context, ref),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryTeal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_a_photo, color: Colors.white, size: 24),
                  ),
                ),

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
    );
  }

  void _showAddOptions(BuildContext context, WidgetRef ref) {
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
            const Divider(indent: 16, endIndent: 16, height: 1),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_rounded, color: AppTheme.primaryTeal),
              title: const Text('기프티콘 앨범에서 사진만 등록'),
              subtitle: const Text('자동 분석 없이 갤러리 사진을 그대로 저장합니다'),
              onTap: () {
                Navigator.pop(context);
                context.push('/wallet/add-manual');
              },
            ),
          ],
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
          Icon(
            icon,
            color: isSelected ? AppTheme.primaryTeal : Colors.grey.shade400,
            size: isSelected ? 26 : 22,
          ),
          const SizedBox(height: 2),
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
