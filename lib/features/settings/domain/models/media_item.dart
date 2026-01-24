class MediaItem {
  final String chatId;
  final String chatTitle;
  final DateTime messageTimestamp;
  final int imageIndex;
  final String base64Content;

  const MediaItem({
    required this.chatId,
    required this.chatTitle,
    required this.messageTimestamp,
    required this.imageIndex,
    required this.base64Content,
  });
}
