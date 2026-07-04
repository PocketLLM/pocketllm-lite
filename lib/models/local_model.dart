enum DownloadStatus {
  notDownloaded,
  downloading,
  downloaded,
}

class LocalModel {
  final String id;
  final String name;
  final String downloadUrl;
  final int fileSizeInBytes;
  final String? localPath;
  final DownloadStatus status;
  final double downloadProgress;
  final bool isCustomImport;
  final String? description;
  final String? provider;
  final String? family;
  final List<String>? capabilities;
  final Map<String, String>? benchmarks;

  const LocalModel({
    required this.id,
    required this.name,
    required this.downloadUrl,
    required this.fileSizeInBytes,
    this.localPath,
    this.status = DownloadStatus.notDownloaded,
    this.downloadProgress = 0.0,
    this.isCustomImport = false,
    this.description,
    this.provider,
    this.family,
    this.capabilities,
    this.benchmarks,
  });

  /// Factory constructors or helpers to classify GGUF variants
  bool get isGemma => id.toLowerCase().contains('gemma');
  bool get isLlama => id.toLowerCase().contains('llama');
  bool get isQwen => id.toLowerCase().contains('qwen');

  /// Helper to convert size in bytes to a human-readable string
  String get formattedSize {
    if (fileSizeInBytes <= 0) return 'Unknown size';
    final gb = fileSizeInBytes / (1024 * 1024 * 1024);
    if (gb >= 1.0) {
      return '${gb.toStringAsFixed(2)} GB';
    }
    final mb = fileSizeInBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  LocalModel copyWith({
    String? id,
    String? name,
    String? downloadUrl,
    int? fileSizeInBytes,
    String? localPath,
    DownloadStatus? status,
    double? downloadProgress,
    bool? isCustomImport,
    String? description,
    String? provider,
    String? family,
    List<String>? capabilities,
    Map<String, String>? benchmarks,
  }) {
    return LocalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileSizeInBytes: fileSizeInBytes ?? this.fileSizeInBytes,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isCustomImport: isCustomImport ?? this.isCustomImport,
      description: description ?? this.description,
      provider: provider ?? this.provider,
      family: family ?? this.family,
      capabilities: capabilities ?? this.capabilities,
      benchmarks: benchmarks ?? this.benchmarks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'downloadUrl': downloadUrl,
      'fileSizeInBytes': fileSizeInBytes,
      'localPath': localPath,
      'status': status.index,
      'downloadProgress': downloadProgress,
      'isCustomImport': isCustomImport ? 1 : 0,
      'description': description,
      'provider': provider,
      'family': family,
      'capabilities': capabilities,
      'benchmarks': benchmarks,
    };
  }

  factory LocalModel.fromMap(Map<String, dynamic> map) {
    return LocalModel(
      id: map['id'] as String,
      name: map['name'] as String,
      downloadUrl: map['downloadUrl'] as String,
      fileSizeInBytes: map['fileSizeInBytes'] as int,
      localPath: map['localPath'] as String?,
      status: DownloadStatus.values[map['status'] as int? ?? 0],
      downloadProgress: (map['downloadProgress'] as num? ?? 0.0).toDouble(),
      isCustomImport: (map['isCustomImport'] as int? ?? 0) == 1,
      description: map['description'] as String?,
      provider: map['provider'] as String?,
      family: map['family'] as String?,
      capabilities: (map['capabilities'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      benchmarks: (map['benchmarks'] as Map<dynamic, dynamic>?)
          ?.map((k, v) => MapEntry(k as String, v as String)),
    );
  }
}
