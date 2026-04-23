import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/models/gifticon_model.dart';
import '../../data/repositories/gifticon_repository.dart';

part 'gifticon_provider.g.dart';

@Riverpod(keepAlive: true)
class GifticonList extends _$GifticonList {
  @override
  Future<List<GifticonModel>> build() async {
    return _fetchGifticons();
  }

  Future<List<GifticonModel>> _fetchGifticons() async {
    final repo = ref.read(gifticonRepositoryProvider);
    return repo.getGifticons();
  }

  Future<void> addGifticon(GifticonModel gifticon) async {
    // 기존 상태 백업
    final previousState = state;

    // 낙관적 업데이트 (Optimistic UI): DB 저장을 기다리지 않고 즉시 화면에 반영
    if (state.hasValue) {
      final currentList = state.value!;
      state = AsyncData([gifticon, ...currentList]);
    }

    try {
      final repo = ref.read(gifticonRepositoryProvider);
      await repo.addGifticon(gifticon);
      // 성공 시 실제 DB 데이터와 최종 동기화
      state = AsyncData(await _fetchGifticons());
    } catch (e, st) {
      // 실패 시 롤백
      state = previousState;
      state = AsyncError(e, st);
    }
  }

  Future<void> deleteGifticon(String id) async {
    final previousState = state;
    state = const AsyncLoading();
    try {
      final repo = ref.read(gifticonRepositoryProvider);
      await repo.deleteGifticon(id);
      state = AsyncData(await _fetchGifticons());
    } catch (e, st) {
      state = previousState;
      state = AsyncError(e, st);
    }
  }
}
