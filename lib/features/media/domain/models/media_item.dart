class MediaItem {
  final String chatId;
  final String chatTitle;
  final DateTime timestamp;
  final String base64;

  const MediaItem({
    required this.chatId,
    required this.chatTitle,
    required this.timestamp,
    required this.base64,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MediaItem &&
        other.chatId == chatId &&
        other.chatTitle == chatTitle &&
        other.timestamp == timestamp &&
        other.base64 == base64;
  }

  @override
  int get hashCode {
    return Object.hash(
      chatId,
      chatTitle,
      timestamp,
      base64,
    );
  }
}
