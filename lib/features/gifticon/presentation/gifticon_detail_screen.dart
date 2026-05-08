import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:go_router/go_router.dart';
import '../domain/models/gifticon_model.dart';
import '../../../core/theme/theme.dart';
import 'providers/gifticon_provider.dart';
import '../../../core/services/security_service.dart';
import 'dart:ui'; // 블러 효과용

class GifticonDetailScreen extends ConsumerStatefulWidget {
  final GifticonModel gifticon;

  const GifticonDetailScreen({super.key, required this.gifticon});

  @override
  ConsumerState<GifticonDetailScreen> createState() => _GifticonDetailScreenState();
}

class _GifticonDetailScreenState extends ConsumerState<GifticonDetailScreen> {
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _authenticate(); // 진입 시 인증 수행
    _setMaxBrightness();
  }

  Future<void> _authenticate() async {
    final securityService = ref.read(securityServiceProvider);
    final available = await securityService.isBiometricAvailable();
    
    if (available) {
      final success = await securityService.authenticate();
      if (mounted) {
        setState(() {
          _isAuthenticated = success;
        });
      }
    } else {
      // 생체 인식이 지원되지 않는 기기라면 바로 보여주거나 다른 처리를 할 수 있음
      // 여기서는 일단 인증된 것으로 간주 (혹은 비밀번호 입력창 등으로 대체 가능)
      setState(() {
        _isAuthenticated = true;
      });
    }
  }

  @override
  void dispose() {
    _resetBrightness();
    super.dispose();
  }

  Future<void> _setMaxBrightness() async {
    try {
      await ScreenBrightness.instance.setScreenBrightness(1.0);
    } catch (e) {
      debugPrint('밝기 조절 실패: $e');
    }
  }

  Future<void> _resetBrightness() async {
    try {
      await ScreenBrightness.instance.resetScreenBrightness();
    } catch (e) {
      debugPrint('밝기 복구 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gifticonsAsyncValue = ref.watch(gifticonListProvider);
    final gifticons = gifticonsAsyncValue.value ?? [];
    final currentGifticon = gifticons.firstWhere(
      (g) => g.id == widget.gifticon.id,
      orElse: () => widget.gifticon,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.secondaryNavy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.push('/wallet/edit', extra: currentGifticon);
            },
            child: const Text(
              '수정',
              style: TextStyle(color: AppTheme.primaryTeal, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('기프티콘 삭제'),
                  content: const Text('정말로 이 기프티콘을 삭제하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소', style: TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final screenHeight = MediaQuery.of(context).size.height;
                        final safeAreaTop = MediaQuery.of(context).padding.top;
                        
                        ref.read(gifticonListProvider.notifier).deleteGifticon(currentGifticon.id);
                        Navigator.pop(context); // 다이얼로그 닫기
                        Navigator.pop(context); // 상세 화면 닫기
                        
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: const Text(
                              '기프티콘이 삭제되었습니다',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            margin: EdgeInsets.only(
                              bottom: screenHeight - safeAreaTop - kToolbarHeight - 170,
                              left: 50,
                              right: 50,
                            ),
                            backgroundColor: AppTheme.secondaryNavy.withOpacity(0.9),
                            elevation: 0,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              // 실제 등록한 기프티콘 이미지가 있을 경우 화면 중앙 상단에 렌더링
              if (currentGifticon.imageUrl != null && currentGifticon.imageUrl!.isNotEmpty)
                Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: MediaQuery.of(context).size.width * 0.6,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: currentGifticon.imageUrl!.startsWith('http')
                    ? Image.network(
                        currentGifticon.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey)),
                      )
                    : Image.file(
                        File(currentGifticon.imageUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey)),
                      ),
                ),
              // 상태 배지 추가
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: currentGifticon.isUsed == true 
                      ? Colors.grey.shade200 
                      : AppTheme.primaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  currentGifticon.isUsed == true ? '사용 완료' : '사용 가능',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: currentGifticon.isUsed == true ? Colors.grey.shade600 : AppTheme.primaryTeal,
                  ),
                ),
              ),
              // 브랜드 및 상품명
              Text(
                currentGifticon.brandName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryNavy,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                currentGifticon.productName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondaryNavy,
                ),
              ),
              const SizedBox(height: 30),
              // 유효기간 및 D-Day (가로 오버플로 방지를 위해 Wrap 사용)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12, // 가로 간격
                runSpacing: 10, // 세로 간격 (줄바꿈 발생 시)
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      '유효기간: ${currentGifticon.expirationDate}',
                      style: const TextStyle(
                        fontSize: 14, // 폰트 사이즈 살짝 조정
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryNavy,
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final days = currentGifticon.remainingDays;
                      final isExpired = (currentGifticon.isUsed == true) || (days < 0 && days != -999);
                      final isUrgent = (currentGifticon.isUsed != true) && (days >= 0 && days <= 14);
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isExpired 
                              ? Colors.grey.shade200 
                              : (isUrgent ? Colors.red.shade50 : AppTheme.primaryTeal.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          currentGifticon.dDayString,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isExpired 
                                ? Colors.grey.shade600 
                                : (isUrgent ? Colors.red.shade600 : AppTheme.primaryTeal),
                          ),
                        ),
                      );
                    }
                  ),
                ],
              ),
              const SizedBox(height: 50),
              // 바코드 영역 (실제 바코드 이미지)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.secondaryNavy.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 120),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isAuthenticated)
                        BarcodeWidget(
                          barcode: Barcode.code128(),
                          data: currentGifticon.barcodeNumber.replaceAll(RegExp(r'[^0-9a-zA-Z]'), ''),
                          width: double.infinity,
                          height: 80, // 높이를 조금 줄여 여유 공간 확보
                          errorBuilder: (context, error) => const Center(
                            child: Text('바코드를 생성할 수 없습니다.\n올바른 번호인지 확인해주세요.', textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _authenticate,
                          child: Container(
                            width: double.infinity,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_outline_rounded, color: AppTheme.secondaryNavy, size: 28),
                                const SizedBox(height: 4),
                                Text(
                                  '터치하여 바코드 보기 (보안 인증)',
                                  style: TextStyle(color: AppTheme.secondaryNavy.withOpacity(0.7), fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // 결제 완료/사용 완료 처리 버튼
              if (currentGifticon.isUsed != true)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('사용 완료 처리'),
                          content: const Text('기프티콘을 사용하셨나요?\n확인 시 사용 완료 상태로 변경됩니다.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('취소', style: TextStyle(color: Colors.grey)),
                            ),
                            TextButton(
                              onPressed: () {
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                final screenHeight = MediaQuery.of(context).size.height;
                                final safeAreaTop = MediaQuery.of(context).padding.top;

                                ref.read(gifticonListProvider.notifier).updateGifticonStatus(currentGifticon.id, true);
                                Navigator.pop(context); // 다이얼로그 닫기
                                Navigator.pop(context); // 상세 화면 닫기
                                
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      '기프티콘이 사용 처리되었습니다',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    margin: EdgeInsets.only(
                                      bottom: screenHeight - safeAreaTop - kToolbarHeight - 170,
                                      left: 50,
                                      right: 50,
                                    ),
                                    backgroundColor: AppTheme.secondaryNavy.withOpacity(0.9),
                                    elevation: 0,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: const Text('사용 완료', style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text(
                      '사용 완료 처리하기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('상태 변경'),
                          content: const Text('이 기프티콘을 다시 미사용 상태로 변경하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('취소', style: TextStyle(color: Colors.grey)),
                            ),
                            TextButton(
                              onPressed: () {
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                final screenHeight = MediaQuery.of(context).size.height;
                                final safeAreaTop = MediaQuery.of(context).padding.top;

                                ref.read(gifticonListProvider.notifier).updateGifticonStatus(currentGifticon.id, false);
                                Navigator.pop(context); // 다이얼로그 닫기
                                Navigator.pop(context); // 상세 화면 닫기
                                
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      '기프티콘이 미사용 상태로 복구되었습니다',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    margin: EdgeInsets.only(
                                      bottom: screenHeight - safeAreaTop - kToolbarHeight - 170,
                                      left: 50,
                                      right: 50,
                                    ),
                                    backgroundColor: AppTheme.secondaryNavy.withOpacity(0.9),
                                    elevation: 0,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: const Text('복구하기', style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Text(
                      '미사용 상태로 되돌리기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
