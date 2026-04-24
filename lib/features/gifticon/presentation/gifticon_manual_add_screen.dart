import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../domain/models/gifticon_model.dart';
import 'providers/gifticon_provider.dart';

class GifticonManualAddScreen extends ConsumerStatefulWidget {
  const GifticonManualAddScreen({super.key});

  @override
  ConsumerState<GifticonManualAddScreen> createState() => _GifticonManualAddScreenState();
}

class _GifticonManualAddScreenState extends ConsumerState<GifticonManualAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _productController = TextEditingController();
  final _expirationController = TextEditingController();
  final _barcodeController = TextEditingController();

  @override
  void dispose() {
    _brandController.dispose();
    _productController.dispose();
    _expirationController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  void _saveGifticon() {
    if (_formKey.currentState!.validate()) {
      final newGifticon = GifticonModel(
        id: '', // Firestore에서 자동 생성
        brandName: _brandController.text,
        productName: _productController.text,
        expirationDate: _expirationController.text,
        barcodeNumber: _barcodeController.text,
        createdAt: DateTime.now(),
      );

      ref.read(gifticonListProvider.notifier).addGifticon(newGifticon);
      
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기프티콘이 성공적으로 등록되었습니다! 🎁')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('기프티콘 직접 등록'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '상품 정보를\n입력해주세요',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.secondaryNavy,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 32),
              
              _buildTextField(
                label: '브랜드 이름',
                hint: '예: 스타벅스, CU, 배스킨라빈스',
                controller: _brandController,
                icon: Icons.store_rounded,
                validator: (value) => (value == null || value.isEmpty) ? '브랜드 이름을 입력해주세요.' : null,
              ),
              const SizedBox(height: 20),
              
              _buildTextField(
                label: '상품명',
                hint: '예: 아이스 아메리카노 Tall',
                controller: _productController,
                icon: Icons.local_cafe_rounded,
                validator: (value) => (value == null || value.isEmpty) ? '상품명을 입력해주세요.' : null,
              ),
              const SizedBox(height: 20),
              
              _buildTextField(
                label: '유효기간',
                hint: '예: 2024.12.31',
                controller: _expirationController,
                icon: Icons.calendar_today_rounded,
                validator: (value) => (value == null || value.isEmpty) ? '유효기간을 입력해주세요.' : null,
              ),
              const SizedBox(height: 20),
              
              _buildTextField(
                label: '바코드 번호',
                hint: '숫자만 입력',
                controller: _barcodeController,
                icon: Icons.qr_code_rounded,
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.isEmpty) ? '바코드 번호를 입력해주세요.' : null,
              ),
              const SizedBox(height: 48),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveGifticon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '보관함에 저장하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.secondaryNavy,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: AppTheme.primaryTeal, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryTeal, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
