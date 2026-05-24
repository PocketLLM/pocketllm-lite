import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/widgets/m3_app_bar.dart';
import '../providers/rag_provider.dart';

class DocumentManagerScreen extends ConsumerWidget {
  const DocumentManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ragDocumentsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: M3AppBar(
        title: 'RAG Documents',
        onBack: () {
          if (GoRouter.of(context).canPop()) {
            context.pop();
          } else {
            context.go('/settings');
          }
        },
      ),
      body: state.isLoading && state.documents.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Text(
                    'Error: ${state.error}',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                )
              : state.documents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.library_books,
                            size: 64,
                            color:
                                theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No documents added yet.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add PDF, TXT, MD, or CSV files to build your knowledge base.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: state.documents.length,
                      itemBuilder: (context, index) {
                        final doc = state.documents[index];
                        final sizeMB = doc.sizeBytes / (1024 * 1024);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(
                            alpha: 0.3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: theme.colorScheme.outlineVariant),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            leading: Icon(
                              Icons.description,
                              color: theme.colorScheme.primary,
                              size: 32,
                            ),
                            title: Text(
                              doc.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '${sizeMB.toStringAsFixed(2)} MB • ${doc.totalChunks} chunks',
                                ),
                                Text(
                                  'Added: ${doc.ingestedAt.toLocal().toString().split(' ')[0]}',
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: theme.colorScheme.error,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Document?'),
                                    content: Text(
                                      'Are you sure you want to delete "${doc.title}" from your knowledge base?',
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
                                          backgroundColor:
                                              theme.colorScheme.error,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  ref
                                      .read(ragDocumentsProvider.notifier)
                                      .deleteDocument(doc.id);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isLoading
            ? null
            : () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf', 'txt', 'md', 'csv'],
                );

                if (result != null && result.files.single.path != null) {
                  final file = File(result.files.single.path!);

                  // Show loading snackbar
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Ingesting document... this may take a moment.',
                            ),
                          ],
                        ),
                        duration: Duration(
                          seconds: 10,
                        ), // Will be hidden manually or replaced
                      ),
                    );
                  }

                  await ref
                      .read(ragDocumentsProvider.notifier)
                      .ingestFile(file);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    final error = ref.read(ragDocumentsProvider).error;
                    if (error == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Document successfully added!'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to add: $error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
        icon: const Icon(Icons.add),
        label: const Text('Add Document'),
      ),
    );
  }
}
