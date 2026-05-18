import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import '../../../../core/providers.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../../../core/widgets/m3_empty_state.dart';
import '../../domain/models/chat_persona.dart';
import '../providers/models_provider.dart';

class PersonaManagementScreen extends ConsumerStatefulWidget {
  const PersonaManagementScreen({super.key});

  @override
  ConsumerState<PersonaManagementScreen> createState() =>
      _PersonaManagementScreenState();
}

class _PersonaManagementScreenState
    extends ConsumerState<PersonaManagementScreen> {
  final List<String> _emojis = [
    '🤖',
    '🐍',
    '🎓',
    '✍️',
    '🧙',
    '🎨',
    '💼',
    '🔍',
    '🚀',
    '🧠',
    '👾',
    '🦸',
    '🕵️',
    '🦷',
    '🌍',
    '🔥',
    '⚙️',
    '📈',
    '🩺',
    '⚖️',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      appBar: M3AppBar(
        title: 'AI Personas',
        onBack: () => context.pop(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create Persona',
            onPressed: () => _showPersonaDialog(context, null),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: storage.personaBoxListenable,
        builder: (context, box, child) {
          final personas = storage.getPersonas();

          if (personas.isEmpty) {
            return const M3EmptyState(
              icon: Icons.face_retouching_natural,
              title: 'No Personas Available',
              description:
                  'Create your first custom AI persona using the "+" button.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: personas.length,
            itemBuilder: (context, index) {
              final persona = personas[index];
              final isSystem = [
                'general_assistant',
                'python_coder',
                'socratic_tutor',
                'creative_writer',
              ].contains(persona.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.8),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      M3Container(
                        Shapes.circle,
                        width: 48,
                        height: 48,
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        child: Center(
                          child: Text(
                            persona.avatarIcon,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  persona.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isSystem) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'SYSTEM',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme
                                                .onSecondaryContainer,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              persona.systemPrompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.thermostat_outlined,
                                  size: 14,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Temp: ${persona.temperature.toStringAsFixed(1)}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (persona.modelId != null) ...[
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.smart_toy_outlined,
                                    size: 14,
                                    color: colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    persona.modelId!,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit Persona',
                            onPressed: () =>
                                _showPersonaDialog(context, persona),
                          ),
                          if (!isSystem)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              tooltip: 'Delete Persona',
                              color: colorScheme.error,
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Persona?'),
                                    content: Text(
                                      'Are you sure you want to delete "${persona.name}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: colorScheme.error,
                                          foregroundColor: colorScheme.onError,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  HapticFeedback.mediumImpact();
                                  storage.deletePersona(persona.id);
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showPersonaDialog(BuildContext context, ChatPersona? persona) {
    final isEdit = persona != null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final modelsAsync = ref.read(modelsProvider);

    final nameController = TextEditingController(text: persona?.name ?? '');
    final promptController = TextEditingController(
      text: persona?.systemPrompt ?? '',
    );
    double temp = persona?.temperature ?? 0.7;
    String selectedEmoji = persona?.avatarIcon ?? '🤖';
    String? selectedModelId = persona?.modelId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isEdit ? 'Edit AI Persona' : 'Create AI Persona',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Avatar Emoji Selector
                  Text(
                    'Choose Emoji Avatar',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 52,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _emojis.length,
                      itemBuilder: (context, idx) {
                        final emo = _emojis[idx];
                        final isSel = selectedEmoji == emo;
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedEmoji = emo),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant.withValues(
                                        alpha: 0.5,
                                      ),
                                width: isSel ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                emo,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name Field
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Persona Name',
                      hintText: 'e.g. Creative Scholar',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // System Prompt Field
                  TextField(
                    controller: promptController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 2,
                    decoration: InputDecoration(
                      labelText: 'System Instructions (Prompt)',
                      hintText:
                          'Describe how this persona should behave and answer...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Temperature Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Temperature: ${temp.toStringAsFixed(1)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Tooltip(
                        message:
                            'Higher values produce more creative output, lower values are more precise.',
                        child: Icon(
                          Icons.info_outline,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: temp,
                    min: 0.0,
                    max: 1.2,
                    divisions: 12,
                    label: temp.toStringAsFixed(1),
                    onChanged: (val) => setModalState(() => temp = val),
                  ),
                  const SizedBox(height: 16),

                  // Default Associated Model (Dropdown)
                  Text(
                    'Associated Model (Optional)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  modelsAsync.when(
                    data: (models) {
                      final items = [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('No preference (use default)'),
                        ),
                        ...models.map(
                          (m) => DropdownMenuItem<String>(
                            value: m.name,
                            child: Text(m.name),
                          ),
                        ),
                      ];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: selectedModelId,
                            items: items,
                            onChanged: (val) =>
                                setModalState(() => selectedModelId = val),
                          ),
                        ),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('Error loading models'),
                  ),
                  const SizedBox(height: 24),

                  // Save Action
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        if (nameController.text.trim().isEmpty ||
                            promptController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please fill in both Name and System Instructions.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        final updated = ChatPersona(
                          id: persona?.id ?? const Uuid().v4(),
                          name: nameController.text.trim(),
                          systemPrompt: promptController.text.trim(),
                          temperature: temp,
                          avatarIcon: selectedEmoji,
                          modelId: selectedModelId,
                        );

                        HapticFeedback.heavyImpact();
                        ref.read(storageServiceProvider).savePersona(updated);
                        Navigator.pop(sheetContext);
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(isEdit ? 'Save Changes' : 'Create Persona'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
