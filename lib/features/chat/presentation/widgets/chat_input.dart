import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';
import '../../../../services/ad_service.dart';
import '../../../../services/usage_limits_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/prompt_enhancer_provider.dart';
import '../providers/connection_status_provider.dart';
import '../providers/draft_message_provider.dart';
import '../providers/editing_message_provider.dart';
import '../../domain/models/text_file_attachment.dart';
import '../../domain/models/chat_message.dart';
import 'templates_sheet.dart';

class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({super.key});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  final List<Uint8List> _selectedImages = [];
  final List<TextFileAttachment> _selectedFiles = [];
  Timer? _debounceTimer;
  bool _limitHapticTriggered = false;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
      final sessionId = ref.read(chatProvider).currentSessionId;
      final draftKey = sessionId ?? 'new_chat';
      final storage = ref.read(storageServiceProvider);
      storage.saveDraft(draftKey, _controller.text);
    }
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadDraft() {
    final sessionId = ref.read(chatProvider).currentSessionId;
    final draftKey = sessionId ?? 'new_chat';
    final storage = ref.read(storageServiceProvider);
    final draft = storage.getDraft(draftKey);
    if (draft != null && draft.isNotEmpty) {
      _controller.text = draft;
    }
  }

  void _onTextChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final sessionId = ref.read(chatProvider).currentSessionId;
      final draftKey = sessionId ?? 'new_chat';
      final storage = ref.read(storageServiceProvider);
      storage.saveDraft(draftKey, _controller.text);
    });

    final hasReachedLimit =
        _controller.text.length >= AppConstants.maxInputLength;
    if (hasReachedLimit && !_limitHapticTriggered) {
      HapticFeedback.heavyImpact();
      _limitHapticTriggered = true;
    } else if (!hasReachedLimit) {
      _limitHapticTriggered = false;
    }
  }

  Future<void> _pickImage() async {
    final storage = ref.read(storageServiceProvider);
    if (storage.getSetting(
      AppConstants.hapticFeedbackKey,
      defaultValue: false,
    )) {
      HapticFeedback.selectionClick();
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Attach Image',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Icons.camera_alt_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (source != null) {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImages.add(bytes);
        });
      }
    }
  }

  Future<void> _pickFile() async {
    final storage = ref.read(storageServiceProvider);
    if (storage.getSetting(
      AppConstants.hapticFeedbackKey,
      defaultValue: false,
    )) {
      HapticFeedback.selectionClick();
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'md', 'json', 'csv', 'log'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final maxBytes = AppConstants.maxTextFileAttachmentBytes;
    if (file.bytes!.lengthInBytes > maxBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('File too large. Limit to 200KB.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    final content = String.fromCharCodes(file.bytes!);
    setState(() {
      _selectedFiles.add(
        TextFileAttachment(
          name: file.name,
          content: content,
          sizeBytes: file.bytes!.lengthInBytes,
          mimeType: file.extension != null
              ? 'text/${file.extension}'
              : 'text/plain',
        ),
      );
    });
  }

  void _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _selectedFiles.isEmpty) {
      return;
    }

    if (text.length > AppConstants.maxInputLength) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Message too long. Please limit to ${AppConstants.maxInputLength} characters.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    final connectionChecker = ref.read(autoConnectionStatusProvider.notifier);
    await connectionChecker.refresh();
    final connectionState = await ref.read(autoConnectionStatusProvider.future);
    final isConnected = connectionState;

    if (!isConnected) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(
              Icons.cloud_off_rounded,
              color: Theme.of(dialogContext).colorScheme.error,
            ),
            title: const Text('Ollama Not Connected'),
            content: const Text(
              'Please ensure Ollama is running and connected. '
              'Check your setup and try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.tonal(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  if (mounted) context.push('/settings');
                },
                child: const Text('Settings'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  if (mounted) context.push('/settings/docs');
                },
                child: const Text('Setup Guide'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final storage = ref.read(storageServiceProvider);
    if (storage.getSetting(
      AppConstants.hapticFeedbackKey,
      defaultValue: false,
    )) {
      HapticFeedback.lightImpact();
    }

    final imagesToSend = _selectedImages
        .map((bytes) => base64Encode(bytes))
        .toList();

    final sessionId = ref.read(chatProvider).currentSessionId;
    final draftKey = sessionId ?? 'new_chat';
    await storage.deleteDraft(draftKey);

    final editingMessage = ref.read(editingMessageProvider);

    if (editingMessage != null) {
      await ref
          .read(chatProvider.notifier)
          .editMessage(
            editingMessage,
            _controller.text,
            attachments: _selectedFiles.isNotEmpty ? _selectedFiles : null,
          );
      ref.read(editingMessageProvider.notifier).clearEditingMessage();
    } else {
      ref
          .read(chatProvider.notifier)
          .sendMessage(
            _controller.text,
            images: imagesToSend.isNotEmpty ? imagesToSend : null,
            attachments: _selectedFiles.isNotEmpty ? _selectedFiles : null,
          );
    }

    _controller.clear();
    setState(() {
      _selectedImages.clear();
      _selectedFiles.clear();
    });
  }

  bool _isEnhancing = false;

  void _showTemplates() {
    final storage = ref.read(storageServiceProvider);
    if (storage.getSetting(
      AppConstants.hapticFeedbackKey,
      defaultValue: false,
    )) {
      HapticFeedback.selectionClick();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TemplatesSheet(
          onSelect: (content) {
            Navigator.pop(context);
            if (content.isNotEmpty) {
              setState(() {
                if (_controller.text.isEmpty) {
                  _controller.text = content;
                } else {
                  _controller.text = '${_controller.text}\n$content';
                }
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
              });
              _focusNode.requestFocus();
            }
          },
        ),
      ),
    );
  }

  Future<void> _enhancePrompt() async {
    if (_controller.text.trim().isEmpty) return;

    final connectionChecker = ref.read(autoConnectionStatusProvider.notifier);
    await connectionChecker.refresh();
    final connectionState = await ref.read(autoConnectionStatusProvider.future);
    final isConnected = connectionState;

    if (!isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cannot enhance prompt: Ollama not connected'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Theme.of(context).colorScheme.onError,
              onPressed: () => context.push('/settings'),
            ),
          ),
        );
      }
      return;
    }

    final enhancerState = ref.read(promptEnhancerProvider);
    if (enhancerState.selectedModelId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Select a Prompt Enhancer model in Settings first.',
          ),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ),
      );
      return;
    }

    final limitsNotifier = ref.read(usageLimitsProvider.notifier);
    if (!limitsNotifier.canUseEnhancer()) {
      await _showEnhancerLimitDialog();
      return;
    }

    final storage = ref.read(storageServiceProvider);
    if (storage.getSetting(
      AppConstants.hapticFeedbackKey,
      defaultValue: true,
    )) {
      HapticFeedback.lightImpact();
    }

    setState(() => _isEnhancing = true);

    try {
      final enhanced = await ref
          .read(promptEnhancerProvider.notifier)
          .enhancePrompt(_controller.text);

      if (mounted) {
        await limitsNotifier.useEnhancer();

        if (!mounted) return;

        setState(() {
          _controller.text = enhanced;
          _isEnhancing = false;
        });

        if (storage.getSetting(
          AppConstants.hapticFeedbackKey,
          defaultValue: true,
        )) {
          HapticFeedback.mediumImpact();
        }

        final remaining = ref.read(usageLimitsProvider).enhancerRemaining;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prompt enhanced! ($remaining uses left today)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEnhancing = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Enhancement failed—check Ollama.'),
            duration: const Duration(seconds: 3),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Theme.of(context).colorScheme.onError,
              onPressed: () => context.push('/settings'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showEnhancerLimitDialog() async {
    final limits = ref.read(usageLimitsProvider);
    final adService = AdService();
    final theme = Theme.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.auto_awesome_rounded,
          color: theme.colorScheme.primary,
        ),
        title: const Text('Enhancement Limit Reached'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "You've used your ${AppConstants.freeEnhancementsPerDay} free enhancements today.",
            ),
            const SizedBox(height: 8),
            Text(
              'Resets in ~${limits.hoursUntilEnhancerReset} hours.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Watch a short ad to unlock 5 more enhancements?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (!await adService.hasInternetConnection()) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Connect to WiFi/Data to watch ad and unlock.',
                      ),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
                return;
              }
              if (context.mounted) Navigator.pop(context, true);
            },
            icon: const Icon(Icons.play_circle_rounded),
            label: const Text('Watch Ad'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await adService.showPromptEnhancementRewardedAd(
        onUserEarnedReward: (reward) async {
          await ref
              .read(usageLimitsProvider.notifier)
              .addEnhancerUses(AppConstants.enhancementsPerAdWatch);
          if (mounted) {
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unlocked 5 more enhancements!')),
            );
          }
        },
        onFailed: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ad failed: $error'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for draft messages (e.g. from suggestion chips)
    ref.listen<String?>(draftMessageProvider, (previous, next) {
      if (next != null && next.isNotEmpty) {
        _controller.text = next;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: next.length),
        );
        _focusNode.requestFocus();
        ref.read(draftMessageProvider.notifier).update((state) => null);
      }
    });

    ref.listen<ChatMessage?>(editingMessageProvider, (previous, next) {
      if (next != null) {
        _controller.text = next.content;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: next.content.length),
        );
        setState(() {
          _selectedFiles
            ..clear()
            ..addAll(next.attachments ?? []);
        });
        _focusNode.requestFocus();
      }
    });

    // Listen for session changes to save/load drafts
    ref.listen<ChatState>(chatProvider, (prev, next) {
      if (prev?.currentSessionId != next.currentSessionId) {
        final storage = ref.read(storageServiceProvider);
        final prevKey = prev?.currentSessionId ?? 'new_chat';
        storage.saveDraft(prevKey, _controller.text);
        final nextKey = next.currentSessionId ?? 'new_chat';
        final newDraft = storage.getDraft(nextKey);
        _controller.text = newDraft ?? '';
      }
    });

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isGenerating = ref.watch(chatProvider.select((s) => s.isGenerating));
    final editingMessage = ref.watch(editingMessageProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Editing banner — above the input capsule
            if (editingMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Editing message',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          onPressed: () {
                            ref
                                .read(editingMessageProvider.notifier)
                                .clearEditingMessage();
                            _controller.clear();
                            setState(() {
                              _selectedFiles.clear();
                            });
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: colorScheme.onPrimaryContainer,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Attachment previews row — above input capsule
            if (_selectedImages.isNotEmpty || _selectedFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                child: SizedBox(
                  height: _selectedImages.isNotEmpty ? 64 : 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Image previews
                      ..._selectedImages.asMap().entries.map((entry) {
                        final i = entry.key;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  entry.value,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  cacheWidth: 168,
                                ),
                              ),
                              Positioned(
                                right: -4,
                                top: -4,
                                child: GestureDetector(
                                  onTap: () => setState(
                                    () => _selectedImages.removeAt(i),
                                  ),
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: colorScheme.error,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colorScheme.surface,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: colorScheme.onError,
                                      size: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      // File chips
                      ..._selectedFiles.asMap().entries.map((entry) {
                        final i = entry.key;
                        final attachment = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Semantics(
                            label: 'Attached file ${attachment.name}',
                            child: InputChip(
                              avatar: Icon(
                                Icons.description_outlined,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              label: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 100,
                                ),
                                child: Text(
                                  attachment.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                              onDeleted: () {
                                setState(() => _selectedFiles.removeAt(i));
                              },
                              deleteIconColor: colorScheme.onSurfaceVariant,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            // Main input capsule
            AnimatedBuilder(
              animation: _focusNode,
              builder: (context, child) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? colorScheme.primary.withValues(alpha: 0.3)
                          : colorScheme.outlineVariant.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 2, 4, 4),
                  child: child,
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Enhancing gradient (visual feedback)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: _isEnhancing
                          ? LinearGradient(
                              colors: [
                                colorScheme.primary.withValues(alpha: 0.06),
                                colorScheme.tertiary.withValues(alpha: 0.06),
                                colorScheme.secondary.withValues(alpha: 0.06),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                    ),
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(
                          LogicalKeyboardKey.enter,
                          control: true,
                        ): _send,
                        const SingleActivator(
                          LogicalKeyboardKey.enter,
                          meta: true,
                        ): _send,
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          enabled: !isGenerating && !_isEnhancing,
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          maxLines: 6,
                          minLines: 1,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5, // Better line height for readability
                            fontSize: 16, // Readable font size
                          ),
                          maxLength: AppConstants.maxInputLength,
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                required maxLength,
                              }) => null,
                          decoration: InputDecoration(
                            hintText: _isEnhancing
                                ? 'Enhancing your prompt...'
                                : 'Message Pocket LLM...',
                            hintStyle: TextStyle(
                              color: _isEnhancing
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant.withValues(
                                      alpha: 0.5,
                                    ),
                              fontStyle: _isEnhancing ? FontStyle.italic : null,
                            ),
                            border: InputBorder.none,
                            isDense: false, // Allow default comfortable height
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14, // Ensures ~48px+ height
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Bottom toolbar — inside capsule
                  Padding(
                    padding: const EdgeInsets.only(left: 2, right: 2),
                    child: Row(
                      children: [
                        // Left action buttons
                        _InputActionButton(
                          icon: Icons.add_photo_alternate_outlined,
                          tooltip: 'Add Image',
                          onTap: _pickImage,
                          isDisabled: isGenerating,
                          colorScheme: colorScheme,
                        ),
                        const SizedBox(width: 2),
                        _InputActionButton(
                          icon: Icons.attach_file_rounded,
                          tooltip: 'Attach File',
                          onTap: _pickFile,
                          isDisabled: isGenerating,
                          colorScheme: colorScheme,
                        ),
                        const SizedBox(width: 2),
                        _InputActionButton(
                          icon: Icons.bolt_rounded,
                          tooltip: 'Templates',
                          onTap: _showTemplates,
                          isDisabled: isGenerating,
                          colorScheme: colorScheme,
                        ),
                        // Enhance Prompt — conditional
                        Consumer(
                          builder: (context, ref, child) {
                            final enhancerState = ref.watch(
                              promptEnhancerProvider,
                            );
                            final hasEnhancer =
                                enhancerState.selectedModelId != null;

                            if (!hasEnhancer) return const SizedBox.shrink();

                            final isDisabled = isGenerating || _isEnhancing;
                            return Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: _InputActionButton(
                                icon: Icons.auto_awesome_rounded,
                                tooltip: 'Enhance Prompt',
                                onTap: _enhancePrompt,
                                isDisabled: isDisabled,
                                colorScheme: colorScheme,
                                isLoading: _isEnhancing,
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                        // Character counter
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, child) {
                            final charCount = value.text.length;
                            final maxLength = AppConstants.maxInputLength;
                            final remaining = maxLength - charCount;
                            // Only show counter when typing
                            if (charCount == 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ExcludeSemantics(
                                child: Text(
                                  '$charCount/$maxLength',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: remaining <= 200
                                        ? colorScheme.error
                                        : colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        // Send button
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, child) {
                            final canSend =
                                (value.text.trim().isNotEmpty ||
                                    _selectedImages.isNotEmpty ||
                                    _selectedFiles.isNotEmpty) &&
                                !isGenerating;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: canSend
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: canSend ? _send : null,
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, animation) =>
                                      ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                  child: isGenerating
                                      ? SizedBox(
                                          key: const ValueKey('spinner'),
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.arrow_upward_rounded,
                                          key: const ValueKey('send_icon'),
                                          color: canSend
                                              ? colorScheme.onPrimary
                                              : colorScheme.onSurfaceVariant
                                                    .withValues(alpha: 0.4),
                                          size: 18,
                                        ),
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                tooltip: isGenerating
                                    ? 'Generating...'
                                    : 'Send (Ctrl/⌘ + Enter)',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable M3 action button for the input toolbar
class _InputActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDisabled;
  final ColorScheme colorScheme;
  final bool isLoading;

  const _InputActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isDisabled,
    required this.colorScheme,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      enabled: !isDisabled,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isDisabled ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Icon(
                        icon,
                        size: 20,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: isDisabled ? 0.35 : 0.8,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
