class HFModel {
  final String id;
  final String author;
  final String name;
  final int downloads;
  final int likes;
  final List<String> tags;
  final String? description;
  final DateTime lastModified;
  final String? pipelineTag;
  final bool isGated;
  final String? license;
  final String? licenseUrl;

  const HFModel({
    required this.id,
    required this.author,
    required this.name,
    required this.downloads,
    required this.likes,
    required this.tags,
    this.description,
    required this.lastModified,
    this.pipelineTag,
    required this.isGated,
    this.license,
    this.licenseUrl,
  });

  factory HFModel.fromJson(Map<String, dynamic> json) {
    final fullId = json['id'] as String;
    final parts = fullId.split('/');
    final author = parts.length > 1 ? parts[0] : '';
    final name = parts.length > 1 ? parts.sublist(1).join('/') : fullId;

    final tags = List<String>.from(json['tags'] ?? []);
    final cardData = json['cardData'] is Map
        ? Map<String, dynamic>.from(json['cardData'] as Map)
        : const <String, dynamic>{};
    final taggedLicense = tags
        .where((tag) => tag.startsWith('license:'))
        .map((tag) => tag.substring('license:'.length))
        .firstOrNull;
    final license = cardData['license'] as String? ?? taggedLicense;
    return HFModel(
      id: fullId,
      author: author,
      name: name,
      downloads: json['downloads'] ?? 0,
      likes: json['likes'] ?? 0,
      tags: tags,
      description: json['description'], // May be fetched separately
      lastModified: DateTime.parse(
        json['lastModified'] ?? DateTime.now().toIso8601String(),
      ),
      pipelineTag: json['pipeline_tag'],
      isGated: json['gated'] == 'true' || json['gated'] == true,
      license: license,
      licenseUrl: license == null
          ? null
          : 'https://huggingface.co/$fullId/blob/main/LICENSE',
    );
  }
}

class HFModelFile {
  final String filename;
  final int sizeBytes;
  final String type; // e.g., 'Q4_K_M'
  final String url;
  final String commitOid;
  final String? sha256;

  const HFModelFile({
    required this.filename,
    required this.sizeBytes,
    required this.type,
    required this.url,
    required this.commitOid,
    this.sha256,
  });

  factory HFModelFile.fromJson(Map<String, dynamic> json, String modelId) {
    final lfs = json['lfs'] is Map
        ? Map<String, dynamic>.from(json['lfs'] as Map)
        : const <String, dynamic>{};
    final path = json['path'] as String;
    return HFModelFile(
      filename: path,
      sizeBytes: (lfs['size'] ?? json['size'] ?? 0) as int,
      type: _extractQuantizationType(path),
      url: Uri.https(
        'huggingface.co',
        '/$modelId/resolve/main/$path',
      ).toString(),
      commitOid: json['oid'] ?? '',
      sha256: lfs['sha256'] as String?,
    );
  }

  static String _extractQuantizationType(String filename) {
    // Matches patterns like Q4_K_M, Q8_0, FP16
    final regex = RegExp(r'(Q\d_[K_M\d]+|FP16|FP32)', caseSensitive: false);
    final match = regex.firstMatch(filename);
    return match != null ? match.group(0)!.toUpperCase() : 'Unknown';
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
