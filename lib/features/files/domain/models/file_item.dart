import '../../../chat/domain/models/chat_message.dart';
import '../../../chat/domain/models/text_file_attachment.dart';

class FileItem {
  final String chatId;
  final String chatTitle;
  final DateTime timestamp;
  final ChatMessage message;
  final TextFileAttachment attachment;

  const FileItem({
    required this.chatId,
    required this.chatTitle,
    required this.timestamp,
    required this.message,
    required this.attachment,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileItem &&
        other.chatId == chatId &&
        other.message == message &&
        other.attachment == attachment;
  }

  @override
  int get hashCode => Object.hash(chatId, message, attachment);
}
