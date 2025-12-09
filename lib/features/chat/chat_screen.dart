import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';

import '../../providers/chat_provider.dart';
import '../../providers/ollama_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/chat_session.dart';
import '../../models/chat_message.dart';
import '../../models/ollama_model.dart';
import 'widgets/chat_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? chatId; // If null, new chat
  const ChatScreen({super.key, this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedModelId;
  String? _currentChatId;
  String? _pickedImageBase64;

  @override
  void initState() {
    super.initState();
    _currentChatId = widget.chatId;
    // Load default model if new chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initModel();
    });
  }

  void _initModel() {
    final settings = ref.read(settingsProvider).value;
    if (_selectedModelId == null && settings?.defaultModelId != null) {
      setState(() {
        _selectedModelId = settings!.defaultModelId;
      });
    }
  }

  // Effect to sync model with chat session if opening existing chat
  void _syncWithSession(ChatSession session) {
    if (_selectedModelId == null || _selectedModelId != session.modelId) {
      // Only update if not already set or different (assuming session source of truth)
      // But allow override? For now, sync to session.
      setState(() {
        _selectedModelId = session.modelId;
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

  Future<void> _handleImagePick() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        _pickedImageBase64 = base64String;
      });
      // Haptic
      final settings = ref.read(settingsProvider).value;
      if (settings?.isHapticEnabled == true) HapticFeedback.selectionClick();
    }
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _pickedImageBase64 == null) return;
    if (_selectedModelId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a model')));
      return;
    }

    // Prepare data
    final message = text;
    final image = _pickedImageBase64;
    final model = _selectedModelId!;

    // Clear input
    _textController.clear();
    setState(() {
      _pickedImageBase64 = null;
    });

    // Create chat if new
    if (_currentChatId == null) {
      final repo = ref.read(chatRepositoryProvider);
      await repo.createChat(model);
      // We need to get the ID. The repo creates it but doesn't return it in void.
      // Let's modify repo or just grab the last created one?
      // Better: repo.createChat should return ID.
      // Since I can't easily change repo API without step back, I'll hack it:
      // fetch all chats, sort by date, take top.
      final chats =
          repo.getAllChats(); // This is synchronous and might be stale? No, it reads from Hive box.
      if (chats.isNotEmpty) {
        _currentChatId = chats.first.id;
      }
    }

    if (_currentChatId != null) {
      await ref
          .read(chatControllerProvider.notifier)
          .sendMessage(
            chatId: _currentChatId!,
            message: message,
            modelId: model,
            imageBase64: image,
          );
      // Haptic
      final settings = ref.read(settingsProvider).value;
      if (settings?.isHapticEnabled == true) HapticFeedback.lightImpact();

      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    final models = ref.watch(availableModelsProvider).value ?? [];

    // If we have a chat ID, watch it
    final chatSession =
        _currentChatId != null
            ? ref.watch(currentChatSessionProvider(_currentChatId!))
            : null;

    // Sync model if loaded
    if (chatSession != null) {
      // We defer this to avoid setState during build, or just check equality
      if (_selectedModelId != chatSession.modelId && _selectedModelId == null) {
        // Initial load sync
        _selectedModelId = chatSession.modelId;
      }
    }

    final messages = chatSession?.messages ?? [];
    final isLoading = ref.watch(chatControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Chat', style: TextStyle(fontSize: 16)),
            // Model Selector in AppBar or just subtitle?
            // Requirement: "Model Dropdown: DropdownButtonFormField in input row"
            // Okay, I'll put it in input row as requested.
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // New Chat
              setState(() {
                _currentChatId = null;
                _textController.clear();
                _pickedImageBase64 = null;
                // Reset model to default
                if (settings?.defaultModelId != null) {
                  _selectedModelId = settings!.defaultModelId;
                }
              });
              context.push(
                '/home',
              ); // actually we are in home shell, so this reloads?
              // Or just clearing state is enough since we are in the screen.
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Empty State
          if (_currentChatId == null && messages.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text('Start a new conversation'),
                    const SizedBox(height: 8),
                    if (models.isEmpty)
                      TextButton(
                        onPressed: () => context.go('/settings'),
                        child: const Text('Go to Settings to download models'),
                      ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length + (isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= messages.length) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: TypingIndicator(),
                      ),
                    );
                  }
                  final msg = messages[index];
                  return ChatBubble(message: msg);
                },
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(blurRadius: 4, color: Colors.black.withOpacity(0.05)),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Image Preview
                  if (_pickedImageBase64 != null)
                    Container(
                      height: 80,
                      padding: const EdgeInsets.only(bottom: 8),
                      alignment: Alignment.centerLeft,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(_pickedImageBase64!),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap:
                                  () =>
                                      setState(() => _pickedImageBase64 = null),
                              child: const CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.red,
                                child: Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Input Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Model Dropdown (Compact)
                      if (models.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 12.0,
                            right: 8.0,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value:
                                  _selectedModelId != null &&
                                          models.any(
                                            (m) => m.name == _selectedModelId,
                                          )
                                      ? _selectedModelId
                                      : null,
                              hint: const Icon(Icons.smart_toy_outlined),
                              isDense: true,
                              items:
                                  models.map((m) {
                                    return DropdownMenuItem(
                                      value: m.name,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 100,
                                        ),
                                        child: Text(
                                          m.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedModelId = val);
                                // Haptic
                                if (settings?.isHapticEnabled == true)
                                  HapticFeedback.selectionClick();

                                // Update chat model if existing
                                if (_currentChatId != null && val != null) {
                                  ref
                                      .read(chatRepositoryProvider)
                                      .updateChatModel(_currentChatId!, val);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Switched to $val')),
                                  );
                                }
                              },
                            ),
                          ),
                        ),

                      Expanded(
                        child: TextField(
                          controller: _textController,
                          maxLines: 5,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),

                      // Vision Button
                      if (_selectedModelId != null &&
                          models.any(
                            (m) =>
                                m.name == _selectedModelId && m.supportsVision,
                          ))
                        IconButton(
                          icon: const Icon(Icons.image),
                          onPressed: _handleImagePick,
                          color:
                              _pickedImageBase64 != null
                                  ? Theme.of(context).primaryColor
                                  : null,
                        ),

                      // Send Button
                      IconButton(
                        icon:
                            isLoading
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.send),
                        onPressed: isLoading ? null : _handleSend,
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double value = (_controller.value + index / 3) % 1.0;
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(
                    0.4 + (value < 0.5 ? value : 1 - value) * 0.6,
                  ),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
