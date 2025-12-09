class OllamaModel {
  final String name;
  final String? modifiedAt;
  final int? size;
  final String? digest;
  final bool supportsVision;

  OllamaModel({
    required this.name,
    this.modifiedAt,
    this.size,
    this.digest,
    this.supportsVision = false,
  });

  factory OllamaModel.fromJson(Map<String, dynamic> json) {
    return OllamaModel(
      name: json['name'] as String,
      modifiedAt: json['modified_at'] as String?,
      size: json['size'] as int?,
      digest: json['digest'] as String?,
      supportsVision: _checkVisionSupport(json['name'] as String),
    );
  }

  static bool _checkVisionSupport(String name) {
    final lowerName = name.toLowerCase();
    return lowerName.contains('llava') ||
        lowerName.contains('moondream') ||
        lowerName.contains('bakllava') ||
        lowerName.contains('llama-vision') ||
        lowerName.contains('minicpm');
  }
}
