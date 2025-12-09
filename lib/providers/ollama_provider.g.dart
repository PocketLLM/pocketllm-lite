// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ollama_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$ollamaServiceHash() => r'b276fa7190341c01fe87bbaceb38f13a2665d4d1';

/// See also [ollamaService].
@ProviderFor(ollamaService)
final ollamaServiceProvider = AutoDisposeProvider<OllamaService>.internal(
  ollamaService,
  name: r'ollamaServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ollamaServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OllamaServiceRef = AutoDisposeProviderRef<OllamaService>;
String _$connectionStatusHash() => r'0f9bd12e18aa14c0c10e687dcecaa9872bede130';

/// See also [ConnectionStatus].
@ProviderFor(ConnectionStatus)
final connectionStatusProvider =
    AutoDisposeAsyncNotifierProvider<ConnectionStatus, bool>.internal(
  ConnectionStatus.new,
  name: r'connectionStatusProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$connectionStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ConnectionStatus = AutoDisposeAsyncNotifier<bool>;
String _$availableModelsHash() => r'5a4ffb1b9b43866271cc6b8ba6cb4cc1ce24c9d9';

/// See also [AvailableModels].
@ProviderFor(AvailableModels)
final availableModelsProvider = AutoDisposeAsyncNotifierProvider<
    AvailableModels, List<OllamaModel>>.internal(
  AvailableModels.new,
  name: r'availableModelsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$availableModelsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AvailableModels = AutoDisposeAsyncNotifier<List<OllamaModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
