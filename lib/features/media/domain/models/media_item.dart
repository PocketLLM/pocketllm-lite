import 'package:flutter/foundation.dart';

@immutable
class MediaItem {
  final String id;
  final String base64;
  final DateTime timestamp;
  final String chatId;

  const MediaItem({
    required this.id,
    required this.base64,
    required this.timestamp,
    required this.chatId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem &&
        other.id == id &&
        other.base64 == base64 &&
        other.timestamp == timestamp &&
        other.chatId == chatId;
  }

  @override
  int get hashCode {
    return Object.hash(id, base64, timestamp, chatId);
  }
}
