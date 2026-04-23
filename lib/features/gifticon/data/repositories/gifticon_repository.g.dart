// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gifticon_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(gifticonRepository)
final gifticonRepositoryProvider = GifticonRepositoryProvider._();

final class GifticonRepositoryProvider
    extends
        $FunctionalProvider<
          GifticonRepository,
          GifticonRepository,
          GifticonRepository
        >
    with $Provider<GifticonRepository> {
  GifticonRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gifticonRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gifticonRepositoryHash();

  @$internal
  @override
  $ProviderElement<GifticonRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GifticonRepository create(Ref ref) {
    return gifticonRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GifticonRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GifticonRepository>(value),
    );
  }
}

String _$gifticonRepositoryHash() =>
    r'2cec540a3160bde2ac5c57e7e6a07391b80483ee';
