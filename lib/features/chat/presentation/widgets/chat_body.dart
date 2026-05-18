import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import '../../../../core/theme/app_motion.dart';
import '../../domain/models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/connection_status_provider.dart';
import '../providers/draft_message_provider.dart';
import 'chat_bubble.dart';
import 'package:pocketllm_lite/features/profile/presentation/providers/profile_provider.dart';

class ChatBody extends ConsumerStatefulWidget {
  const ChatBody({super.key});

  @override
  ConsumerState<ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<ChatBody> {
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
        duration: AppMotion.durationMD,
        curve: AppMotion.curveEnter,
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
    final connectionStatusAsync = ref.watch(autoConnectionStatusProvider);
    final messages = ref.watch(chatProvider.select((s) => s.messages));
    final isGenerating = ref.watch(chatProvider.select((s) => s.isGenerating));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Auto-scroll logic
    ref.listen(chatProvider.select((s) => s.messages.length), (prev, next) {
      if (next > (prev ?? 0)) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    // Throttled scroll for streaming content
    ref.listen(chatProvider.select((s) => s.streamingContent.length), (
      prev,
      next,
    ) {
      if (next > (prev ?? 0)) {
        _throttledScrollToBottom();
      }
    });

    return connectionStatusAsync.when(
      data: (isConnected) {
        if (!isConnected) {
          return _DisconnectedState();
        }

        if (messages.isEmpty) {
          return const _EmptyState();
        }

        return Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              itemCount: messages.length + (isGenerating ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < messages.length) {
                  return ChatBubble(
                    key: ValueKey(messages[index]),
                    message: messages[index],
                  );
                } else {
                  return const _StreamingChatBubble();
                }
              },
            ),
            // Scroll-to-bottom FAB
            Positioned(
              right: 16,
              bottom: 16,
              child: AnimatedSwitcher(
                duration: AppMotion.durationSM,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: AppMotion.curveOvershoot,
                  ),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: _showScrollToBottom
                    ? Semantics(
                        key: const ValueKey('scroll_fab'),
                        label: 'Scroll to bottom',
                        button: true,
                        child: FloatingActionButton.small(
                          onPressed: _scrollToBottom,
                          tooltip: 'Scroll to bottom',
                          backgroundColor: colorScheme.surfaceContainerHigh,
                          foregroundColor: colorScheme.primary,
                          elevation: 3,
                          child: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}

/// Disconnected state — M3 themed with M3 expressive shape
class _DisconnectedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              M3Container(
                Shapes.soft_burst,
                width: 100,
                height: 100,
                color: colorScheme.errorContainer.withValues(alpha: 0.5),
                child: Center(
                  child: Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Not Connected',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please ensure Ollama is running and connected',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_rounded),
                    label: const Text('Configure'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/settings/docs'),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Setup Guide'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state — M3 themed with Gemini-style personalized greeting and suggestions
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = ref.watch(profileProvider);
    final displayName = profile.name.trim();

    final greeting = displayName.isNotEmpty
        ? 'Hi $displayName, what\'s on your mind?'
        : 'Hi, what\'s on your mind?';

    final suggestions = [
      'What are the different types of shots in ice hockey?',
      'Create an image of a snowboarder in the Alps',
      'Tell me about the must see athletes from team usa',
    ];

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Beautiful Gemini-style Heading
              Semantics(
                header: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32.0),
                  child: Text(
                    greeting,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                      fontSize: 26,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              // Suggestions column
              ...suggestions.map((suggestion) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(draftMessageProvider.notifier).state =
                            suggestion;
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh.withValues(
                            alpha: 0.6,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                suggestion,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.85,
                                  ),
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.05,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamingChatBubble extends ConsumerStatefulWidget {
  const _StreamingChatBubble();

  @override
  ConsumerState<_StreamingChatBubble> createState() =>
      _StreamingChatBubbleState();
}

class _StreamingChatBubbleState extends ConsumerState<_StreamingChatBubble> {
  late final DateTime _timestamp;

  @override
  void initState() {
    super.initState();
    _timestamp = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(chatProvider.select((s) => s.streamingContent));
    final thinking = ref.watch(
      chatProvider.select((s) => s.streamingThinkingContent),
    );

    return ChatBubble(
      message: ChatMessage(
        role: 'assistant',
        content: content,
        timestamp: _timestamp,
        thinkingContent: thinking.isNotEmpty ? thinking : null,
      ),
    );
  }
}
