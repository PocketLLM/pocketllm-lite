import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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

class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({super.key});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final List<String> _selectedImages = [];

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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          ],
        ),
      ),
    );

    if (source != null) {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64 = base64Encode(bytes);
        setState(() {
          _selectedImages.add(base64);
        });
      }
    }
  }

  void _send() async {
    if (_controller.text.trim().isEmpty && _selectedImages.isEmpty) return;

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
              'Check your setup and try again.'
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

    ref
        .read(chatProvider.notifier)
        .sendMessage(
          _controller.text,
          images: _selectedImages.isNotEmpty ? [..._selectedImages] : null,
        );

    _controller.clear();
    setState(() {
      _selectedImages.clear();
    });
  }

  bool _isEnhancing = false;

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
          const SnackBar(
            content: Text('Cannot enhance prompt: Ollama not connected'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final enhancerState = ref.read(promptEnhancerProvider);
    if (enhancerState.selectedModelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a Prompt Enhancer model in Settings first.'),
          duration: Duration(seconds: 3),
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
          const SnackBar(
            content: Text('Enhancement failed—check Ollama.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
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
          ElevatedButton(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue, // Blue background
              foregroundColor: Colors.white, // White text
            ),
            child: const Text('Watch Ad'),
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
    final theme = Theme.of(context);
    final isGenerating = ref.watch(chatProvider.select((s) => s.isGenerating));
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Background of the bar area
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.transparent,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedImages.isNotEmpty)
              Container(
                height: 70,
                padding: const EdgeInsets.only(bottom: 8, top: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (c, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(_selectedImages[i]),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Semantics(
                            label: 'Remove image',
                            button: true,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _selectedImages.removeAt(i)),
                                customBorder: const CircleBorder(),
                                child: const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
              child: TextField(
                controller: _controller,
                enabled: !isGenerating && !_isEnhancing,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                maxLines: 8,
                minLines: 1,
                style: theme.textTheme.bodyLarge,
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
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: isGenerating ? null : _pickImage,
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.grey[800] : Colors.grey[300],
                        ),
                        child: Icon(
                          Icons.add,
                          size: 20,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      tooltip: 'Add Image',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    // Enhance Prompt Button - only show if enhancer model selected
                    Consumer(
                      builder: (context, ref, child) {
                        final enhancerState = ref.watch(promptEnhancerProvider);
                        final hasEnhancer =
                            enhancerState.selectedModelId != null;

                        if (!hasEnhancer) return const SizedBox.shrink();

                        return IconButton(
                          onPressed: (isGenerating || _isEnhancing)
                              ? null
                              : _enhancePrompt,
                          icon: Icon(
                            Icons.auto_awesome,
                            size: 22,
                            color: (isGenerating || _isEnhancing)
                                ? Colors.grey
                                : (isDark ? Colors.white : Colors.black),
                          ),
                          tooltip: 'Enhance Prompt',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        );
                      },
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isGenerating
                        ? Colors.grey
                        : theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: isGenerating ? null : _send,
                    icon: isGenerating
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.arrow_upward,
                            color: Colors.white,
                            size: 20,
                          ),
                    tooltip: 'Send',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}