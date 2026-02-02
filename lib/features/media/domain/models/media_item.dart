import 'package:flutter/foundation.dart';

class MediaItem {
  final String base64Content;
  final String chatId;
  final DateTime timestamp;
  final String role;

  const MediaItem({
    required this.base64Content,
    required this.chatId,
    required this.timestamp,
    required this.role,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MediaItem &&
        other.base64Content == base64Content &&
        other.chatId == chatId &&
        other.timestamp == timestamp &&
        other.role == role;
  }

  @override
  int get hashCode {
    return Object.hash(
      base64Content,
      chatId,
      timestamp,
      role,
    );
  }
}
