import 'package:flutter/foundation.dart';

@immutable
class MediaItem {
  final String id;
  final String chatId;
  final String base64Content;
  final DateTime timestamp;

  const MediaItem({
    required this.id,
    required this.chatId,
    required this.base64Content,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MediaItem &&
        other.id == id &&
        other.chatId == chatId &&
        other.base64Content == base64Content &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(id, chatId, base64Content, timestamp);
  }
}
