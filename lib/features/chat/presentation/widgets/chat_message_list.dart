import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/chat_message.dart';
import '../providers/chat_provider.dart';
import 'chat_bubble.dart';

class ChatMessageList extends ConsumerStatefulWidget {
  const ChatMessageList({super.key});

  @override
  ConsumerState<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends ConsumerState<ChatMessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  DateTime? _lastAutoScroll;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    // Show button if we are more than 300 pixels away from the bottom
    final show = (maxScroll - currentScroll) > 300;

    if (show != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = show;
      });
    }
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

  void _throttledScrollToBottom() {
    final now = DateTime.now();
    if (_lastAutoScroll == null ||
        now.difference(_lastAutoScroll!) > const Duration(milliseconds: 100)) {
      _scrollToBottom();
      _lastAutoScroll = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider.select((s) => s.messages));
    final isGenerating = ref.watch(chatProvider.select((s) => s.isGenerating));
    final hasStreamingContent =
        ref.watch(chatProvider.select((s) => s.streamingContent.isNotEmpty));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Auto-scroll logic scoped to this widget
    ref.listen(chatProvider.select((s) => s.messages.length), (prev, next) {
      if (next > (prev ?? 0)) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    // Throttled scroll for streaming content
    ref.listen(chatProvider.select((s) => s.streamingContent.length),
        (prev, next) {
      if (next > (prev ?? 0)) {
        _throttledScrollToBottom();
      }
    });

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          itemCount: messages.length +
              (isGenerating && hasStreamingContent ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < messages.length) {
              return ChatBubble(message: messages[index]);
            } else {
              return const _StreamingChatBubble();
            }
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: AnimatedOpacity(
            opacity: _showScrollToBottom ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_showScrollToBottom,
              child: Semantics(
                label: 'Scroll to bottom',
                button: true,
                child: FloatingActionButton.small(
                  onPressed: _scrollToBottom,
                  backgroundColor: isDark
                    ? Colors.grey[800]
                    : Colors.white,
                  foregroundColor: theme.colorScheme.primary,
                  elevation: 4,
                  child: const Icon(Icons.arrow_downward),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StreamingChatBubble extends ConsumerWidget {
  const _StreamingChatBubble();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(chatProvider.select((s) => s.streamingContent));

    return ChatBubble(
      message: ChatMessage(
        role: 'assistant',
        content: content,
        timestamp: DateTime.now(),
      ),
    );
  }
}
