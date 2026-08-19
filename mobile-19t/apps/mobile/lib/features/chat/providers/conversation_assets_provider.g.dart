// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_assets_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$conversationAssetsSummaryHash() =>
    r'654a3f1647c7fa4858ef8ce2252601faf0d0593f';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [conversationAssetsSummary].
@ProviderFor(conversationAssetsSummary)
const conversationAssetsSummaryProvider = ConversationAssetsSummaryFamily();

/// See also [conversationAssetsSummary].
class ConversationAssetsSummaryFamily
    extends Family<AsyncValue<ConversationAssetsSummary>> {
  /// See also [conversationAssetsSummary].
  const ConversationAssetsSummaryFamily();

  /// See also [conversationAssetsSummary].
  ConversationAssetsSummaryProvider call(String conversationId) {
    return ConversationAssetsSummaryProvider(conversationId);
  }

  @override
  ConversationAssetsSummaryProvider getProviderOverride(
    covariant ConversationAssetsSummaryProvider provider,
  ) {
    return call(provider.conversationId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'conversationAssetsSummaryProvider';
}

/// See also [conversationAssetsSummary].
class ConversationAssetsSummaryProvider
    extends AutoDisposeFutureProvider<ConversationAssetsSummary> {
  /// See also [conversationAssetsSummary].
  ConversationAssetsSummaryProvider(String conversationId)
    : this._internal(
        (ref) => conversationAssetsSummary(
          ref as ConversationAssetsSummaryRef,
          conversationId,
        ),
        from: conversationAssetsSummaryProvider,
        name: r'conversationAssetsSummaryProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$conversationAssetsSummaryHash,
        dependencies: ConversationAssetsSummaryFamily._dependencies,
        allTransitiveDependencies:
            ConversationAssetsSummaryFamily._allTransitiveDependencies,
        conversationId: conversationId,
      );

  ConversationAssetsSummaryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.conversationId,
  }) : super.internal();

  final String conversationId;

  @override
  Override overrideWith(
    FutureOr<ConversationAssetsSummary> Function(
      ConversationAssetsSummaryRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ConversationAssetsSummaryProvider._internal(
        (ref) => create(ref as ConversationAssetsSummaryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        conversationId: conversationId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ConversationAssetsSummary> createElement() {
    return _ConversationAssetsSummaryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationAssetsSummaryProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ConversationAssetsSummaryRef
    on AutoDisposeFutureProviderRef<ConversationAssetsSummary> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _ConversationAssetsSummaryProviderElement
    extends AutoDisposeFutureProviderElement<ConversationAssetsSummary>
    with ConversationAssetsSummaryRef {
  _ConversationAssetsSummaryProviderElement(super.provider);

  @override
  String get conversationId =>
      (origin as ConversationAssetsSummaryProvider).conversationId;
}

String _$conversationMediaListHash() =>
    r'62b99087a4050eb0301fc9533adb535f602d1805';

abstract class _$ConversationMediaList
    extends BuildlessAutoDisposeAsyncNotifier<List<ConversationMediaItem>> {
  late final String conversationId;

  FutureOr<List<ConversationMediaItem>> build(String conversationId);
}

/// See also [ConversationMediaList].
@ProviderFor(ConversationMediaList)
const conversationMediaListProvider = ConversationMediaListFamily();

/// See also [ConversationMediaList].
class ConversationMediaListFamily
    extends Family<AsyncValue<List<ConversationMediaItem>>> {
  /// See also [ConversationMediaList].
  const ConversationMediaListFamily();

  /// See also [ConversationMediaList].
  ConversationMediaListProvider call(String conversationId) {
    return ConversationMediaListProvider(conversationId);
  }

  @override
  ConversationMediaListProvider getProviderOverride(
    covariant ConversationMediaListProvider provider,
  ) {
    return call(provider.conversationId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'conversationMediaListProvider';
}

/// See also [ConversationMediaList].
class ConversationMediaListProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          ConversationMediaList,
          List<ConversationMediaItem>
        > {
  /// See also [ConversationMediaList].
  ConversationMediaListProvider(String conversationId)
    : this._internal(
        () => ConversationMediaList()..conversationId = conversationId,
        from: conversationMediaListProvider,
        name: r'conversationMediaListProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$conversationMediaListHash,
        dependencies: ConversationMediaListFamily._dependencies,
        allTransitiveDependencies:
            ConversationMediaListFamily._allTransitiveDependencies,
        conversationId: conversationId,
      );

  ConversationMediaListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.conversationId,
  }) : super.internal();

  final String conversationId;

  @override
  FutureOr<List<ConversationMediaItem>> runNotifierBuild(
    covariant ConversationMediaList notifier,
  ) {
    return notifier.build(conversationId);
  }

  @override
  Override overrideWith(ConversationMediaList Function() create) {
    return ProviderOverride(
      origin: this,
      override: ConversationMediaListProvider._internal(
        () => create()..conversationId = conversationId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        conversationId: conversationId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<
    ConversationMediaList,
    List<ConversationMediaItem>
  >
  createElement() {
    return _ConversationMediaListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationMediaListProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ConversationMediaListRef
    on AutoDisposeAsyncNotifierProviderRef<List<ConversationMediaItem>> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _ConversationMediaListProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          ConversationMediaList,
          List<ConversationMediaItem>
        >
    with ConversationMediaListRef {
  _ConversationMediaListProviderElement(super.provider);

  @override
  String get conversationId =>
      (origin as ConversationMediaListProvider).conversationId;
}

String _$conversationFilesListHash() =>
    r'f1408514048d4b976ffe592360db4e8f31008a41';

abstract class _$ConversationFilesList
    extends BuildlessAutoDisposeAsyncNotifier<List<ConversationFileItem>> {
  late final String conversationId;

  FutureOr<List<ConversationFileItem>> build(String conversationId);
}

/// See also [ConversationFilesList].
@ProviderFor(ConversationFilesList)
const conversationFilesListProvider = ConversationFilesListFamily();

/// See also [ConversationFilesList].
class ConversationFilesListFamily
    extends Family<AsyncValue<List<ConversationFileItem>>> {
  /// See also [ConversationFilesList].
  const ConversationFilesListFamily();

  /// See also [ConversationFilesList].
  ConversationFilesListProvider call(String conversationId) {
    return ConversationFilesListProvider(conversationId);
  }

  @override
  ConversationFilesListProvider getProviderOverride(
    covariant ConversationFilesListProvider provider,
  ) {
    return call(provider.conversationId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'conversationFilesListProvider';
}

/// See also [ConversationFilesList].
class ConversationFilesListProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          ConversationFilesList,
          List<ConversationFileItem>
        > {
  /// See also [ConversationFilesList].
  ConversationFilesListProvider(String conversationId)
    : this._internal(
        () => ConversationFilesList()..conversationId = conversationId,
        from: conversationFilesListProvider,
        name: r'conversationFilesListProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$conversationFilesListHash,
        dependencies: ConversationFilesListFamily._dependencies,
        allTransitiveDependencies:
            ConversationFilesListFamily._allTransitiveDependencies,
        conversationId: conversationId,
      );

  ConversationFilesListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.conversationId,
  }) : super.internal();

  final String conversationId;

  @override
  FutureOr<List<ConversationFileItem>> runNotifierBuild(
    covariant ConversationFilesList notifier,
  ) {
    return notifier.build(conversationId);
  }

  @override
  Override overrideWith(ConversationFilesList Function() create) {
    return ProviderOverride(
      origin: this,
      override: ConversationFilesListProvider._internal(
        () => create()..conversationId = conversationId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        conversationId: conversationId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<
    ConversationFilesList,
    List<ConversationFileItem>
  >
  createElement() {
    return _ConversationFilesListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationFilesListProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ConversationFilesListRef
    on AutoDisposeAsyncNotifierProviderRef<List<ConversationFileItem>> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _ConversationFilesListProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          ConversationFilesList,
          List<ConversationFileItem>
        >
    with ConversationFilesListRef {
  _ConversationFilesListProviderElement(super.provider);

  @override
  String get conversationId =>
      (origin as ConversationFilesListProvider).conversationId;
}

String _$conversationLinksListHash() =>
    r'b9889c7a652d7e964ad5f367e81670f7af2666de';

abstract class _$ConversationLinksList
    extends BuildlessAutoDisposeAsyncNotifier<List<ConversationLinkItem>> {
  late final String conversationId;

  FutureOr<List<ConversationLinkItem>> build(String conversationId);
}

/// See also [ConversationLinksList].
@ProviderFor(ConversationLinksList)
const conversationLinksListProvider = ConversationLinksListFamily();

/// See also [ConversationLinksList].
class ConversationLinksListFamily
    extends Family<AsyncValue<List<ConversationLinkItem>>> {
  /// See also [ConversationLinksList].
  const ConversationLinksListFamily();

  /// See also [ConversationLinksList].
  ConversationLinksListProvider call(String conversationId) {
    return ConversationLinksListProvider(conversationId);
  }

  @override
  ConversationLinksListProvider getProviderOverride(
    covariant ConversationLinksListProvider provider,
  ) {
    return call(provider.conversationId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'conversationLinksListProvider';
}

/// See also [ConversationLinksList].
class ConversationLinksListProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          ConversationLinksList,
          List<ConversationLinkItem>
        > {
  /// See also [ConversationLinksList].
  ConversationLinksListProvider(String conversationId)
    : this._internal(
        () => ConversationLinksList()..conversationId = conversationId,
        from: conversationLinksListProvider,
        name: r'conversationLinksListProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$conversationLinksListHash,
        dependencies: ConversationLinksListFamily._dependencies,
        allTransitiveDependencies:
            ConversationLinksListFamily._allTransitiveDependencies,
        conversationId: conversationId,
      );

  ConversationLinksListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.conversationId,
  }) : super.internal();

  final String conversationId;

  @override
  FutureOr<List<ConversationLinkItem>> runNotifierBuild(
    covariant ConversationLinksList notifier,
  ) {
    return notifier.build(conversationId);
  }

  @override
  Override overrideWith(ConversationLinksList Function() create) {
    return ProviderOverride(
      origin: this,
      override: ConversationLinksListProvider._internal(
        () => create()..conversationId = conversationId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        conversationId: conversationId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<
    ConversationLinksList,
    List<ConversationLinkItem>
  >
  createElement() {
    return _ConversationLinksListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationLinksListProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ConversationLinksListRef
    on AutoDisposeAsyncNotifierProviderRef<List<ConversationLinkItem>> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _ConversationLinksListProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          ConversationLinksList,
          List<ConversationLinkItem>
        >
    with ConversationLinksListRef {
  _ConversationLinksListProviderElement(super.provider);

  @override
  String get conversationId =>
      (origin as ConversationLinksListProvider).conversationId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
