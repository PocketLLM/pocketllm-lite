import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RemoteProviderConfig {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String modelId;
  final Map<String, String> customHeaders;
  final int contextLength;
  final bool supportsVision;
  final bool supportsTools;
  final bool streaming;

  const RemoteProviderConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.apiKey = '',
    required this.modelId,
    this.customHeaders = const {},
    this.contextLength = 8192,
    this.supportsVision = false,
    this.supportsTools = false,
    this.streaming = true,
  });

  String get selectionId => encodeSelection(id, modelId);

  static String encodeSelection(String providerId, String modelId) =>
      'remote::${Uri.encodeComponent(providerId)}::${Uri.encodeComponent(modelId)}';

  static ({String providerId, String modelId})? decodeSelection(String value) {
    final parts = value.split('::');
    if (parts.length != 3 || parts.first != 'remote') return null;
    return (
      providerId: Uri.decodeComponent(parts[1]),
      modelId: Uri.decodeComponent(parts[2]),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'modelId': modelId,
        'customHeaders': customHeaders,
        'contextLength': contextLength,
        'supportsVision': supportsVision,
        'supportsTools': supportsTools,
        'streaming': streaming,
      };

  factory RemoteProviderConfig.fromJson(Map<String, dynamic> json) {
    return RemoteProviderConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      apiKey: json['apiKey'] as String? ?? '',
      modelId: json['modelId'] as String,
      customHeaders: Map<String, String>.from(
        json['customHeaders'] as Map? ?? const {},
      ),
      contextLength: json['contextLength'] as int? ?? 8192,
      supportsVision: json['supportsVision'] as bool? ?? false,
      supportsTools: json['supportsTools'] as bool? ?? false,
      streaming: json['streaming'] as bool? ?? true,
    );
  }
}

class RemoteProviderRegistry {
  static const _storageKey = 'remote_provider_configs_v1';
  final FlutterSecureStorage _storage;

  const RemoteProviderRegistry({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<List<RemoteProviderConfig>> load() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(
          (item) => RemoteProviderConfig.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<void> save(RemoteProviderConfig config) async {
    final configs = [...await load()];
    final index = configs.indexWhere((item) => item.id == config.id);
    if (index >= 0) {
      configs[index] = config;
    } else {
      configs.add(config);
    }
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(configs.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> delete(String id) async {
    final configs = [...await load()]..removeWhere((item) => item.id == id);
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(configs.map((item) => item.toJson()).toList()),
    );
  }

  Future<RemoteProviderConfig?> find(String id) async {
    final matches = (await load()).where((item) => item.id == id);
    return matches.isEmpty ? null : matches.first;
  }
}
