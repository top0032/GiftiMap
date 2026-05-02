import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../domain/models/gifticon_model.dart';
import '../../../core/theme/theme.dart';
import 'providers/gifticon_provider.dart';

class GifticonDetailScreen extends ConsumerStatefulWidget {
  final GifticonModel gifticon;

  const GifticonDetailScreen({super.key, required this.gifticon});

  @override
  ConsumerState<GifticonDetailScreen> createState() => _GifticonDetailScreenState();
}

class _GifticonDetailScreenState extends ConsumerState<GifticonDetailScreen> {
  @override
  void initState() {
    super.initState();
    _setMaxBrightness();
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
                        ref.read(gifticonListProvider.notifier).deleteGifticon(widget.gifticon.id);
                        Navigator.pop(context); // 다이얼로그 닫기
                        Navigator.pop(context); // 상세 화면 닫기
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('기프티콘이 삭제되었습니다.')),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              // 실제 등록한 기프티콘 이미지가 있을 경우 화면 중앙 상단에 렌더링
              if (widget.gifticon.imageUrl != null && widget.gifticon.imageUrl!.isNotEmpty)
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
                  child: Image.file(
                    File(widget.gifticon.imageUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey)),
                  ),
                ),
              // 상태 배지 추가
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.gifticon.isUsed == true 
                      ? Colors.grey.shade200 
                      : AppTheme.primaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.gifticon.isUsed == true ? '사용 완료' : '사용 가능',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.gifticon.isUsed == true ? Colors.grey.shade600 : AppTheme.primaryTeal,
                  ),
                ),
              ),
              // 브랜드 및 상품명
              Text(
                widget.gifticon.brandName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryNavy,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.gifticon.productName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondaryNavy,
                ),
              ),
              const SizedBox(height: 30),
              // 유효기간 및 D-Day
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      '유효기간: ${widget.gifticon.expirationDate}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryNavy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Builder(
                    builder: (context) {
                      final days = widget.gifticon.remainingDays;
                      final isExpired = (widget.gifticon.isUsed == true) || (days < 0 && days != -999);
                      final isUrgent = (widget.gifticon.isUsed != true) && (days >= 0 && days <= 14);
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isExpired 
                              ? Colors.grey.shade200 
                              : (isUrgent ? Colors.red.shade50 : AppTheme.primaryTeal.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.gifticon.dDayString,
                          style: TextStyle(
                            fontSize: 15,
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
                child: Column(
                  children: [
                    BarcodeWidget(
                      barcode: Barcode.code128(), // 주로 쓰이는 범용 바코드 포맷
                      data: widget.gifticon.barcodeNumber.replaceAll(RegExp(r'[^0-9a-zA-Z]'), ''), // 렌더링 오류 방지를 위해 숫자/영문자만 추출
                      width: double.infinity,
                      height: 100,
                      errorBuilder: (context, error) => const Center(
                        child: Text('바코드를 생성할 수 없습니다.\n올바른 번호인지 확인해주세요.', textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // 결제 완료/사용 완료 처리 버튼
              if (widget.gifticon.isUsed != true)
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
                                ref.read(gifticonListProvider.notifier).updateGifticonStatus(widget.gifticon.id, true);
                                Navigator.pop(context); // 다이얼로그 닫기
                                Navigator.pop(context); // 상세 화면 닫기
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('기프티콘이 사용 처리되었습니다.')),
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
                          content: const Text('이 기프티콘을 다시 \'미사용\' 상태로 변경하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('취소', style: TextStyle(color: Colors.grey)),
                            ),
                            TextButton(
                              onPressed: () {
                                ref.read(gifticonListProvider.notifier).updateGifticonStatus(widget.gifticon.id, false);
                                Navigator.pop(context); // 다이얼로그 닫기
                                Navigator.pop(context); // 상세 화면 닫기
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('기프티콘이 미사용 상태로 복구되었습니다.')),
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
