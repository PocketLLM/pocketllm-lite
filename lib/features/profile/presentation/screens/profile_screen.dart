import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  Color _avatarColor = Colors.blue;
  final List<MapEntry<String, Color>> _colorOptions = const [
    MapEntry('Blue', Colors.blue),
    MapEntry('Indigo', Colors.indigo),
    MapEntry('Teal', Colors.teal),
    MapEntry('Green', Colors.green),
    MapEntry('Orange', Colors.orange),
    MapEntry('Pink', Colors.pink),
    MapEntry('Purple', Colors.purple),
    MapEntry('Grey', Colors.grey),
  ];

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _nameController = TextEditingController(
      text: storage.getSetting(AppConstants.profileNameKey, defaultValue: ''),
    );
    _bioController = TextEditingController(
      text: storage.getSetting(AppConstants.profileBioKey, defaultValue: ''),
    );
    final colorValue =
        storage.getSetting(AppConstants.profileAvatarColorKey);
    if (colorValue is int) {
      _avatarColor = Color(colorValue);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveSetting(
      AppConstants.profileNameKey,
      _nameController.text.trim(),
    );
    await storage.saveSetting(
      AppConstants.profileBioKey,
      _bioController.text.trim(),
    );
    await storage.saveSetting(
      AppConstants.profileAvatarColorKey,
      _avatarColor.toARGB32(),
    );

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _avatarColor,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Bio / status',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Avatar color', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _colorOptions.map((option) {
              final isSelected = _avatarColor.toARGB32() == option.value.toARGB32();
              return ChoiceChip(
                label: Text(option.key),
                selected: isSelected,
                selectedColor: option.value,
                backgroundColor: option.value.withValues(alpha: 0.4),
                onSelected: (_) {
                  setState(() => _avatarColor = option.value);
                  HapticFeedback.selectionClick();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
