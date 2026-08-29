import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/background_task.dart';
import '../../../core/widgets/m3_app_bar.dart';
import '../../../core/widgets/m3_empty_state.dart';
import '../../../core/widgets/m3_section_header.dart';
import '../../../core/widgets/model_prerequisite_dialog.dart';
import '../domain/document.dart';
import '../domain/rag_models.dart';
import '../providers/rag_provider.dart';

class DocumentManagerScreen extends ConsumerWidget {
  const DocumentManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ragDocumentsProvider);
    final setup = state.setup;
    final ready = setup?.ready ?? false;
    return Scaffold(
      appBar: M3AppBar(
        title: 'Knowledge Base',
        onBack: () =>
            context.canPop() ? context.pop() : context.go('/settings'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ragDocumentsProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            _SetupCard(setup: setup, isLoading: state.isLoading),
            if (state.error != null) _ErrorCard(message: state.error!),
            if (state.tasks.isNotEmpty) ...[
              const M3SectionHeader(
                title: 'Indexing tasks',
                icon: Icons.pending_actions,
              ),
              ...state.tasks.take(5).map((task) => _TaskCard(task: task)),
            ],
            const M3SectionHeader(
              title: 'Documents',
              icon: Icons.library_books_outlined,
            ),
            if (state.isLoading && state.documents.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.documents.isEmpty)
              M3EmptyState(
                icon: Icons.description_outlined,
                title: ready ? 'No documents yet' : 'Finish setup first',
                description: ready
                    ? 'Add a PDF, TXT, Markdown, or CSV file. Processing and retrieval stay on this device.'
                    : 'Choose a retrieval mode and install any required local embedding model before adding files.',
              )
            else
              ...state.documents.map(
                (document) => _DocumentCard(document: document),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: !state.isLoading
            ? () => _startAddDocument(context, ref, setup)
            : null,
        icon: const Icon(Icons.add),
        label: const Text('Add document'),
      ),
    );
  }

  Future<void> _startAddDocument(
    BuildContext context,
    WidgetRef ref,
    RagSetupStatus? setup,
  ) async {
    if (setup?.ready == true) {
      await _pickDocument(context, ref);
      return;
    }
    final modelId =
        setup?.embeddingModelId ?? supportedEmbeddingModels.first.id;
    final result = await _showEmbeddingSetup(context, modelId);
    if (!context.mounted) return;
    if (result == ModelPrerequisiteResult.installed) {
      await ref.read(ragDocumentsProvider.notifier).refresh();
      if (context.mounted) await _pickDocument(context, ref);
    } else if (result == ModelPrerequisiteResult.chooseAnother) {
      await context.push('/settings/model-catalog?query=Embeddings');
      ref.invalidate(ragDocumentsProvider);
    }
  }

  Future<void> _pickDocument(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt', 'md', 'csv'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    await ref.read(ragDocumentsProvider.notifier).ingestFile(File(path));
    if (!context.mounted) return;
    final error = ref.read(ragDocumentsProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'Document indexed and ready for retrieval.'
              : 'Document indexing stopped: $error',
        ),
      ),
    );
  }
}

class _SetupCard extends ConsumerWidget {
  final RagSetupStatus? setup;
  final bool isLoading;

