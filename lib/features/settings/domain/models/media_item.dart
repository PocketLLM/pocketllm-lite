class MediaItem {
  final String id;
  final String base64Content;
  final String chatId;
  final String chatTitle;
  final DateTime timestamp;

  const MediaItem({
    required this.id,
    required this.base64Content,
    required this.chatId,
    required this.chatTitle,
    required this.timestamp,
  });
}
