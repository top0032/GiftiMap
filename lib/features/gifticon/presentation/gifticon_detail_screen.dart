import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../domain/models/gifticon_model.dart';
import '../../../core/theme/theme.dart';

class GifticonDetailScreen extends StatefulWidget {
  final GifticonModel gifticon;

  const GifticonDetailScreen({super.key, required this.gifticon});

  @override
  State<GifticonDetailScreen> createState() => _GifticonDetailScreenState();
}

class _GifticonDetailScreenState extends State<GifticonDetailScreen> {
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // 브랜드 및 상품명
              Text(
                widget.gifticon.brandName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
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
              // 유효기간
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '유효기간: ${widget.gifticon.expirationDate}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryTeal,
                  ),
                ),
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
              // 결제 완료/사용 완료 처리 버튼 (선택사항)
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
                    // TODO: 사용 완료 처리 로직
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('사용 완료 기능은 준비 중입니다.')),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
