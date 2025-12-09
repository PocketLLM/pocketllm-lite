import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/appearance_provider.dart';

class CustomizationScreen extends ConsumerWidget {
  const CustomizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Customization')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Colors'),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('User Message Color'),
              trailing: CircleAvatar(
                backgroundColor: Color(appearance.userMsgColor),
              ),
              onTap: () => _pickColor(
                context,
                appearance.userMsgColor,
                (c) => notifier.updateUserMsgColor(c.value),
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('AI Message Color'),
              trailing: CircleAvatar(
                backgroundColor: Color(appearance.aiMsgColor),
              ),
              onTap: () => _pickColor(
                context,
                appearance.aiMsgColor,
                (c) => notifier.updateAiMsgColor(c.value),
              ),
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('Typography & Layout'),
            const SizedBox(height: 16),
            const Text('Font Size'),
            Slider(
              value: appearance.fontSize,
              min: 12,
              max: 24,
              divisions: 12,
              label: appearance.fontSize.toString(),
              onChanged: (val) => notifier.updateFontSize(val),
            ),
            const SizedBox(height: 16),
            const Text('Bubble Radius'),
            Slider(
              value: appearance.bubbleRadius,
              min: 4,
              max: 32,
              divisions: 14,
              label: appearance.bubbleRadius.toString(),
              onChanged: (val) => notifier.updateBubbleRadius(val),
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('Preview'),
            const SizedBox(height: 16),
            // Mock Chat Bubble
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(appearance.userMsgColor),
                  borderRadius: BorderRadius.circular(
                    appearance.bubbleRadius,
                  ).copyWith(bottomRight: Radius.zero),
                ),
                child: Text(
                  'This is how your messages look!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: appearance.fontSize,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(appearance.aiMsgColor),
                  borderRadius: BorderRadius.circular(
                    appearance.bubbleRadius,
                  ).copyWith(bottomLeft: Radius.zero),
                ),
                child: Text(
                  'And this is how I appear.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: appearance.fontSize,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
        letterSpacing: 1.0,
      ),
    );
  }

  void _pickColor(
    BuildContext context,
    int currentColor,
    Function(Color) onColorSelected,
  ) {
    // Simple mock color picker since we don't have a package installed yet.
    // Let's provide a few preset colors.
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 200,
        child: Column(
          children: [
            const Text(
              'Select Color',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children:
                    [
                          Colors.teal,
                          Colors.blue,
                          Colors.purple,
                          Colors.deepPurple,
                          Colors.indigo,
                          Colors.redAccent,
                          Colors.orange,
                          Colors.grey[800]!,
                          Colors.black,
                          Colors.white10,
                        ]
                        .map(
                          (c) => GestureDetector(
                            onTap: () {
                              onColorSelected(c);
                              Navigator.pop(context);
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
