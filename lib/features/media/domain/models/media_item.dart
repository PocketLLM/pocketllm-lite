import 'package:flutter/foundation.dart';

class MediaItem {
  final String id;
  final String chatId;
  final String chatTitle;
  final DateTime timestamp;
  final String base64Image;

  const MediaItem({
    required this.id,
    required this.chatId,
    required this.chatTitle,
    required this.timestamp,
    required this.base64Image,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem &&
        other.id == id &&
        other.chatId == chatId &&
        other.chatTitle == chatTitle &&
        other.timestamp == timestamp &&
        other.base64Image == base64Image;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      chatId,
      chatTitle,
      timestamp,
      base64Image,
    );
  }
}
