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

String _$authRepositoryHash() => r'19a3485653561ac2f781b997131430c5659286d1';

/// 사용자의 닉네임을 별도로 관리하는 프로바이더입니다.

@ProviderFor(DisplayName)
final displayNameProvider = DisplayNameProvider._();

/// 사용자의 닉네임을 별도로 관리하는 프로바이더입니다.
final class DisplayNameProvider
    extends $NotifierProvider<DisplayName, String?> {
  /// 사용자의 닉네임을 별도로 관리하는 프로바이더입니다.
  DisplayNameProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'displayNameProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$displayNameHash();

  @$internal
  @override
  DisplayName create() => DisplayName();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$displayNameHash() => r'c1d3b14ed0adc3dc4a6da263687283f2912aa1d9';

/// 사용자의 닉네임을 별도로 관리하는 프로바이더입니다.

abstract class _$DisplayName extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

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

String _$authStateHash() => r'91d3309f20a95c681d08b7bebec0851a77682fd0';

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

String _$authControllerHash() => r'd2e4a474c9ab6cb6b8343007116efd843113a36c';

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
