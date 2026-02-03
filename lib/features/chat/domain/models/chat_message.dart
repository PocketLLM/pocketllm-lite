import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'text_file_attachment.dart';

part 'chat_message.g.dart';

@HiveType(typeId: 0)
class ChatMessage {
  @HiveField(0)
  final String role; // 'user' or 'assistant'

  @HiveField(1)
  final String content;

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final List<String>? images; // Base64 strings

  @HiveField(4)
  final List<TextFileAttachment>? attachments;

  // Cache hashCode to avoid expensive re-calculation, especially for messages with images.
  // This is safe because the images list is made unmodifiable in the constructor.
  // ignore: prefer_final_fields
  int? _cachedHashCode;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    List<String>? images,
    List<TextFileAttachment>? attachments,
  })  : images = images != null ? List.unmodifiable(images) : null,
        attachments =
            attachments != null ? List.unmodifiable(attachments) : null;

  ChatMessage copyWith({
    String? role,
    String? content,
    DateTime? timestamp,
    List<String>? images,
    List<TextFileAttachment>? attachments,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      images: images ?? this.images,
      attachments: attachments ?? this.attachments,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatMessage &&
        other.role == role &&
        other.content == content &&
        other.timestamp == timestamp &&
        listEquals(other.images, images) &&
        listEquals(other.attachments, attachments);
  }

  @override
  int get hashCode {
    _cachedHashCode ??= Object.hash(
      role,
      content,
      timestamp,
      // Use Object.hashAll for lists to generate a consistent hash code based on content
      images != null ? Object.hashAll(images!) : null,
      attachments != null ? Object.hashAll(attachments!) : null,
    );
    return _cachedHashCode!;
  }
}
