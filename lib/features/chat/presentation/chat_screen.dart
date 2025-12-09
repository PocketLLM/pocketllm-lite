import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/chat_provider.dart';
import 'providers/models_provider.dart';

import 'widgets/chat_bubble.dart';
import 'widgets/chat_input.dart';
import 'dialogs/chat_settings_dialog.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

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
    final chatState = ref.watch(chatProvider);
    final modelsAsync = ref.watch(modelsProvider);

    // Auto-scroll when messages change (especially when generating)
    ref.listen(chatProvider, (prev, next) {
      if (next.messages.length > (prev?.messages.length ?? 0) ||
          (next.isGenerating && next.messages.isNotEmpty)) {
        // Delay slightly to let layout build
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: modelsAsync.when(
          data: (models) {
            String? currentValue = chatState.selectedModel;
            // Check if current value is valid, if not, pick first
            if (models.isNotEmpty &&
                !models.any((m) => m.name == currentValue)) {
              currentValue = models.first.name;
              // defer update
              Future.microtask(
                () => ref.read(chatProvider.notifier).setModel(currentValue!),
              );
            }

            if (models.isEmpty) return const Text('No Models');

            return Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: currentValue,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                      style: Theme.of(context).textTheme.titleMedium,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      items: models
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.name,
                              child: Text(
                                m.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(chatProvider.notifier).setModel(val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Prompt Dropdown
              ],
            );
          },
          loading: () => const Text('Loading...'),
          error: (e, s) =>
              const Text('Ollama Disconnected', style: TextStyle(fontSize: 16)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New Chat',
            onPressed: () {
              ref.read(chatProvider.notifier).newChat();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Models',
            onPressed: () {
              ref.refresh(modelsProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Chat Settings',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const ChatSettingsDialog(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.messages.isEmpty
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
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: chatState.messages[index]);
                    },
                  ),
          ),
          const ChatInput(),
        ],
      ),
    );
  }
}