  const _SetupCard({required this.setup, required this.isLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = setup?.mode ?? RagRetrievalMode.keyword;
    final selectedModel = setup?.embeddingModelId;
    return Card.filled(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Retrieval setup',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusBadge(ready: setup?.ready ?? false),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<RagRetrievalMode>(
              segments: RagRetrievalMode.values
                  .map(
                    (value) => ButtonSegment(
                      value: value,
                      label: Text(value.label),
                    ),
                  )
                  .toList(growable: false),
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: isLoading
                  ? null
                  : (selection) {
                      final next = selection.single;
                      ref.read(ragDocumentsProvider.notifier).configure(
                            mode: next,
                            embeddingModelId: next.requiresEmbedding
                                ? selectedModel ??
                                    supportedEmbeddingModels.first.id
                                : null,
                          );
                    },
            ),
            const SizedBox(height: 12),
            Text(mode.description, style: theme.textTheme.bodyMedium),
            if (mode.requiresEmbedding) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    selectedModel ?? supportedEmbeddingModels.first.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Embedding model',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(28)),
                  ),
                ),
                items: supportedEmbeddingModels
                    .map(
                      (model) => DropdownMenuItem(
                        value: model.id,
                        child: Text(
                          '${model.name} · ${model.catalogSizeMb} MB',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: isLoading
                    ? null
                    : (modelId) {
                        if (modelId != null) {
                          ref.read(ragDocumentsProvider.notifier).configure(
                                mode: mode,
                                embeddingModelId: modelId,
                              );
                        }
                      },
              ),
              if (!(setup?.embeddingModelInstalled ?? false)) ...[
                const SizedBox(height: 12),
                Text(
                  'A local embedding model is required for ${mode.label.toLowerCase()} retrieval. Install it now, choose a different compatible model, or use Keyword mode without a model.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _downloadRequiredModel(
                        context,
                        ref,
                        selectedModel ?? supportedEmbeddingModels.first.id,
                      ),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download & continue'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.push(
                        '/settings/model-catalog?query=Embeddings',
                      ),
                      child: const Text('Choose another'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _downloadRequiredModel(
    BuildContext context,
    WidgetRef ref,
    String modelId,
  ) async {
    final result = await _showEmbeddingSetup(context, modelId);
    if (!context.mounted) return;
    if (result == ModelPrerequisiteResult.installed) {
      await ref.read(ragDocumentsProvider.notifier).refresh();
    } else if (result == ModelPrerequisiteResult.chooseAnother) {
      await context.push('/settings/model-catalog?query=Embeddings');
      ref.invalidate(ragDocumentsProvider);
    }
  }
}

Future<ModelPrerequisiteResult?> _showEmbeddingSetup(
  BuildContext context,
  String modelId,
) {
  return showModelPrerequisiteDialog(
    context: context,
    modelId: modelId,
    title: 'Set up document search',
    explanation:
        'PocketLLM needs this local embedding model to understand and search your documents. After verification, the interrupted document flow continues automatically.',
  );
}

class _StatusBadge extends StatelessWidget {
  final bool ready;
  const _StatusBadge({required this.ready});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ready ? colors.primaryContainer : colors.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          ready ? 'Ready' : 'Setup needed',
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color:
                    ready ? colors.onPrimaryContainer : colors.onErrorContainer,
              ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final BackgroundTask task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(task.phase),
            if (task.progress != null) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: task.progress),
            ],
            if (task.failure != null) ...[
              const SizedBox(height: 8),
              Text(
                '${task.failure!.message} ${task.failure!.action}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends ConsumerWidget {
  final IngestedDocument document;
  const _DocumentCard({required this.document});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pageCount = document.metadata['pageCount'] as int?;
    final mode = RagRetrievalMode.parse(
      document.metadata['retrievalMode'] as String?,
    );
    return Card.outlined(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: ListTile(
        minVerticalPadding: 12,
        leading: Icon(Icons.description, color: theme.colorScheme.primary),
        title: Text(document.title, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${pageCount ?? 1} page${pageCount == 1 ? '' : 's'} · '
          '${document.totalChunks} chunks · ${mode.label}',
        ),
        onTap: () => _showDetails(context, ref),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(document.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text('File: ${document.filename}'),
              Text('Size: ${document.sizeBytes} bytes'),
              Text('Pages: ${document.metadata['pageCount'] ?? 1}'),
              Text('Chunks: ${document.totalChunks}'),
              Text('Mode: ${document.metadata['retrievalMode'] ?? 'legacy'}'),
              if (document.metadata['embeddingModelId'] != null)
                Text(
                  'Embedding model: ${document.metadata['embeddingModelId']}',
                ),
              Text('Indexed: ${document.ingestedAt.toLocal()}'),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await ref
                      .read(ragDocumentsProvider.notifier)
                      .deleteDocument(document.id);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete local index'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card.filled(
      color: colors.errorContainer,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '$message\nReview setup or retry the last task.',
          style: TextStyle(color: colors.onErrorContainer),
        ),
      ),
    );
  }
}
