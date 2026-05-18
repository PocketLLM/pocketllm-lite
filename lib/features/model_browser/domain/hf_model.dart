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
  });

  factory HFModel.fromJson(Map<String, dynamic> json) {
    final fullId = json['id'] as String;
    final parts = fullId.split('/');
    final author = parts.length > 1 ? parts[0] : '';
    final name = parts.length > 1 ? parts.sublist(1).join('/') : fullId;

    return HFModel(
      id: fullId,
      author: author,
      name: name,
      downloads: json['downloads'] ?? 0,
      likes: json['likes'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      description: json['description'], // May be fetched separately
      lastModified: DateTime.parse(
        json['lastModified'] ?? DateTime.now().toIso8601String(),
      ),
      pipelineTag: json['pipeline_tag'],
      isGated: json['gated'] == 'true' || json['gated'] == true,
    );
  }
}

class HFModelFile {
  final String filename;
  final int sizeBytes;
  final String type; // e.g., 'Q4_K_M'
  final String url;
  final String commitOid;

  const HFModelFile({
    required this.filename,
    required this.sizeBytes,
    required this.type,
    required this.url,
    required this.commitOid,
  });

  factory HFModelFile.fromJson(Map<String, dynamic> json, String modelId) {
    return HFModelFile(
      filename: json['path'],
      sizeBytes: json['size'] ?? 0,
      type: _extractQuantizationType(json['path']),
      url: 'https://huggingface.co/$modelId/resolve/main/${json['path']}',
      commitOid: json['oid'] ?? '',
    );
  }

  static String _extractQuantizationType(String filename) {
    // Matches patterns like Q4_K_M, Q8_0, FP16
    final regex = RegExp(r'(Q\d_[K_M\d]+|FP16|FP32)', caseSensitive: false);
    final match = regex.firstMatch(filename);
    return match != null ? match.group(0)!.toUpperCase() : 'Unknown';
  }
}
