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
}
