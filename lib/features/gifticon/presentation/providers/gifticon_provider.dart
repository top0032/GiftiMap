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
    final data = await repo.getGifticons();
    
    // UI 테스트를 위한 가짜(Dummy) 데이터 추가
    if (data.isEmpty) {
      return [
        GifticonModel(
          id: 'dummy1',
          brandName: '스타벅스',
          productName: '아이스 카페 아메리카노 T',
          expirationDate: '2026.05.20',
          barcodeNumber: '123456789012',
          createdAt: DateTime.now(),
        ),
        GifticonModel(
          id: 'dummy2',
          brandName: '투썸플레이스',
          productName: '스트로베리 초콜릿 생크림',
          expirationDate: '2026.06.15',
          barcodeNumber: '987654321098',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        GifticonModel(
          id: 'dummy3',
          brandName: '배스킨라빈스',
          productName: '파인트 아이스크림',
          expirationDate: '2026.07.01',
          barcodeNumber: '567812349012',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];
    }
    
    return data;
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
    if (id.isEmpty) return;
    final previousState = state;
    
    // 로딩 화면(AsyncLoading)으로 진입하지 않고 즉시 리스트에서 제외 (낙관적 UI 업데이트)
    if (state.hasValue) {
      state = AsyncData(state.value!.where((g) => g.id != id).toList());
    }

    try {
      // 프론트엔드 테스트를 위해 생성한 더미 데이터의 경우, DB 삭제 및 재조회를 건너뜁니다.
      if (id.startsWith('dummy')) {
        return;
      }
      
      final repo = ref.read(gifticonRepositoryProvider);
      // 백엔드 연동 전이거나 권한/네트워크 문제가 있을 때 무한정 대기하는 것을 막기 위해 3초 타임아웃 설정
      await repo.deleteGifticon(id).timeout(const Duration(seconds: 3));
      
      // 실제 서버 데이터라면 삭제 후 최종 동기화
      state = AsyncData(await _fetchGifticons());
    } catch (e, st) {
      state = previousState;
      state = AsyncError(e, st);
    }
  }

  Future<void> markAsUsed(String id) async {
    if (id.isEmpty) return;
    final previousState = state;
    
    // 낙관적 업데이트
    if (state.hasValue) {
      state = AsyncData(state.value!.map((g) {
        if (g.id == id) {
          return g.copyWith(isUsed: true);
        }
        return g;
      }).toList());
    }

    try {
      if (id.startsWith('dummy')) {
        return;
      }
      
      final repo = ref.read(gifticonRepositoryProvider);
      await repo.updateGifticonStatus(id, true).timeout(const Duration(seconds: 3));
      
      state = AsyncData(await _fetchGifticons());
    } catch (e, st) {
      state = previousState;
      state = AsyncError(e, st);
    }
  }
}
