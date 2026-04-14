import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/services/ocr_service.dart';
import '../../domain/models/ocr_result_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'ocr_provider.g.dart';

@riverpod
OcrService ocrService(Ref ref) {
  final service = OcrService();
  ref.onDispose(() => service.dispose());
  return service;
}

@riverpod
class OcrState extends _$OcrState {
  @override
  AsyncValue<OcrResultModel?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> scanImage(ImageSource source) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(ocrServiceProvider);
      final result = await service.processImage(source);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
