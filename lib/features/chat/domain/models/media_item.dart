class MediaItem {
  final String chatId;
  final int messageIndex;
  final int imageIndex;
  final String base64Content;
  final DateTime timestamp;

  MediaItem({
    required this.chatId,
    required this.messageIndex,
    required this.imageIndex,
    required this.base64Content,
    required this.timestamp,
  });
}
