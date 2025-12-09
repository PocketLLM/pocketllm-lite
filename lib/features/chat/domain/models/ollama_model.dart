class OllamaModel {
  final String name;
  final String modifiedAt;
  final int size;
  final String digest;

  OllamaModel({
    required this.name,
    required this.modifiedAt,
    required this.size,
    required this.digest,
  });

  factory OllamaModel.fromJson(Map<String, dynamic> json) {
    return OllamaModel(
      name: json['name'] as String,
      modifiedAt: json['modified_at'] as String,
      size: json['size'] as int,
      digest: json['digest'] as String,
    );
  }
}
