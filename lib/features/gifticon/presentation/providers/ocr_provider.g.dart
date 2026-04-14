// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ocr_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ocrService)
final ocrServiceProvider = OcrServiceProvider._();

final class OcrServiceProvider
    extends $FunctionalProvider<OcrService, OcrService, OcrService>
    with $Provider<OcrService> {
  OcrServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ocrServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ocrServiceHash();

  @$internal
  @override
  $ProviderElement<OcrService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OcrService create(Ref ref) {
    return ocrService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OcrService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OcrService>(value),
    );
  }
}

String _$ocrServiceHash() => r'62d38a0beb2f4ecd738f824593a69c97b065c0db';

@ProviderFor(OcrState)
final ocrStateProvider = OcrStateProvider._();

final class OcrStateProvider
    extends $NotifierProvider<OcrState, AsyncValue<OcrResultModel?>> {
  OcrStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ocrStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ocrStateHash();

  @$internal
  @override
  OcrState create() => OcrState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<OcrResultModel?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<OcrResultModel?>>(value),
    );
  }
}

String _$ocrStateHash() => r'170f7fadada755927fabeb7607b10a629e63fe11';

abstract class _$OcrState extends $Notifier<AsyncValue<OcrResultModel?>> {
  AsyncValue<OcrResultModel?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<OcrResultModel?>, AsyncValue<OcrResultModel?>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<OcrResultModel?>,
                AsyncValue<OcrResultModel?>
              >,
              AsyncValue<OcrResultModel?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
