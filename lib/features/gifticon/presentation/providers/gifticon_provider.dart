import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/models/gifticon_model.dart';
import '../../data/repositories/gifticon_repository.dart';
import '../../data/services/expiration_notification_service.dart';
import 'package:giftimap/features/auth/presentation/providers/auth_provider.dart';

part 'gifticon_provider.g.dart';

@Riverpod(keepAlive: true)
class GifticonList extends _$GifticonList {
  @override
  Future<List<GifticonModel>> build() async {
    // 인증 상태를 감시하여 사용자가 바뀌면 자동으로 다시 build됨
    ref.watch(authStateProvider);
    return _fetchGifticons();
  }

  Future<List<GifticonModel>> _fetchGifticons() async {
    final repo = ref.read(gifticonRepositoryProvider);
    final data = await repo.getGifticons();
    
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
      
      // 유효기간 알림 예약
      await ExpirationNotificationService().scheduleExpirationNotifications(gifticon);
      
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
      // 알림 취소
      await ExpirationNotificationService().cancelExpirationNotifications(id);

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

  Future<void> updateGifticon(GifticonModel updatedGifticon) async {
    if (updatedGifticon.id.isEmpty) return;
    final previousState = state;
    
    // 낙관적 업데이트
    if (state.hasValue) {
      state = AsyncData(state.value!.map((g) {
        if (g.id == updatedGifticon.id) {
          return updatedGifticon;
        }
        return g;
      }).toList());
    }

    try {
      final repo = ref.read(gifticonRepositoryProvider);
      // addGifticon 내부에서 id가 있으면 업데이트로 처리함
      await repo.addGifticon(updatedGifticon);
      
      // 기존 알림 취소 후 변경된 기프티콘 정보로 알림 재등록
      await ExpirationNotificationService().cancelExpirationNotifications(updatedGifticon.id);
      if (updatedGifticon.isUsed != true) {
        await ExpirationNotificationService().scheduleExpirationNotifications(updatedGifticon);
      }
      
      state = AsyncData(await _fetchGifticons());
    } catch (e, st) {
      state = previousState;
      state = AsyncError(e, st);
    }
  }

  Future<void> updateGifticonStatus(String id, bool isUsed) async {
    if (id.isEmpty) return;
    final previousState = state;
    
    // 낙관적 업데이트
    if (state.hasValue) {
      state = AsyncData(state.value!.map((g) {
        if (g.id == id) {
          return g.copyWith(isUsed: isUsed);
        }
        return g;
      }).toList());
    }

    try {
      if (isUsed) {
        // 사용 완료 시 알림 취소
        await ExpirationNotificationService().cancelExpirationNotifications(id);
      } else {
        // 다시 미사용으로 돌릴 시 알림 재예약
        if (state.hasValue) {
          final gifticon = state.value!.firstWhere((g) => g.id == id);
          await ExpirationNotificationService().scheduleExpirationNotifications(gifticon);
        }
      }

      if (id.startsWith('dummy')) {
        return;
      }
      
      final repo = ref.read(gifticonRepositoryProvider);
      await repo.updateGifticonStatus(id, isUsed).timeout(const Duration(seconds: 3));
      
      state = AsyncData(await _fetchGifticons());
    } catch (e, st) {
      state = previousState;
      state = AsyncError(e, st);
    }
  }
}
