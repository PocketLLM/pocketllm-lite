import 'dart:ui';

class MediaItem {
  final String imageBase64;
  final DateTime timestamp;
  final String chatId;
  final String chatTitle; // Useful for display

  const MediaItem({
    required this.imageBase64,
    required this.timestamp,
    required this.chatId,
    required this.chatTitle,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MediaItem &&
      other.imageBase64 == imageBase64 &&
      other.timestamp == timestamp &&
      other.chatId == chatId &&
      other.chatTitle == chatTitle;
  }

  @override
  int get hashCode => Object.hash(imageBase64, timestamp, chatId, chatTitle);
}
