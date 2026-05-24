import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../../core/providers.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../../../core/widgets/m3_empty_state.dart';
import '../../domain/models/skill.dart';

class SkillManagementScreen extends ConsumerStatefulWidget {
  const SkillManagementScreen({super.key});

  @override
  ConsumerState<SkillManagementScreen> createState() =>
      _SkillManagementScreenState();
}

class _SkillManagementScreenState extends ConsumerState<SkillManagementScreen> {
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      appBar: M3AppBar(
        title: 'Agent Skills',
        onBack: () => context.pop(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Create Skill',
            onPressed: () => _showSkillDialog(context, null),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Install from GitHub',
            onPressed: () => _showGitHubInstallDialog(context),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: storage.skillsBoxListenable,
        builder: (context, box, child) {
          final skills = storage.getSkills();

          if (skills.isEmpty) {
            return M3EmptyState(
              icon: Icons.extension_rounded,
              title: 'No Skills Installed',
              description:
                  'Install agent skills via GitHub URL or build one manually.',
              action: FilledButton.icon(
                onPressed: () => _showGitHubInstallDialog(context),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Install from GitHub'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: skills.length,
            itemBuilder: (context, index) {
              final skill = skills[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.15),
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
                          alpha: 0.4,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.extension_rounded,
                            color: colorScheme.primary,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context
                                .push('/settings/skills/details/${skill.id}');
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      skill.title,
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
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
                                      '/${skill.id}',
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                skill.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    skill.githubUrl != null
                                        ? Icons.cloud_download_outlined
                                        : Icons.edit_note_outlined,
                                    size: 14,
                                    color: colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    skill.githubUrl != null
                                        ? 'GitHub'
                                        : 'Manual',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Switch(
                            value: skill.isEnabled,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              final updated = skill.copyWith(isEnabled: val);
                              storage.saveSkill(updated);
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Edit Skill',
                                onPressed: () =>
                                    _showSkillDialog(context, skill),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: colorScheme.error,
                                  size: 20,
                                ),
                                tooltip: 'Delete Skill',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Skill?'),
                                      content: Text(
                                        'Are you sure you want to delete "${skill.title}"?',
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
                                            foregroundColor:
                                                colorScheme.onError,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    HapticFeedback.mediumImpact();
                                    storage.deleteSkill(skill.id);
                                  }
                                },
                              ),
                            ],
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

  void _showSkillDialog(BuildContext context, Skill? skill) {
    final isEdit = skill != null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final idController = TextEditingController(text: skill?.id ?? '');
    final titleController = TextEditingController(text: skill?.title ?? '');
    final descController =
        TextEditingController(text: skill?.description ?? '');
    final bodyController = TextEditingController(text: skill?.body ?? '');

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
                    isEdit ? 'Edit Skill' : 'Create Agent Skill',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Slug ID
                  TextField(
                    controller: idController,
                    enabled: !isEdit,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9\-]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Skill ID (Slug)',
                      hintText:
                          'e.g. webdesign (kebab-case, alphanumeric, dashes)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          width: 2.0,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  TextField(
                    controller: titleController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g. Web Design Expert',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          width: 2.0,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextField(
                    controller: descController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Short Description',
                      hintText:
                          'e.g. Design gorgeous Material 3 responsive layouts',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          width: 2.0,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Instructions (Body)
                  TextField(
                    controller: bodyController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 8,
                    minLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Instructions (Body)',
                      hintText:
                          'Detailed prompt instructions the AI should follow...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          width: 2.0,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Action
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        final id = idController.text.trim();
                        final title = titleController.text.trim();
                        final desc = descController.text.trim();
                        final body = bodyController.text.trim();

                        if (id.isEmpty ||
                            title.isEmpty ||
                            desc.isEmpty ||
                            body.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill in all fields.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        // Validate Unique ID
                        final storage = ref.read(storageServiceProvider);
                        if (!isEdit) {
                          final exists =
                              storage.getSkills().any((s) => s.id == id);
                          if (exists) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Skill ID already exists. Use a unique slug.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                        }

                        final newSkill = Skill(
                          id: id,
                          title: title,
                          description: desc,
                          body: body,
                          githubUrl: skill?.githubUrl,
                          isEnabled: skill?.isEnabled ?? true,
                        );

                        HapticFeedback.heavyImpact();
                        storage.saveSkill(newSkill);
                        Navigator.pop(sheetContext);
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(isEdit ? 'Save Changes' : 'Create Skill'),
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

  void _showGitHubInstallDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final urlController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: !_isImporting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          icon: Icon(
            Icons.cloud_download_outlined,
            color: colorScheme.primary,
          ),
          title: const Text('Install from GitHub'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter the GitHub repository URL, blob link, or raw SKILL.md URL to import instructions directly.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                enabled: !_isImporting,
                decoration: InputDecoration(
                  labelText: 'GitHub / Raw URL',
                  hintText:
                      'https://github.com/user/repo/blob/main/skills/SKILL.md',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              if (_isImporting) ...[
                const SizedBox(height: 16),
                const Center(
                  child: CircularProgressIndicator(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  _isImporting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _isImporting
                  ? null
                  : () async {
                      final url = urlController.text.trim();
                      if (url.isEmpty) return;

                      setDialogState(() => _isImporting = true);
                      final skill = await _fetchAndParseSkill(url);
                      setDialogState(() => _isImporting = false);

                      if (skill != null) {
                        Navigator.pop(dialogContext);
                        _showInstallPreview(context, skill);
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Failed to fetch or parse SKILL.md. Check URL & network.'),
                              backgroundColor: colorScheme.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Fetch'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Skill?> _fetchAndParseSkill(String url) async {
    try {
      var fetchUrl = url.trim();

      // Autocomplete / convert standard GitHub blob/tree URLs to Raw URLs
      if (fetchUrl.contains('github.com')) {
        // Example: https://github.com/GoogleDeepMind/science-skills/blob/main/skills/alphafold_database_fetch_and_analyze/SKILL.md
        // raw: https://raw.githubusercontent.com/GoogleDeepMind/science-skills/main/skills/alphafold_database_fetch_and_analyze/SKILL.md
        fetchUrl =
            fetchUrl.replaceFirst('github.com', 'raw.githubusercontent.com');
        fetchUrl = fetchUrl.replaceFirst('/blob/', '/');
      }

      final response = await http.get(Uri.parse(fetchUrl));
      if (response.statusCode != 200) return null;

      final content = response.body;
      final lines = content.split('\n');
      final metadata = <String, String>{};
      int bodyStartIndex = 0;

      if (lines.isNotEmpty && lines.first.trim() == '---') {
        int endIdx = -1;
        for (int i = 1; i < lines.length; i++) {
          if (lines[i].trim() == '---') {
            endIdx = i;
            break;
          }
        }
        if (endIdx != -1) {
          bodyStartIndex = endIdx + 1;
          for (int i = 1; i < endIdx; i++) {
            final line = lines[i].trim();
            if (line.isEmpty) continue;
            final colonIdx = line.indexOf(':');
            if (colonIdx != -1) {
              final key = line.substring(0, colonIdx).trim().toLowerCase();
              final val = line.substring(colonIdx + 1).trim();
              var cleanVal = val;
              if (cleanVal.startsWith('"') && cleanVal.endsWith('"')) {
                cleanVal = cleanVal.substring(1, cleanVal.length - 1);
              } else if (cleanVal.startsWith("'") && cleanVal.endsWith("'")) {
                cleanVal = cleanVal.substring(1, cleanVal.length - 1);
              }
              metadata[key] = cleanVal;
            }
          }
        }
      }

      final body = lines.sublist(bodyStartIndex).join('\n').trim();
      final id = metadata['name']?.replaceAll(' ', '-').toLowerCase() ??
          'imported-skill';
      final title = metadata['title'] ?? id.replaceAll('-', ' ').toUpperCase();
      final description =
          metadata['description'] ?? 'Imported skill from GitHub.';

      return Skill(
        id: id,
        title: title,
        description: description,
        body: body,
        githubUrl: url,
        isEnabled: true,
      );
    } catch (e) {
      debugPrint('Error fetching/parsing skill: $e');
      return null;
    }
  }

  void _showInstallPreview(BuildContext context, Skill skill) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Preview Skill Import'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Title: ${skill.title}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ID / Slug: /${skill.id}',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Description:',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                skill.description,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Instructions Snippet:',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  skill.body.length > 250
                      ? '${skill.body.substring(0, 250)}...'
                      : skill.body,
                  style: const TextStyle(
                      fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final storage = ref.read(storageServiceProvider);
              HapticFeedback.heavyImpact();
              storage.saveSkill(skill);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Installed skill "${skill.title}" successfully!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Install'),
          ),
        ],
      ),
    );
  }
}
