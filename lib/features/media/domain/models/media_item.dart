import 'package:flutter/foundation.dart';

@immutable
class MediaItem {
  final String base64Content;
  final String chatId;
  final DateTime timestamp;

  const MediaItem({
    required this.base64Content,
    required this.chatId,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem &&
        other.base64Content == base64Content &&
        other.chatId == chatId &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(base64Content, chatId, timestamp);
}
