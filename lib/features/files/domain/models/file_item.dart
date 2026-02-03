import '../../../chat/domain/models/text_file_attachment.dart';

class FileItem {
  final String chatId;
  final String chatTitle;
  final DateTime timestamp;
  final TextFileAttachment attachment;

  const FileItem({
    required this.chatId,
    required this.chatTitle,
    required this.timestamp,
    required this.attachment,
  });
}
