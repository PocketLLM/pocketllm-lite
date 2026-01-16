import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

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

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.images,
  });

  ChatMessage copyWith({
    String? role,
    String? content,
    DateTime? timestamp,
    List<String>? images,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      images: images ?? this.images,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatMessage &&
        other.role == role &&
        other.content == content &&
        other.timestamp == timestamp &&
        listEquals(other.images, images);
  }

  @override
  int get hashCode {
    return Object.hash(
      role,
      content,
      timestamp,
      // Use Object.hashAll for lists to generate a consistent hash code based on content
      images != null ? Object.hashAll(images!) : null,
    );
  }
}
