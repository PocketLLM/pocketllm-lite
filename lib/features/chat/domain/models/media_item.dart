class MediaItem {
  final String id;
  final String chatId;
  final String base64Content;
  final DateTime timestamp;
  final String role;

  const MediaItem({
    required this.id,
    required this.chatId,
    required this.base64Content,
    required this.timestamp,
    required this.role,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
