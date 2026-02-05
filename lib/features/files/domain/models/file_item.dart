import '../../../chat/domain/models/chat_message.dart';
import '../../../chat/domain/models/text_file_attachment.dart';

class FileItem {
  final TextFileAttachment attachment;
  final String chatId;
  final String chatTitle;
  final ChatMessage message;

  const FileItem({
    required this.attachment,
    required this.chatId,
    required this.chatTitle,
    required this.message,
  });
}
