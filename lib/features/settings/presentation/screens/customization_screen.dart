import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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
      backgroundColor: Color(0xFF0F172AD),
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

  static const List<Color> recommendedSwatches = [
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF06B6D4),
    Color(0xFFF43F5E),
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
    Color(0xFF6366F1),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Appearance')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Live Preview Card
            _buildLivePreview(context, appearance),

            const SizedBox(height: 16),

            // 2. Presets
            _buildSectionTitle('Theme Presets'),
            _buildPresetsList(appearance, notifier),

            const SizedBox(height: 24),

            // 3. Colour Pickers
            _buildSectionTitle('Message Colours'),
            _buildColorPickerSection(
              context,
              'You',
              Color(appearance.userMsgColor),
              (c) => notifier.updateUserMsgColor(c.value),
            ),
            const SizedBox(height: 12),
            _buildColorPickerSection(
              context,
              'AI',
              Color(appearance.aiMsgColor),
              (c) => notifier.updateAiMsgColor(c.value),
            ),

            const SizedBox(height: 24),

            // 4. Bubble Shape (Corner Style)
            _buildSectionTitle('Corner Style'),
            _buildCornerStyleSection(appearance, notifier),

            const SizedBox(height: 24),

            // 5. Typography & Spacing
            _buildSectionTitle('Typography & Spacing'),
            _buildTypographySection(appearance, notifier),

            const SizedBox(height: 24),

            // 6. Advanced
            _buildAdvancedSection(appearance, notifier),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePreview(BuildContext context, AppearanceState appearance) {
    // Determine background color: custom or preset or default
    Color bgColor = Theme.of(context).scaffoldBackgroundColor;
    if (appearance.customBgColor != null) {
      bgColor = Color(appearance.customBgColor!);
    }

    return Container(
      height: 260,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Optional Bezel illustration or just plain content
            Column(
              children: [
                // Fake AppBar
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      const CircleAvatar(
                        radius: 14,
                        child: Text('AI', style: TextStyle(fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Assistant',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
                // Fake Input
                Container(
                  height: 50,
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    children: [SizedBox(width: 16), Text('Type a message...')],
                  ),
                ),
              ],
            ),
            // "Live Preview" Label
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Live Preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ...presets.map((preset) {
            final isSelected =
                appearance.userMsgColor == preset.userColor &&
                appearance.aiMsgColor == preset.aiColor;

            return Padding(
              padding: const EdgeInsets.only(right: 12),
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
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 140,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          )
                        : Border.all(color: Colors.transparent),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Color(preset.userColor),
                            radius: 6,
                          ),
                          const SizedBox(width: 4),
                          CircleAvatar(
                            backgroundColor: Color(preset.aiColor),
                            radius: 6,
                          ),
                          const Spacer(),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.blue,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        preset.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        preset.note,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        maxLines: 1,
                      ),
                    ],
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
    String label,
    Color currentColor,
    Function(Color) onColorChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Wheel / Custom Button
                InkWell(
                  onTap: () => _showFullColorPicker(
                    context,
                    currentColor,
                    onColorChanged,
                  ),
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.red, Colors.green, Colors.blue],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.colorize,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                // Swatches
                ...recommendedSwatches.map(
                  (c) => GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onColorChanged(c);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: currentColor.value == c.value
                            ? Border.all(
                                color: Theme.of(context).primaryColor,
                                width: 3,
                              )
                            : Border.all(
                                color: Colors.grey.withValues(alpha: 0.2),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildCornerStyleSection(
    AppearanceState appearance,
    AppearanceNotifier notifier,
  ) {
    double current = appearance.bubbleRadius;
    // Map radius to segmented index: 0=Sharp(4), 1=Rounded(16), 2=Pill(32)
    // Logic: closest match
    Set<double> options = {4, 16, 32};

    // Determine segmented selection
    int selectedIndex = -1;
    if ((current - 4).abs() < 2) {
      selectedIndex = 0;
    } else if ((current - 16).abs() < 4) {
      selectedIndex = 1;
    } else if ((current - 32).abs() < 4) {
      selectedIndex = 2;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(
                value: 4.0,
                label: Text('Sharp'),
                icon: Icon(Icons.square_outlined, size: 16),
              ),
              ButtonSegment(
                value: 16.0,
                label: Text('Rounded'),
                icon: Icon(Icons.rounded_corner, size: 16),
              ),
              ButtonSegment(
                value: 32.0,
                label: Text('Pill'),
                icon: Icon(Icons.circle_outlined, size: 16),
              ),
            ],
            selected: selectedIndex != -1
                ? {options.elementAt(selectedIndex)}
                : {},
            emptySelectionAllowed: true,
            onSelectionChanged: (Set<double> newSelection) {
              HapticFeedback.lightImpact();
              notifier.updateBubbleRadius(newSelection.first);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Radius', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: current,
                  min: 4,
                  max: 40,
                  divisions: 36,
                  label: current.toStringAsFixed(0),
                  onChanged: (val) {
                    if ((val - current).abs() > 1)
                      HapticFeedback.selectionClick();
                    notifier.updateBubbleRadius(val);
                  },
                ),
              ),
              Text(
                '${current.toStringAsFixed(0)} dp',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypographySection(
    AppearanceState appearance,
    AppearanceNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Font Size
          Row(
            children: [
              const Text('Font Size'),
              Expanded(
                child: Slider(
                  value: appearance.fontSize,
                  min: 12,
                  max: 24,
                  divisions: 12,
                  label: appearance.fontSize.toStringAsFixed(1),
                  onChanged: (val) {
                    notifier.updateFontSize(val);
                  },
                ),
              ),
              Text('${appearance.fontSize.toStringAsFixed(0)} sp'),
            ],
          ),
          // Chat Padding
          Row(
            children: [
              const Text('Padding'),
              Expanded(
                child: Slider(
                  value: appearance.chatPadding,
                  min: 8,
                  max: 24,
                  divisions: 16,
                  label: appearance.chatPadding.toStringAsFixed(1),
                  onChanged: (val) {
                    notifier.updateChatPadding(val);
                  },
                ),
              ),
              Text('${appearance.chatPadding.toStringAsFixed(0)} dp'),
            ],
          ),
          // Avatars
          SwitchListTile(
            title: const Text('Show Sender Avatars'),
            value: appearance.showAvatars,
            onChanged: (val) {
              HapticFeedback.lightImpact();
              notifier.updateShowAvatars(val);
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection(
    AppearanceState appearance,
    AppearanceNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ExpansionTile(
        title: const Text('Advanced', style: TextStyle(fontSize: 14)),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        children: [
          // Custom Background Color
          ListTile(
            title: const Text('Chat Background Color'),
            subtitle: const Text('Tap to pick custom color'),
            trailing: CircleAvatar(
              backgroundColor: appearance.customBgColor != null
                  ? Color(appearance.customBgColor!)
                  : Colors.grey,
              child: appearance.customBgColor == null
                  ? const Icon(Icons.block, size: 16)
                  : null,
            ),
            onTap: () {
              _showFullColorPicker(
                context,
                appearance.customBgColor != null
                    ? Color(appearance.customBgColor!)
                    : Colors.white,
                (c) {
                  notifier.updateCustomBgColor(c.value);
                },
              );
            },
          ),
          // Elevation
          SwitchListTile(
            title: const Text('Bubble Elevation'),
            subtitle: const Text('Add subtle shadow'),
            value: appearance.bubbleElevation,
            onChanged: (val) => notifier.updateBubbleElevation(val),
          ),
          // Opacity
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Message Opacity'),
          ),
          Slider(
            value: appearance.msgOpacity,
            min: 0.8,
            max: 1.0,
            divisions: 20,
            label: '${(appearance.msgOpacity * 100).toInt()}%',
            onChanged: (val) => notifier.updateMsgOpacity(val),
          ),
        ],
      ),
    );
  }
}
