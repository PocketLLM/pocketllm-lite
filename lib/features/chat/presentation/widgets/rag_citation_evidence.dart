import 'package:flutter/material.dart';

class RagCitationPreview {
  static void show(BuildContext context, Map<String, dynamic> citation) {
    final theme = Theme.of(context);
    final filename = citation['filename'] as String? ?? 'Source';
    final page = citation['page'] as int?;
    final section = citation['section'] as int?;
    final location = page != null
        ? 'Page $page'
        : section != null
            ? 'Section $section'
            : 'Retrieved excerpt';
    final snippet = citation['snippet'] as String? ?? '';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(filename, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(location, style: theme.textTheme.labelMedium),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    snippet,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RagCitationEvidence extends StatelessWidget {
  final List<Map<String, dynamic>> citations;
  final bool? hasRetrievedSources;

  const RagCitationEvidence({
    super.key,
    required this.citations,
    required this.hasRetrievedSources,
  });

  @override
  Widget build(BuildContext context) {
    final hasSources = hasRetrievedSources;
    if (hasSources == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasSources ? Icons.menu_book_outlined : Icons.info_outline,
                size: 14,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                hasSources
                    ? 'Retrieved context available'
                    : 'No supporting sources retrieved',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (citations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var index = 0; index < citations.length; index++)
                    ActionChip(
                      avatar: const Icon(Icons.article_outlined, size: 15),
                      label: Text('Source ${index + 1}'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          RagCitationPreview.show(context, citations[index]),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
