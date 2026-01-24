import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
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
  final List<PlatformFile> _selectedFiles = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // Save any pending draft before disposing
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
      final sessionId = ref.read(chatProvider).currentSessionId;
      final draftKey = sessionId ?? 'new_chat';
      final storage = ref.read(storageServiceProvider);
      // We can't await here, but storage is synchronous (Hive memory) or fire-and-forget
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
  }

  Future<void> _pickImage() async {
    // Show bottom sheet to choose camera or gallery
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
              // Drag handle
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
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
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
        maxHeight: 1024, // Security: Prevent DoS via memory exhaustion
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

    try {
      final fileService = ref.read(fileServiceProvider);
      // We restrict to common text-based formats for now
      final files = await fileService.pickFiles(
        allowedExtensions: [
          'txt', 'md', 'json', 'yaml', 'yml', 'dart', 'py', 'js', 'ts',
          'html', 'css', 'csv', 'c', 'cpp', 'h', 'java', 'kt', 'swift', 'rb', 'go', 'rs'
        ],
      );

      if (files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty && _selectedImages.isEmpty && _selectedFiles.isEmpty) return;

    if (text.length > AppConstants.maxInputLength) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Message too long. Please limit to ${AppConstants.maxInputLength} characters.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check connection status before sending using the auto-refreshing provider
    final connectionChecker = ref.read(autoConnectionStatusProvider.notifier);
    await connectionChecker.refresh(); // Force a refresh before checking
    final connectionState = await ref.read(autoConnectionStatusProvider.future);
    final isConnected = connectionState;

    if (!isConnected) {
      // Show dialog prompting user to connect Ollama with improved button design
      if (mounted) {
        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
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
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  // Navigate to settings using State context
                  if (mounted) context.push('/settings');
                },
                child: const Text('Settings'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  // Navigate to docs using State context
                  if (mounted) context.push('/settings/docs');
                },
                child: const Text('Docs'),
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

    // Process files if any
    final messageBuffer = StringBuffer();
    if (text.isNotEmpty) {
      messageBuffer.write(text);
    }

    if (_selectedFiles.isNotEmpty) {
       final fileService = ref.read(fileServiceProvider);
       if (messageBuffer.isNotEmpty) messageBuffer.writeln('\n');
       messageBuffer.writeln('--- Attached Files ---');

       for (final file in _selectedFiles) {
         try {
           final content = await fileService.readFileContent(file);
           messageBuffer.writeln('\nFile: ${file.name}');
           messageBuffer.writeln('```');
           messageBuffer.writeln(content);
           messageBuffer.writeln('```');
         } catch (e) {
           messageBuffer.writeln('\nError reading file ${file.name}: $e');
         }
       }
       messageBuffer.writeln('\n---');
    }

    final imagesToSend = _selectedImages
        .map((bytes) => base64Encode(bytes))
        .toList();

    // Clear draft before sending
    final sessionId = ref.read(chatProvider).currentSessionId;
    final draftKey = sessionId ?? 'new_chat';
    await storage.deleteDraft(draftKey);

    ref
        .read(chatProvider.notifier)
        .sendMessage(
          messageBuffer.toString(),
          images: imagesToSend.isNotEmpty ? imagesToSend : null,
        );

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
                // If controller is empty, just replace. If not, append.
                if (_controller.text.isEmpty) {
                  _controller.text = content;
                } else {
                  _controller.text = '${_controller.text}\n$content';
                }
                // Move cursor to end
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

    // Check connection status before enhancing using the auto-refreshing provider
    final connectionChecker = ref.read(autoConnectionStatusProvider.notifier);
    await connectionChecker.refresh(); // Force a refresh before checking
    final connectionState = await ref.read(autoConnectionStatusProvider.future);
    final isConnected = connectionState;

    if (!isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cannot enhance prompt: Ollama not connected'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
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

    // Check usage limits
    final limitsNotifier = ref.read(usageLimitsProvider.notifier);
    if (!limitsNotifier.canUseEnhancer()) {
      // Show ad dialog
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
        // Consume one enhancer use
        await limitsNotifier.useEnhancer();

        if (!mounted) return;

        setState(() {
          _controller.text = enhanced;
          _isEnhancing = false;
        });

        // Haptic success feedback
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
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
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

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
          ElevatedButton.icon(
            onPressed: () async {
              // Check internet first
              if (!await adService.hasInternetConnection()) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Connect to WiFi/Data to watch ad and unlock.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
                return;
              }
              if (context.mounted) Navigator.pop(context, true);
            },
            icon: const Icon(Icons.play_circle),
            label: const Text('Watch Ad'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, // Blue background
              foregroundColor: Colors.white, // White text
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      // Show and handle rewarded ad
      await adService.showPromptEnhancementRewardedAd(
        onUserEarnedReward: (reward) async {
          await ref
              .read(usageLimitsProvider.notifier)
              .addEnhancerUses(AppConstants.enhancementsPerAdWatch);
          if (mounted) {
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unlocked 5 more enhancements!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        onFailed: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ad failed: $error'),
                backgroundColor: Colors.red,
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
        // Reset the provider to avoid re-triggering or stale state
        ref.read(draftMessageProvider.notifier).state = null;
      }
    });

    // Listen for session changes to save/load drafts
    ref.listen<ChatState>(chatProvider, (prev, next) {
      if (prev?.currentSessionId != next.currentSessionId) {
        final storage = ref.read(storageServiceProvider);

        // Save previous draft
        final prevKey = prev?.currentSessionId ?? 'new_chat';
        storage.saveDraft(prevKey, _controller.text);

        // Load new draft
        final nextKey = next.currentSessionId ?? 'new_chat';
        final newDraft = storage.getDraft(nextKey);

        _controller.text = newDraft ?? '';
      }
    });

    final theme = Theme.of(context);
    final isGenerating = ref.watch(chatProvider.select((s) => s.isGenerating));
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Background of the bar area
      ),
      child: AnimatedBuilder(
        animation: _focusNode,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _focusNode.hasFocus
                    ? theme.colorScheme.primary
                    : (isDark ? Colors.grey[800]! : Colors.transparent),
                width: 1.0, // Constant width to prevent layout shift
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedImages.isNotEmpty || _selectedFiles.isNotEmpty)
              Container(
                height: 70,
                padding: const EdgeInsets.only(bottom: 8, top: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._selectedImages.asMap().entries.map((entry) {
                      final i = entry.key;
                      final bytes = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                bytes,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                cacheWidth: 180,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton(
                                alignment: Alignment.topRight,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                tooltip: 'Remove image',
                                onPressed: () =>
                                    setState(() => _selectedImages.removeAt(i)),
                                icon: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    ..._selectedFiles.asMap().entries.map((entry) {
                      final i = entry.key;
                      final file = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InputChip(
                          label: Text(
                            file.name,
                            style: const TextStyle(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onDeleted: () => setState(() => _selectedFiles.removeAt(i)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          avatar: const Icon(Icons.insert_drive_file, size: 14),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: _isEnhancing
                    ? LinearGradient(
                        colors: [
                          Colors.blue.withValues(alpha: 0.1),
                          Colors.purple.withValues(alpha: 0.1),
                          Colors.pink.withValues(alpha: 0.1),
                          Colors.blue.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                boxShadow: _isEnhancing
                    ? [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
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
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !isGenerating && !_isEnhancing,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  maxLines: 8,
                  minLines: 1,
                  style: theme.textTheme.bodyLarge,
                  maxLength: AppConstants.maxInputLength,
                  buildCounter: (
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
                          ? Colors.blue
                          : theme.hintColor.withValues(alpha: 0.7),
                      fontStyle: _isEnhancing ? FontStyle.italic : null,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      label: 'Add Image',
                      button: true,
                      enabled: !isGenerating,
                      child: Tooltip(
                        message: 'Add Image',
                        child: Material(
                          color: (isDark ? Colors.grey[800] : Colors.grey[300])
                              ?.withValues(alpha: isGenerating ? 0.5 : 1.0),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: isGenerating ? null : _pickImage,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.add_photo_alternate,
                                size: 20,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: isGenerating ? 0.5 : 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // File Attachment
                    Semantics(
                      label: 'Attach File',
                      button: true,
                      enabled: !isGenerating,
                      child: Tooltip(
                        message: 'Attach File',
                        child: Material(
                          color: (isDark ? Colors.grey[800] : Colors.grey[300])
                              ?.withValues(alpha: isGenerating ? 0.5 : 1.0),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: isGenerating ? null : _pickFile,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.attach_file,
                                size: 20,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: isGenerating ? 0.5 : 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Templates Button
                    Semantics(
                      label: 'Templates',
                      button: true,
                      enabled: !isGenerating,
                      child: Tooltip(
                        message: 'Quick Templates',
                        child: Material(
                          color: (isDark ? Colors.grey[800] : Colors.grey[300])
                              ?.withValues(alpha: isGenerating ? 0.5 : 1.0),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: isGenerating ? null : _showTemplates,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.bolt,
                                size: 20,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: isGenerating ? 0.5 : 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Enhance Prompt Button
                    Consumer(
                      builder: (context, ref, child) {
                        final enhancerState = ref.watch(promptEnhancerProvider);
                        final hasEnhancer =
                            enhancerState.selectedModelId != null;

                        if (!hasEnhancer) return const SizedBox.shrink();

                        final isDisabled = isGenerating || _isEnhancing;
                        return Semantics(
                          label: 'Enhance Prompt',
                          button: true,
                          enabled: !isDisabled,
                          child: Tooltip(
                            message: 'Enhance Prompt',
                            child: Material(
                              color:
                                  (isDark ? Colors.grey[800] : Colors.grey[300])
                                      ?.withValues(
                                        alpha: isDisabled ? 0.5 : 1.0,
                                      ),
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: isDisabled ? null : _enhancePrompt,
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: _isEnhancing
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    theme.colorScheme.onSurface,
                                                  ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.auto_awesome,
                                            size: 20,
                                            color: theme.colorScheme.onSurface
                                                .withValues(
                                                  alpha: isDisabled ? 0.5 : 1.0,
                                                ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                // Optimize: Only rebuild the Send button when text changes, not the whole widget
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
                      decoration: BoxDecoration(
                        color: canSend
                            ? theme.colorScheme.primary
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: canSend ? _send : null,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: isGenerating
                              ? SizedBox(
                                  key: const ValueKey('spinner'),
                                  width: 18,
                                  height: 18,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_upward,
                                  key: ValueKey('send_icon'),
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                        tooltip: isGenerating ? 'Generating...' : 'Send',
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
