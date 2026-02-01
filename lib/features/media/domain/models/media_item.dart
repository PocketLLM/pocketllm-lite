class MediaItem {
  final String chatId;
  final String messageId;
  final String imagePath; // Base64 string
  final DateTime timestamp;
  final String chatTitle;

  const MediaItem({
    required this.chatId,
    required this.messageId,
    required this.imagePath,
    required this.timestamp,
    required this.chatTitle,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem &&
        other.chatId == chatId &&
        other.messageId == messageId &&
        other.imagePath == imagePath &&
        other.timestamp == timestamp &&
        other.chatTitle == chatTitle;
  }

  @override
  int get hashCode => Object.hash(
    chatId,
    messageId,
    imagePath,
    timestamp,
    chatTitle,
  );
}
