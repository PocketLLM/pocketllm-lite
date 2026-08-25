enum ModelSupportStatus {
  installedUntested,
  tested,
  experimental,
  backendUnsupported,
  notRecommended,
}

extension ModelSupportStatusLabel on ModelSupportStatus {
  String get label => switch (this) {
        ModelSupportStatus.installedUntested => 'Installed — not tested yet',
        ModelSupportStatus.tested => 'Tested on this device',
        ModelSupportStatus.experimental => 'Experimental',
        ModelSupportStatus.backendUnsupported => 'Backend unsupported',
        ModelSupportStatus.notRecommended => 'Not recommended for this device',
      };
}

class ModelManifest {
  final int schemaVersion;
  final String id;
  final String displayName;
  final String source;
  final String? provider;
  final String? family;
  final String? architecture;
  final double? parametersBillions;
  final String? quantization;
  final int fileSizeBytes;
  final int? contextLength;
  final List<String> capabilities;
  final bool? supportsVision;
  final bool? supportsTools;
  final bool? supportsReasoning;
  final bool? supportsEmbeddings;
  final String? license;
  final String? licenseUrl;
  final String? chatTemplate;
  final String? toolFormat;
  final String? thinkingFormat;
  final List<String> backendCompatibility;
  final String? minimumBackendVersion;
  final String? sha256;
  final ModelSupportStatus status;
  final DateTime lastVerified;

  const ModelManifest({
    this.schemaVersion = 1,
    required this.id,
    required this.displayName,
    required this.source,
    this.provider,
    this.family,
    this.architecture,
    this.parametersBillions,
    this.quantization,
    required this.fileSizeBytes,
    this.contextLength,
    this.capabilities = const [],
    this.supportsVision,
    this.supportsTools,
    this.supportsReasoning,
    this.supportsEmbeddings,
    this.license,
    this.licenseUrl,
    this.chatTemplate,
    this.toolFormat,
    this.thinkingFormat,
    this.backendCompatibility = const [],
    this.minimumBackendVersion,
    this.sha256,
    this.status = ModelSupportStatus.experimental,
    required this.lastVerified,
  });

  ModelManifest copyWith({
    List<String>? capabilities,
    bool? supportsVision,
    bool? supportsTools,
    bool? supportsReasoning,
    bool? supportsEmbeddings,
    ModelSupportStatus? status,
    DateTime? lastVerified,
    String? sha256,
  }) {
    return ModelManifest(
      schemaVersion: schemaVersion,
      id: id,
      displayName: displayName,
      source: source,
      provider: provider,
      family: family,
      architecture: architecture,
      parametersBillions: parametersBillions,
      quantization: quantization,
      fileSizeBytes: fileSizeBytes,
      contextLength: contextLength,
      capabilities: capabilities ?? this.capabilities,
      supportsVision: supportsVision ?? this.supportsVision,
      supportsTools: supportsTools ?? this.supportsTools,
      supportsReasoning: supportsReasoning ?? this.supportsReasoning,
      supportsEmbeddings: supportsEmbeddings ?? this.supportsEmbeddings,
      license: license,
      licenseUrl: licenseUrl,
      chatTemplate: chatTemplate,
      toolFormat: toolFormat,
      thinkingFormat: thinkingFormat,
      backendCompatibility: backendCompatibility,
      minimumBackendVersion: minimumBackendVersion,
      sha256: sha256 ?? this.sha256,
      status: status ?? this.status,
      lastVerified: lastVerified ?? this.lastVerified,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'displayName': displayName,
        'source': source,
        'provider': provider,
        'family': family,
        'architecture': architecture,
        'parametersBillions': parametersBillions,
        'quantization': quantization,
        'fileSizeBytes': fileSizeBytes,
        'contextLength': contextLength,
        'capabilities': capabilities,
        'supportsVision': supportsVision,
        'supportsTools': supportsTools,
        'supportsReasoning': supportsReasoning,
        'supportsEmbeddings': supportsEmbeddings,
        'license': license,
        'licenseUrl': licenseUrl,
        'chatTemplate': chatTemplate,
        'toolFormat': toolFormat,
        'thinkingFormat': thinkingFormat,
        'backendCompatibility': backendCompatibility,
        'minimumBackendVersion': minimumBackendVersion,
        'sha256': sha256,
        'status': status.name,
        'lastVerified': lastVerified.toIso8601String(),
      };

  factory ModelManifest.fromJson(Map<String, dynamic> json) {
    return ModelManifest(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      source: json['source'] as String? ?? 'unknown',
      provider: json['provider'] as String?,
      family: json['family'] as String?,
      architecture: json['architecture'] as String?,
      parametersBillions: (json['parametersBillions'] as num?)?.toDouble(),
      quantization: json['quantization'] as String?,
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      contextLength: json['contextLength'] as int?,
      capabilities:
          List<String>.from(json['capabilities'] as List? ?? const []),
      supportsVision: json['supportsVision'] as bool?,
      supportsTools: json['supportsTools'] as bool?,
      supportsReasoning: json['supportsReasoning'] as bool?,
      supportsEmbeddings: json['supportsEmbeddings'] as bool?,
      license: json['license'] as String?,
      licenseUrl: json['licenseUrl'] as String?,
      chatTemplate: json['chatTemplate'] as String?,
      toolFormat: json['toolFormat'] as String?,
      thinkingFormat: json['thinkingFormat'] as String?,
      backendCompatibility: List<String>.from(
        json['backendCompatibility'] as List? ?? const [],
      ),
      minimumBackendVersion: json['minimumBackendVersion'] as String?,
      sha256: json['sha256'] as String?,
      status: ModelSupportStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => ModelSupportStatus.experimental,
      ),
      lastVerified: DateTime.tryParse(json['lastVerified'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
