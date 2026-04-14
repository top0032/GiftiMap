import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../domain/models/ocr_result_model.dart';
import '../../utils/ocr_parser.dart';

class OcrService {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);

  Future<OcrResultModel?> processImage(ImageSource source) async {
    if (kIsWeb) {
      throw '웹(Chrome) 환경에서는 카메라/OCR 기능을 지원하지 않습니다.\n안드로이드 에뮬레이터나 아이폰 시뮬레이터, 또는 실제 기기 환경에서 테스트해주세요.';
    }
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return null;

      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      final String rawText = recognizedText.text;
      
      final parsedData = OcrParser.parseText(rawText);

      return OcrResultModel(
        rawText: rawText,
        expirationDate: parsedData['expirationDate'],
        barcodeNumber: parsedData['barcodeNumber'],
      );
    } catch (e) {
      print('OCR Error: $e');
      return null;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
