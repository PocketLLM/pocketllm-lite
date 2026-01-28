import 'package:flutter/foundation.dart';

@immutable
class MediaItem {
  final String id;
  final String base64Content;
  final String chatId;
  final String chatTitle;
  final DateTime timestamp;

  const MediaItem({
    required this.id,
    required this.base64Content,
    required this.chatId,
    required this.chatTitle,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MediaItem &&
        other.id == id &&
        other.base64Content == base64Content &&
        other.chatId == chatId &&
        other.chatTitle == chatTitle &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(id, base64Content, chatId, chatTitle, timestamp);
  }
}
