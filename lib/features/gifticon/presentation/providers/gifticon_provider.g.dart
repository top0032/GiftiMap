// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gifticon_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GifticonList)
final gifticonListProvider = GifticonListProvider._();

final class GifticonListProvider
    extends $AsyncNotifierProvider<GifticonList, List<GifticonModel>> {
  GifticonListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gifticonListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gifticonListHash();

  @$internal
  @override
  GifticonList create() => GifticonList();
}

String _$gifticonListHash() => r'45915693d0102630613cb84aa304190ecc294127';

abstract class _$GifticonList extends $AsyncNotifier<List<GifticonModel>> {
  FutureOr<List<GifticonModel>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<GifticonModel>>, List<GifticonModel>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<GifticonModel>>, List<GifticonModel>>,
              AsyncValue<List<GifticonModel>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
