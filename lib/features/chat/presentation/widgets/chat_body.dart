import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/connection_status_provider.dart';
import 'chat_bubble.dart';

class ChatBody extends ConsumerStatefulWidget {
  const ChatBody({super.key});

  @override
  ConsumerState<ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<ChatBody> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only watch what we need for the body
    final connectionStatusAsync = ref.watch(autoConnectionStatusProvider);
    final chatState = ref.watch(chatProvider);

    // Auto-scroll logic scoped to this widget
    ref.listen(chatProvider, (prev, next) {
      if (next.messages.length > (prev?.messages.length ?? 0) ||
          (next.isGenerating && next.messages.isNotEmpty)) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    return connectionStatusAsync.when(
      data: (isConnected) {
        if (!isConnected) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Not Connected',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please ensure Ollama is running and connected',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => context.push('/settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Configure Connection'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => context.push('/settings/docs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Docs'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return chatState.messages.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Start a conversation',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ensure Ollama is running in Termux',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                itemCount: chatState.messages.length +
                    (chatState.isGenerating &&
                            chatState.streamingContent.isNotEmpty
                        ? 1
                        : 0),
                itemBuilder: (context, index) {
                  if (index < chatState.messages.length) {
                    return ChatBubble(message: chatState.messages[index]);
                  } else {
                    return ChatBubble(
                      message: ChatMessage(
                        role: 'assistant',
                        content: chatState.streamingContent,
                        timestamp: DateTime.now(),
                      ),
                    );
                  }
                },
              );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}
