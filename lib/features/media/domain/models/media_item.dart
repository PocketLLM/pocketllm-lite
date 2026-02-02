import 'package:flutter/foundation.dart';

class MediaItem {
  final String id;
  final String chatId;
  final String base64Image;
  final DateTime timestamp;

  const MediaItem({
    required this.id,
    required this.chatId,
    required this.base64Image,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MediaItem &&
        other.id == id &&
        other.chatId == chatId &&
        other.base64Image == base64Image &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(id, chatId, base64Image, timestamp);
  }
}
