// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$storageServiceHash() => r'b9eb09cfea0c265efa80435bdffda55cb5e6d8ba';

/// See also [storageService].
@ProviderFor(storageService)
final storageServiceProvider = AutoDisposeProvider<StorageService>.internal(
  storageService,
  name: r'storageServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$storageServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StorageServiceRef = AutoDisposeProviderRef<StorageService>;
String _$chatRepositoryHash() => r'86d84359fa090c6db9e96c055801c82a7b2ec5fc';

/// See also [chatRepository].
@ProviderFor(chatRepository)
final chatRepositoryProvider = AutoDisposeProvider<ChatRepository>.internal(
  chatRepository,
  name: r'chatRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chatRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ChatRepositoryRef = AutoDisposeProviderRef<ChatRepository>;
String _$chatHistoryHash() => r'09decffbbe52840b8f65ddbbb2c0dfe7dad4057a';

/// See also [ChatHistory].
@ProviderFor(ChatHistory)
final chatHistoryProvider =
    AutoDisposeNotifierProvider<ChatHistory, List<ChatSession>>.internal(
  ChatHistory.new,
  name: r'chatHistoryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$chatHistoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChatHistory = AutoDisposeNotifier<List<ChatSession>>;
String _$currentChatSessionHash() =>
    r'a1701d59f3e70933e1c87a00b5e0238fd6f6e84b';

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

abstract class _$CurrentChatSession
    extends BuildlessAutoDisposeNotifier<ChatSession?> {
  late final String? chatId;

  ChatSession? build(
    String? chatId,
  );
}

/// See also [CurrentChatSession].
@ProviderFor(CurrentChatSession)
const currentChatSessionProvider = CurrentChatSessionFamily();

/// See also [CurrentChatSession].
class CurrentChatSessionFamily extends Family<ChatSession?> {
  /// See also [CurrentChatSession].
  const CurrentChatSessionFamily();

  /// See also [CurrentChatSession].
  CurrentChatSessionProvider call(
    String? chatId,
  ) {
    return CurrentChatSessionProvider(
      chatId,
    );
  }

  @override
  CurrentChatSessionProvider getProviderOverride(
    covariant CurrentChatSessionProvider provider,
  ) {
    return call(
      provider.chatId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'currentChatSessionProvider';
}

/// See also [CurrentChatSession].
class CurrentChatSessionProvider
    extends AutoDisposeNotifierProviderImpl<CurrentChatSession, ChatSession?> {
  /// See also [CurrentChatSession].
  CurrentChatSessionProvider(
    String? chatId,
  ) : this._internal(
          () => CurrentChatSession()..chatId = chatId,
          from: currentChatSessionProvider,
          name: r'currentChatSessionProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$currentChatSessionHash,
          dependencies: CurrentChatSessionFamily._dependencies,
          allTransitiveDependencies:
              CurrentChatSessionFamily._allTransitiveDependencies,
          chatId: chatId,
        );

  CurrentChatSessionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.chatId,
  }) : super.internal();

  final String? chatId;

  @override
  ChatSession? runNotifierBuild(
    covariant CurrentChatSession notifier,
  ) {
    return notifier.build(
      chatId,
    );
  }

  @override
  Override overrideWith(CurrentChatSession Function() create) {
    return ProviderOverride(
      origin: this,
      override: CurrentChatSessionProvider._internal(
        () => create()..chatId = chatId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        chatId: chatId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<CurrentChatSession, ChatSession?>
      createElement() {
    return _CurrentChatSessionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CurrentChatSessionProvider && other.chatId == chatId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, chatId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CurrentChatSessionRef on AutoDisposeNotifierProviderRef<ChatSession?> {
  /// The parameter `chatId` of this provider.
  String? get chatId;
}

class _CurrentChatSessionProviderElement
    extends AutoDisposeNotifierProviderElement<CurrentChatSession, ChatSession?>
    with CurrentChatSessionRef {
  _CurrentChatSessionProviderElement(super.provider);

  @override
  String? get chatId => (origin as CurrentChatSessionProvider).chatId;
}

String _$chatControllerHash() => r'd59ab8b17317b4d2e63b5c9b3ee8eb5cad04a81b';

/// See also [ChatController].
@ProviderFor(ChatController)
final chatControllerProvider =
    AutoDisposeAsyncNotifierProvider<ChatController, void>.internal(
  ChatController.new,
  name: r'chatControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chatControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChatController = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
