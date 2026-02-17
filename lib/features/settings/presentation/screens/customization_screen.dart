import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../../chat/domain/models/chat_message.dart';
import '../../../chat/presentation/widgets/chat_bubble.dart';
import '../providers/appearance_provider.dart';

class ThemePreset {
  final String name;
  final int userColor;
  final int aiColor;
  final Color backgroundColor;
  final String note;

  const ThemePreset({
    required this.name,
    required this.userColor,
    required this.aiColor,
    required this.backgroundColor,
    required this.note,
  });
}

class _ColorOption {
  final Color color;
  final String name;
  const _ColorOption(this.color, this.name);
}

class CustomizationScreen extends ConsumerStatefulWidget {
  const CustomizationScreen({super.key});

  @override
  ConsumerState<CustomizationScreen> createState() =>
      _CustomizationScreenState();
}

class _CustomizationScreenState extends ConsumerState<CustomizationScreen> {
  static const List<ThemePreset> presets = [
    ThemePreset(
      name: 'Ocean Breeze',
      userColor: 0xFF4F46E5,
      aiColor: 0xFF06B6D4,
      backgroundColor: Color(0xFFF8FAFC),
      note: 'Fresh & modern',
    ),
    ThemePreset(
      name: 'Midnight Glow',
      userColor: 0xFF8B5CF6,
      aiColor: 0xFFEC4899,
      backgroundColor: Color(0xFF0F172A),
      note: 'Dark mode favourite',
    ),
    ThemePreset(
      name: 'Sakura Dream',
      userColor: 0xFFEC4899,
      aiColor: 0xFFF472B6,
      backgroundColor: Color(0xFFFDF4FF),
      note: 'Soft & feminine',
    ),
    ThemePreset(
      name: 'Forest Whisper',
      userColor: 0xFF10B981,
      aiColor: 0xFF34D399,
      backgroundColor: Color(0xFFF0FDF4),
      note: 'Calm & nature',
    ),
    ThemePreset(
      name: 'Obsidian',
      userColor: 0xFF6366F1,
      aiColor: 0xFFA78BFA,
      backgroundColor: Color(0xFF111111),
      note: 'True black AMOLED',
    ),
    ThemePreset(
      name: 'Bubble Gum',
      userColor: 0xFFFF6BCD,
      aiColor: 0xFFC084FC,
      backgroundColor: Color(0xFFFAFAFA),
      note: 'Playful & bold',
    ),
    ThemePreset(
      name: 'Classic Telegram',
      userColor: 0xFF54A9EB,
      aiColor: 0xFFE4E4E7,
      backgroundColor: Color(0xFFFFFFFF),
      note: 'Nostalgic feel',
    ),
    ThemePreset(
      name: 'Monochrome',
      userColor: 0xFF1F2937,
      aiColor: 0xFFE5E7EB,
      backgroundColor: Color(0xFFFFFFFF),
      note: 'Minimal & clean',
    ),
  ];

  static const List<_ColorOption> recommendedSwatches = [
    _ColorOption(Color(0xFF4F46E5), 'Indigo'),
    _ColorOption(Color(0xFF7C3AED), 'Violet'),
    _ColorOption(Color(0xFFEC4899), 'Pink'),
    _ColorOption(Color(0xFFF59E0B), 'Amber'),
    _ColorOption(Color(0xFF10B981), 'Emerald'),
    _ColorOption(Color(0xFF06B6D4), 'Cyan'),
    _ColorOption(Color(0xFFF43F5E), 'Rose'),
    _ColorOption(Color(0xFF8B5CF6), 'Purple'),
    _ColorOption(Color(0xFF0EA5E9), 'Sky Blue'),
    _ColorOption(Color(0xFF6366F1), 'Light Indigo'),
  ];

