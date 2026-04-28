// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [AuthRepository]의 인스턴스를 제공하는 프로바이더(Provider)입니다.

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

/// [AuthRepository]의 인스턴스를 제공하는 프로바이더(Provider)입니다.

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  /// [AuthRepository]의 인스턴스를 제공하는 프로바이더(Provider)입니다.
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'e3b22fd7863ea1be0b322870da43112c60f80087';

/// Firebase의 인증 상태(User?) 변화를 실시간으로 감지하여 제공하는 스트림 프로바이더입니다.

@ProviderFor(authState)
final authStateProvider = AuthStateProvider._();

/// Firebase의 인증 상태(User?) 변화를 실시간으로 감지하여 제공하는 스트림 프로바이더입니다.

final class AuthStateProvider
    extends $FunctionalProvider<AsyncValue<User?>, User?, Stream<User?>>
    with $FutureModifier<User?>, $StreamProvider<User?> {
  /// Firebase의 인증 상태(User?) 변화를 실시간으로 감지하여 제공하는 스트림 프로바이더입니다.
  AuthStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStateHash();

  @$internal
  @override
  $StreamProviderElement<User?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<User?> create(Ref ref) {
    return authState(ref);
  }
}

String _$authStateHash() => r'd9cb25a6beabac8407f73e3a8258280c56cedcd4';

/// 로그인 및 로그아웃과 같은 인증 동작을 제어하는 컨트롤러(Controller) 클래스입니다.

@ProviderFor(AuthController)
final authControllerProvider = AuthControllerProvider._();

/// 로그인 및 로그아웃과 같은 인증 동작을 제어하는 컨트롤러(Controller) 클래스입니다.
final class AuthControllerProvider
    extends $AsyncNotifierProvider<AuthController, void> {
  /// 로그인 및 로그아웃과 같은 인증 동작을 제어하는 컨트롤러(Controller) 클래스입니다.
  AuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authControllerHash();

  @$internal
  @override
  AuthController create() => AuthController();
}

String _$authControllerHash() => r'aa1d0cbd9fea43696aec6a8aeab7c5b679fa3bae';

/// 로그인 및 로그아웃과 같은 인증 동작을 제어하는 컨트롤러(Controller) 클래스입니다.

abstract class _$AuthController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
