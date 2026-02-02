import 'package:flutter/foundation.dart';

class MediaItem {
  final String id;
  final String chatId;
  final String chatTitle;
  final String base64Data;
  final DateTime timestamp;

  const MediaItem({
    required this.id,
    required this.chatId,
    required this.chatTitle,
    required this.base64Data,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem &&
        other.id == id &&
        other.chatId == chatId &&
        other.chatTitle == chatTitle &&
        other.timestamp == timestamp &&
        other.base64Data == base64Data;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      chatId,
      chatTitle,
      timestamp,
      base64Data,
    );
  }
}
