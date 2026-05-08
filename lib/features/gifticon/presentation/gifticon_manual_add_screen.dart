import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../core/theme/theme.dart';
import '../domain/models/gifticon_model.dart';
import 'providers/gifticon_provider.dart';
import '../data/services/ocr_service.dart';
import '../utils/ocr_parser.dart';

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
  File? _selectedImage;
  bool _isProcessingOcr = false;
  bool _isSaving = false;

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
        final File tempFile = File(pickedFile.path);
        
        // 1. 앱의 영구 문서 디렉토리 가져오기
        final appDir = await getApplicationDocumentsDirectory();
        final String fileName = 'gifticon_${DateTime.now().millisecondsSinceEpoch}${path.extension(pickedFile.path)}';
        final String savedPath = path.join(appDir.path, fileName);

        // 2. 임시 파일을 영구 디렉토리로 복사
        final File savedFile = await tempFile.copy(savedPath);

        setState(() {
          _selectedImage = savedFile; // 복사된 영구 파일로 교체
          _isProcessingOcr = true;
        });

        // OCR 처리 시작
        final ocrService = ref.read(ocrServiceProvider);
        final inputImage = InputImage.fromFilePath(pickedFile.path);
        
        // OCR 서비스의 메서드를 직접 쓰지 않고 TextRecognizer를 직접 쓰거나 서비스를 통해 처리
        // 여기서는 서비스의 processImage가 ImagePicker를 내포하고 있으므로, 
        // 이미 선택된 파일을 처리하는 메서드를 별도로 만들거나 existing logic 활용
        // 임시로 서비스의 processImage 대신 직접 파싱 로직을 타게 함 (이미 파일을 선택했으므로)
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);
        final recognizedText = await textRecognizer.processImage(inputImage);
        final parsedData = OcrParser.parseEnhanced(recognizedText);
        textRecognizer.close();

        setState(() {
          if (parsedData['brandName'] != null) _brandController.text = parsedData['brandName']!;
          if (parsedData['productName'] != null) _productController.text = parsedData['productName']!;
          if (parsedData['expirationDate'] != null) _expirationController.text = parsedData['expirationDate']!;
          if (parsedData['barcodeNumber'] != null) _barcodeController.text = parsedData['barcodeNumber']!;
          _isProcessingOcr = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지 정보를 자동으로 읽어왔습니다.')),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessingOcr = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('정보를 읽어오는데 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _saveGifticon() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      
      try {
        final newGifticon = GifticonModel(
          id: '', // 리포지토리에서 새 문서로 추가하도록 빈 값 설정
          userId: '', 
          brandName: _brandController.text,
          productName: _productController.text,
          expirationDate: _expirationController.text,
          barcodeNumber: _barcodeController.text.isEmpty ? '미등록' : _barcodeController.text,
          createdAt: DateTime.now(),
          imageUrl: _selectedImage?.path,
        );

        await ref.read(gifticonListProvider.notifier).addGifticon(newGifticon);
        
        if (!mounted) return;
        
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final screenHeight = MediaQuery.of(context).size.height;
        final safeAreaTop = MediaQuery.of(context).padding.top;
        
        context.pop();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text(
              '기프티콘이 등록되었습니다',
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
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장에 실패했습니다: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      helpText: '유효기간 선택',
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
        title: const Text('기프티콘 등록', style: TextStyle(color: AppTheme.secondaryNavy, fontSize: 18, fontWeight: FontWeight.bold)),
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
                  '새로운 기프티콘 정보를\n등록해 주세요 🎁',
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
                  '기프티콘 이미지 첨부',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.secondaryNavy),
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
                    child: _selectedImage != null
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
                              Icon(Icons.add_photo_alternate_rounded, size: 48, color: AppTheme.primaryTeal),
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
                
                // 하단 저장 버튼
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isSaving || _isProcessingOcr) ? null : _saveGifticon,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      disabledBackgroundColor: AppTheme.primaryTeal.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving 
                      ? const SizedBox(
                          height: 20, 
                          width: 20, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('보관함에 저장하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
