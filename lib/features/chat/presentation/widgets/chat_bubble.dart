import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/chat_message.dart';
import '../../../settings/presentation/providers/appearance_provider.dart';

class ChatBubble extends ConsumerWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == 'user';
    final theme = Theme.of(context);
    final appearance = ref.watch(appearanceProvider);
    final bubbleColor = isUser
        ? Color(appearance.userMsgColor)
        : Color(appearance.aiMsgColor);
    final radius = appearance.bubbleRadius;
    final fontSize = appearance.fontSize;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.transparent,
              child: Icon(
                Icons.auto_awesome,
                color: Colors.purpleAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 0,
            child: GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showMessageMenu(context, message);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(radius).copyWith(
                    bottomRight: isUser ? const Radius.circular(0) : null,
                    bottomLeft: !isUser ? const Radius.circular(0) : null,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.images != null && message.images!.isNotEmpty)
                      ...message.images!.map(
                        (str) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(str),
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    if (isUser)
                      Text(
                        message.content,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isUser
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                          fontSize: fontSize,
                        ),
                      )
                    else
                      MarkdownBody(
                        data: message.content,
                        styleSheet: MarkdownStyleSheet.fromTheme(theme)
                            .copyWith(
                              p: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontSize: fontSize,
                              ),
                              code: theme.textTheme.bodyMedium?.copyWith(
                                backgroundColor: Colors.black26,
                                fontSize: fontSize * 0.9,
                              ),
                            ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 20)),
          ],
        ],
      ),
    );
  }

  void _showMessageMenu(BuildContext context, ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMenuAction(context, Icons.copy, 'Copy', () {
              Clipboard.setData(ClipboardData(text: message.content));
              Navigator.pop(context);
            }),
            _buildMenuAction(context, Icons.share, 'Share', () {
              Navigator.pop(context);
            }),
            if (message.role == 'user')
              _buildMenuAction(context, Icons.edit, 'Edit', () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Branching/Edit coming in next update'),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuAction(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).highlightColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
