import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/theme/theme.dart';
import '../domain/models/gifticon_model.dart';
import 'providers/gifticon_provider.dart';

class GifticonEditScreen extends ConsumerStatefulWidget {
  final GifticonModel gifticon;

  const GifticonEditScreen({super.key, required this.gifticon});

  @override
  ConsumerState<GifticonEditScreen> createState() => _GifticonEditScreenState();
}

class _GifticonEditScreenState extends ConsumerState<GifticonEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _brandController;
  late TextEditingController _productController;
  late TextEditingController _expirationController;
  late TextEditingController _barcodeController;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _brandController = TextEditingController(text: widget.gifticon.brandName);
    _productController = TextEditingController(text: widget.gifticon.productName);
    _expirationController = TextEditingController(text: widget.gifticon.expirationDate);
    _barcodeController = TextEditingController(
      text: widget.gifticon.barcodeNumber == '미등록' ? '' : widget.gifticon.barcodeNumber,
    );
    if (widget.gifticon.imageUrl != null && widget.gifticon.imageUrl!.isNotEmpty) {
      _selectedImage = File(widget.gifticon.imageUrl!);
    }
  }

  @override
  void dispose() {
    _brandController.dispose();
    _productController.dispose();
    _expirationController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지를 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  void _saveGifticon() {
    if (_formKey.currentState!.validate()) {
      final updatedGifticon = widget.gifticon.copyWith(
        brandName: _brandController.text,
        productName: _productController.text,
        expirationDate: _expirationController.text,
        barcodeNumber: _barcodeController.text.isEmpty ? '미등록' : _barcodeController.text,
        imageUrl: _selectedImage?.path,
      );

      ref.read(gifticonListProvider.notifier).updateGifticon(updatedGifticon);
      
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final screenHeight = MediaQuery.of(context).size.height;
      final safeAreaTop = MediaQuery.of(context).padding.top;

      context.pop(); // 수정 화면 닫기
      
      // 수정 완료 스낵바 (상단 AppBar 아래 위치, 둥근 타원형 형태)
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text(
            '기프티콘 정보가 수정되었습니다',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // 둥근 타원형 느낌
          ),
          margin: EdgeInsets.only(
            bottom: screenHeight - safeAreaTop - kToolbarHeight - 40, // 이전보다 아주 살짝 내림
            left: 50,
            right: 50,
          ),
          backgroundColor: AppTheme.secondaryNavy.withOpacity(0.9), // 가시성 좋은 어두운 색상
          elevation: 0,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    // 기존 유효기간을 파싱하여 달력의 초기 날짜로 설정
    DateTime initialDate = DateTime.now();
    final parsed = widget.gifticon.parsedExpirationDate;
    if (parsed != null) {
      initialDate = parsed;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      helpText: '유효기간 수정',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked != null) {
      setState(() {
        _expirationController.text =
            "${picked.year}.${picked.month.toString().padLeft(2, '0')}.${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
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
            readOnly: readOnly,
            onTap: onTap,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(icon, color: AppTheme.primaryTeal, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('기프티콘 수정', style: TextStyle(color: AppTheme.secondaryNavy, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.secondaryNavy),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '기프티콘 정보를\n수정해 주세요',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.secondaryNavy,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 32),
                
                // 사진 업로드 영역
                Text(
                  '기프티콘 이미지 수정',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.secondaryNavy),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedImage == null ? Colors.grey.shade300 : AppTheme.primaryTeal,
                        width: 2,
                      ),
                    ),
                    child: _selectedImage != null && _selectedImage!.existsSync()
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate_rounded, size: 48, color: AppTheme.primaryTeal),
                              const SizedBox(height: 12),
                              Text(
                                '기프티콘 원본 사진 첨부 (선택)',
                                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                
                _buildTextField(
                  label: '매장 (브랜드 이름)',
                  hint: '예: 스타벅스, 배스킨라빈스',
                  controller: _brandController,
                  icon: Icons.store_rounded,
                  validator: (value) => value == null || value.trim().isEmpty ? '매장 이름을 입력해주세요.' : null,
                ),
                
                _buildTextField(
                  label: '메뉴 (상품명)',
                  hint: '예: 아이스 카페 아메리카노 T',
                  controller: _productController,
                  icon: Icons.local_cafe_rounded,
                  validator: (value) => value == null || value.trim().isEmpty ? '메뉴 이름을 입력해주세요.' : null,
                ),
                
                _buildTextField(
                  label: '만료기간',
                  hint: '날짜를 선택해 주세요',
                  controller: _expirationController,
                  icon: Icons.calendar_today_rounded,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  validator: (value) => value == null || value.trim().isEmpty ? '만료기간을 입력해주세요.' : null,
                ),
                
                _buildTextField(
                  label: '바코드 번호 (선택)',
                  hint: '하단 숫자 입력 (텍스트로 확인용)',
                  controller: _barcodeController,
                  icon: Icons.qr_code_rounded,
                  keyboardType: TextInputType.number,
                ),
                
                const SizedBox(height: 24),
                
                // 하단 수정 완료 버튼
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveGifticon,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('수정 완료하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
