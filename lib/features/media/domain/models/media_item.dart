import 'package:flutter/foundation.dart';

class MediaItem {
  final String id;
  final String base64;
  final String chatId;
  final DateTime timestamp;

  const MediaItem({
    required this.id,
    required this.base64,
    required this.chatId,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem &&
        other.id == id &&
        other.base64 == base64 &&
        other.chatId == chatId &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(id, base64, chatId, timestamp);
}
