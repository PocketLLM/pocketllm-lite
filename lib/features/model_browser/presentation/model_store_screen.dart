import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/background_task.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/m3_app_bar.dart';
import '../../../core/widgets/m3_empty_state.dart';
import '../../../core/widgets/m3_section_header.dart';
import '../../../providers/model_manager_provider.dart';
import '../domain/model_store_model.dart';
import '../providers/model_store_provider.dart';

class ModelStoreScreen extends ConsumerStatefulWidget {
  const ModelStoreScreen({super.key});

  @override
  ConsumerState<ModelStoreScreen> createState() => _ModelStoreScreenState();
}

class _ModelStoreScreenState extends ConsumerState<ModelStoreScreen> {
  final _search = TextEditingController();
  ModelStoreRuntime? _runtime;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(modelStoreCatalogProvider);
    final installed =
        ref.watch(installedStoreModelIdsProvider).asData?.value ?? <String>{};
    final taskService = ref.watch(backgroundTaskServiceProvider);
    return Scaffold(
      appBar: M3AppBar(
        title: 'Model Store',
        subtitle: 'Discover and manage on-device model files',
        onBack: () => context.pop(),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(modelStoreCatalogProvider);
              ref.invalidate(installedStoreModelIdsProvider);
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh catalog and local models',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(modelStoreCatalogProvider);
          ref.invalidate(installedStoreModelIdsProvider);
          await ref.read(modelStoreCatalogProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search model name or capability',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(28)),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _runtime == null,
                    onSelected: (_) => setState(() => _runtime = null),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Chat & embeddings'),
                    selected: _runtime == ModelStoreRuntime.onDevice,
                    onSelected: (_) => setState(
                      () => _runtime = ModelStoreRuntime.onDevice,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Speech'),
                    selected: _runtime == ModelStoreRuntime.speech,
                    onSelected: (_) => setState(
                      () => _runtime = ModelStoreRuntime.speech,
                    ),
                  ),
                ],
              ),
            ),
            const M3SectionHeader(title: 'Sources and local files'),
            Card.outlined(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.travel_explore),
                    title: const Text('Hugging Face GGUF'),
                    subtitle: const Text(
                      'Search live Hub results and inspect exact GGUF files',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/model-browser'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: const Text('Browse Files'),
                    subtitle: const Text(
                      'Import a local GGUF file into managed app storage',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/local-models'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.memory),
                    title: const Text('Installed local models'),
                    subtitle:
                        Text('${installed.length} model folders detected'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/settings/local-models'),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<List<BackgroundTask>>(
              valueListenable: taskService.tasks,
              builder: (context, tasks, _) {
                final downloads = tasks
                    .where(
                        (task) => task.type == BackgroundTaskType.modelDownload)
                    .toList(growable: false);
                if (downloads.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: [
                    const M3SectionHeader(title: 'Download tasks'),
                    ...downloads.take(5).map(_DownloadTaskCard.new),
                  ],
                );
              },
            ),
            const M3SectionHeader(title: 'On-device catalog'),
            catalog.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => M3EmptyState(
                icon: Icons.cloud_off,
                title: 'Catalog unavailable',
                description:
                    '$error\nEnable online model browsing and disable Strict Offline to retry.',
                action: FilledButton.tonal(
                  onPressed: () => ref.invalidate(modelStoreCatalogProvider),
                  child: const Text('Retry'),
                ),
              ),
              data: (models) {
                final query = _search.text.trim().toLowerCase();
                final visible = models.where((model) {
                  if (_runtime != null && model.runtime != _runtime) {
                    return false;
                  }
                  return query.isEmpty ||
                      model.name.toLowerCase().contains(query) ||
                      model.id.toLowerCase().contains(query) ||
                      model.capabilities.any(
                        (value) => value.toLowerCase().contains(query),
                      );
                }).toList(growable: false);
                if (visible.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No catalog models match these filters.'),
                  );
                }
                return Column(
                  children: visible
                      .map(
                        (model) => _ModelCard(
                          model: model,
                          installed: installed.contains(model.id),
                          onInstalled: () {
                            ref.invalidate(installedStoreModelIdsProvider);
                            ref
                                .read(modelManagerProvider.notifier)
                                .scanLocalModels();
                          },
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelCard extends ConsumerWidget {
  final ModelStoreModel model;
  final bool installed;
  final VoidCallback onInstalled;

  const _ModelCard({
    required this.model,
    required this.installed,
    required this.onInstalled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(model.name, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${model.sizeMb} MB · Q${model.quantizationBits} · '
            '${model.capabilities.join(', ')}\n${model.source}',
          ),
        ),
        trailing: installed
            ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
            : IconButton.filledTonal(
                onPressed: () => _confirmDownload(context, ref),
                icon: const Icon(Icons.download),
                tooltip: 'Download model',
              ),
        onTap: () => _showDetails(context),
      ),
    );
  }

  Future<void> _confirmDownload(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Download ${model.name}?'),
        content: Text(
          '${model.sizeMb} MB catalog size. The bundle downloads from the '
          'Cactus catalog and is extracted into private app storage.\n\n'
          'License metadata is not supplied by this catalog response; review '
          'the upstream model terms before redistribution.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(modelDownloadServiceProvider).downloadManagedBundle(
            modelId: model.id,
            modelName: model.name,
            url: model.downloadUrl,
            archiveFilename: model.archiveFilename,
            catalogSizeMb: model.sizeMb,
          );
      onInstalled();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model install stopped: $error')),
      );
    }
  }

  Future<void> _showDetails(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(model.name,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                SelectableText('ID: ${model.id}'),
                Text('Runtime: ${model.runtime.name}'),
                Text('Catalog size: ${model.sizeMb} MB'),
                Text('Quantization: ${model.quantizationBits}-bit'),
                Text('Capabilities: ${model.capabilities.join(', ')}'),
                Text('Source: ${model.source}'),
                const Text('License: not supplied by catalog metadata'),
              ],
            ),
          ),
        ),
      );
}

class _DownloadTaskCard extends ConsumerWidget {
  final BackgroundTask task;
  const _DownloadTaskCard(this.task);

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card.outlined(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ListTile(
          title: Text(task.title, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.failure == null
                  ? task.phase
                  : '${task.failure!.message} ${task.failure!.action}'),
              if (task.progress != null) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(value: task.progress),
              ],
            ],
          ),
          trailing: task.state == BackgroundTaskState.running
              ? IconButton(
                  onPressed: () => ref
                      .read(modelDownloadServiceProvider)
                      .cancelManagedDownload(task.id),
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel and keep safe resumable data',
                )
              : null,
        ),
      );
}
