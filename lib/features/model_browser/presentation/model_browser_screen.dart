import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/widgets/m3_app_bar.dart';
import '../providers/model_browser_provider.dart';
import '../domain/hf_model.dart';
import 'model_detail_screen.dart'; // We'll navigate to this

class ModelBrowserScreen extends ConsumerStatefulWidget {
  const ModelBrowserScreen({super.key});

  @override
  ConsumerState<ModelBrowserScreen> createState() => _ModelBrowserScreenState();
}

class _ModelBrowserScreenState extends ConsumerState<ModelBrowserScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    ref.read(modelBrowserProvider.notifier).searchModels(query);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(modelBrowserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: M3AppBar(
        title: 'Hugging Face Models',
        onBack: () {
          if (GoRouter.of(context).canPop()) {
            context.pop();
          } else {
            context.go('/chat'); // Fallback
          }
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search GGUF models...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
              ),
              onSubmitted: _onSearch,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildSortChip(theme, 'Downloads', 'downloads'),
                const SizedBox(width: 8),
                _buildSortChip(theme, 'Likes', 'likes'),
                const SizedBox(width: 8),
                _buildSortChip(theme, 'Recent', 'lastModified'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: state.isLoading
                ? _buildLoadingState()
                : state.error != null
                    ? Center(
                        child: Text(
                          'Error: ${state.error}',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      )
                    : state.models.isEmpty
                        ? const Center(child: Text('No models found.'))
                        : ListView.builder(
                            itemCount: state.models.length,
                            itemBuilder: (context, index) {
                              final model = state.models[index];
                              return _buildModelCard(context, model, theme);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(ThemeData theme, String label, String sortKey) {
    final currentSort = ref.watch(modelBrowserProvider).sort;
    final isSelected = currentSort == sortKey;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ref.read(modelBrowserProvider.notifier).setSort(sortKey);
        }
      },
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.primary,
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModelCard(BuildContext context, HFModel model, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () {
          context.push('/model-detail', extra: model.id);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      model.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (model.isGated)
                    Icon(
                      Icons.lock,
                      size: 16,
                      color: theme.colorScheme.tertiary,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                model.author,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.download,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(model.downloads),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.favorite,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(model.likes),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
