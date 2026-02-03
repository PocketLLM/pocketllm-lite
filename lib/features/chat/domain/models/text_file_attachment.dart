import 'package:hive/hive.dart';

part 'text_file_attachment.g.dart';

@HiveType(typeId: 3)
class TextFileAttachment {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String content;

  @HiveField(2)
  final int sizeBytes;

  @HiveField(3)
  final String? mimeType;

  TextFileAttachment({
    required this.name,
    required this.content,
    required this.sizeBytes,
    this.mimeType,
  });

  TextFileAttachment copyWith({
    String? name,
    String? content,
    int? sizeBytes,
    String? mimeType,
  }) {
    return TextFileAttachment(
      name: name ?? this.name,
      content: content ?? this.content,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextFileAttachment &&
        other.name == name &&
        other.content == content &&
        other.sizeBytes == sizeBytes &&
        other.mimeType == mimeType;
  }

  @override
  int get hashCode => Object.hash(name, content, sizeBytes, mimeType);
}
