import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

/// [AuthRepository]의 인스턴스를 제공하는 프로바이더(Provider)입니다.
@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository();
}

/// Firebase의 인증 상태(User?) 변화를 실시간으로 감지하여 제공하는 스트림 프로바이더입니다.
@riverpod
Stream<User?> authState(Ref ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
}

/// 로그인 및 로그아웃과 같은 인증 동작을 제어하는 컨트롤러(Controller) 클래스입니다.
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {
    // 초기 상태는 비어있습니다.
  }

  /// 구글 로그인을 실행합니다.
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithGoogle();
    });
  }

  /// 로그아웃을 실행합니다.
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.signOut();
    });
  }
}
