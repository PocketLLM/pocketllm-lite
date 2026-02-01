import 'package:flutter/foundation.dart';

class MediaItem {
  final String id;
  final String chatId;
  final String messageId; // Using message timestamp or content hash if no ID
  final String base64Content;
  final DateTime timestamp;

  const MediaItem({
    required this.id,
    required this.chatId,
    required this.messageId,
    required this.base64Content,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MediaItem &&
        other.id == id &&
        other.chatId == chatId &&
        other.messageId == messageId &&
        other.base64Content == base64Content &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      chatId,
      messageId,
      base64Content,
      timestamp,
    );
  }
}
