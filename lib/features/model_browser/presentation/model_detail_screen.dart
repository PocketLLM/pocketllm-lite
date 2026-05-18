import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/widgets/m3_app_bar.dart';
import '../providers/model_browser_provider.dart';
import '../domain/hf_model.dart';
import '../../../services/model_download_service.dart';

class ModelDetailScreen extends ConsumerWidget {
  final String modelId;

  const ModelDetailScreen({super.key, required this.modelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(modelDetailsProvider(modelId));
    final filesAsync = ref.watch(modelFilesProvider(modelId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: M3AppBar(title: 'Model Details', onBack: () => context.pop()),
      body: detailsAsync.when(
        data: (model) {
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'by ${model.author}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatChip(
                            theme,
                            Icons.download,
                            '${model.downloads} downloads',
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip(
                            theme,
                            Icons.favorite,
                            '${model.likes} likes',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Available Files (GGUF)',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              filesAsync.when(
                data: (files) {
                  if (files.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          'No GGUF files found for this model.',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final file = files[index];
                        return _buildFileCard(context, file, model, theme);
                      }, childCount: files.length),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) =>
                    SliverToBoxAdapter(child: Text('Error loading files: $e')),
              ),
              if (model.description != null) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text('Readme', style: theme.textTheme.titleLarge),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: MarkdownBody(
                      data: model.description!,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildStatChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(
    BuildContext context,
    HFModelFile file,
    HFModel model,
    ThemeData theme,
  ) {
    final sizeGB = file.sizeBytes / (1024 * 1024 * 1024);

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        title: Text(
          file.filename,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          'Size: ${sizeGB.toStringAsFixed(2)} GB • Quantization: ${file.type}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: FilledButton.icon(
          onPressed: () async {
            // Trigger download via ModelDownloadService
            final service = ModelDownloadService();
            await service.downloadModelWithDialog(
              context,
              modelName: '${model.name} (${file.type})',
              url: file.url,
              expectedFilename: file.filename,
              expectedSizeBytes: file.sizeBytes,
            );
          },
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Download'),
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ),
    );
  }
}
