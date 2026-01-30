import 'package:flutter/foundation.dart';

@immutable
class MediaItem {
  final String id;
  final String base64Image;
  final String chatId;
  final String chatTitle;
  final String messageId;
  final DateTime timestamp;

  const MediaItem({
    required this.id,
    required this.base64Image,
    required this.chatId,
    required this.chatTitle,
    required this.messageId,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