  // Dummy messages for preview
  final List<ChatMessage> _previewMessages = [
    ChatMessage(
      role: 'user',
      content: 'Hey! How does the new design look?',
      timestamp: DateTime.now(),
    ),
    ChatMessage(
      role: 'assistant',
      content:
          'It looks stunning! The live preview updates instantly effectively.',
      timestamp: DateTime.now(),
    ),
    ChatMessage(role: 'user', content: 'Awesome.', timestamp: DateTime.now()),
  ];

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (GoRouter.of(context).canPop()) {
          context.pop();
        } else {
          context.go('/settings');
        }
      },
      child: Scaffold(
        appBar: M3AppBar(
          title: 'Chat Appearance',
          onBack: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // 1. Live Preview Card
            _buildLivePreview(context, appearance),
            const SizedBox(height: 24),

            // 2. Presets
            Text(
              'Theme Presets',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _buildPresetsList(appearance, notifier),
            const SizedBox(height: 24),

            // 3. Typography & Spacing (Spinners)
            Text(
              'Typography & Layout',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildNumberStepper(
                    context,
                    label: 'Font Size',
                    value: appearance.fontSize,
                    min: 12,
                    max: 24,
                    suffix: 'sp',
                    onChanged: (val) => notifier.updateFontSize(val),
                  ),
                  const Divider(height: 24),
                  _buildNumberStepper(
                    context,
                    label: 'Bubble Radius',
                    value: appearance.bubbleRadius,
                    min: 4,
                    max: 40,
                    step: 4,
                    suffix: 'dp',
                    onChanged: (val) => notifier.updateBubbleRadius(val),
                  ),
                  const Divider(height: 24),
                  _buildNumberStepper(
                    context,
                    label: 'Padding',
                    value: appearance.chatPadding,
                    min: 8,
                    max: 24,
                    step: 2,
                    suffix: 'dp',
                    onChanged: (val) => notifier.updateChatPadding(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Colour Pickers
            Text(
              'Message Colors',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'User Bubble',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildColorPickerSection(
                    context,
                    Color(appearance.userMsgColor),
                    (c) => notifier.updateUserMsgColor(c.toARGB32()),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('AI Bubble', style: theme.textTheme.labelLarge),
                  ),
                  const SizedBox(height: 8),
                  _buildColorPickerSection(
                    context,
                    Color(appearance.aiMsgColor),
                    (c) => notifier.updateAiMsgColor(c.toARGB32()),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 5. Advanced
            Text(
              'Advanced',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Show Avatars'),
                    subtitle: const Text(
                      'Display sender icons next to messages',
                    ),
                    value: appearance.showAvatars,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      notifier.updateShowAvatars(val);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Chat Background'),
                    subtitle: const Text(
                      'Tap to set a custom background color',
                    ),
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: appearance.customBgColor != null
                            ? Color(appearance.customBgColor!)
                            : theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: appearance.customBgColor == null
                          ? Icon(
                              Icons.close,
                              size: 14,
                              color: theme.colorScheme.onSurface,
                            )
                          : null,
                    ),
                    onTap: () {
                      _showFullColorPicker(
                        context,
                        appearance.customBgColor != null
                            ? Color(appearance.customBgColor!)
                            : Colors.white,
                        (c) {
                          notifier.updateCustomBgColor(c.toARGB32());
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberStepper(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    double step = 1.0,
    required String suffix,
    required Function(double) onChanged,
  }) {
    final theme = Theme.of(context);
    final isMin = value <= min;
    final isMax = value >= max;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: isMin
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        onChanged(value - step);
                      },
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                color: theme.colorScheme.onSurface,
              ),
              Container(
                width: 1,
                height: 20,
                color: theme.colorScheme.outlineVariant,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${value.toStringAsFixed(0)} $suffix',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 20,
                color: theme.colorScheme.outlineVariant,
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: isMax
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        onChanged(value + step);
                      },
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                color: theme.colorScheme.onSurface,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLivePreview(BuildContext context, AppearanceState appearance) {
    Color bgColor = Theme.of(context).scaffoldBackgroundColor;
    if (appearance.customBgColor != null) {
      bgColor = Color(appearance.customBgColor!);
    }

    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Column(
              children: [
                // Fake AppBar
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.9),
                  child: Row(
                    children: [
                      Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Assistant',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _previewMessages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: _previewMessages[index]);
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility,
                      size: 14,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Live Preview',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsList(
    AppearanceState appearance,
    AppearanceNotifier notifier,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...presets.map((preset) {
            final isSelected =
                appearance.userMsgColor == preset.userColor &&
                appearance.aiMsgColor == preset.aiColor;

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Semantics(
                selected: isSelected,
                button: true,
                label: '${preset.name} theme',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      notifier.applyPreset(
                        userColor: preset.userColor,
                        aiColor: preset.aiColor,
                        radius: appearance.bubbleRadius,
                        fontSize: appearance.fontSize,
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 120,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Color(preset.userColor),
                                radius: 8,
                              ),
                              const SizedBox(width: -4),
                              CircleAvatar(
                                backgroundColor: Color(preset.aiColor),
                                radius: 8,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            preset.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            preset.note,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withValues(alpha: 0.7)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildColorPickerSection(
    BuildContext context,
    Color currentColor,
    Function(Color) onColorChanged,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Wheel / Custom Button
          Semantics(
            label: 'Pick custom color',
            button: true,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.green, Colors.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: InkWell(
                  onTap: () => _showFullColorPicker(
                    context,
                    currentColor,
                    onColorChanged,
                  ),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.colorize_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Swatches
          ...recommendedSwatches.map((option) {
            final isSelected =
                currentColor.toARGB32() == option.color.toARGB32();

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Semantics(
                label: '${option.name} color',
                selected: isSelected,
                button: true,
                child: Material(
                  color: option.color,
                  shape: const CircleBorder(),
                  elevation: isSelected ? 4 : 0,
                  shadowColor: option.color.withValues(alpha: 0.4),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onColorChanged(option.color);
                    },
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 44 : 36,
                      height: isSelected ? 44 : 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : Border.all(
                                color: Colors.black.withValues(alpha: 0.05),
                                width: 1,
                              ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 22,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showFullColorPicker(
    BuildContext context,
    Color currentColor,
    Function(Color) onColorChanged,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        Color pickerColor = currentColor;
        return AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (c) => pickerColor = c,
              enableAlpha: false,
              displayThumbColor: true,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Done'),
              onPressed: () {
                onColorChanged(pickerColor);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}
