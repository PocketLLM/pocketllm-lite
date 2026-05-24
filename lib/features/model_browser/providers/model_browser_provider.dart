import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../domain/hf_model.dart';

class ModelBrowserState {
  final bool isLoading;
  final List<HFModel> models;
  final String query;
  final String sort;
  final String? error;

  ModelBrowserState({
    this.isLoading = false,
    this.models = const [],
    this.query = '',
    this.sort = 'downloads',
    this.error,
  });

  ModelBrowserState copyWith({
    bool? isLoading,
    List<HFModel>? models,
    String? query,
    String? sort,
    String? error,
  }) {
    return ModelBrowserState(
      isLoading: isLoading ?? this.isLoading,
      models: models ?? this.models,
      query: query ?? this.query,
      sort: sort ?? this.sort,
      error: error,
    );
  }
}

class ModelBrowserNotifier extends Notifier<ModelBrowserState> {
  @override
  ModelBrowserState build() {
    // Initial fetch on build
    Future.microtask(() => searchModels(''));
    return ModelBrowserState();
  }

  Future<void> searchModels(String query) async {
    state = state.copyWith(isLoading: true, query: query, error: null);
    try {
      final hfService = ref.read(huggingFaceServiceProvider);
      final models = await hfService.searchModels(
        query: query,
        sort: state.sort,
      );
      state = state.copyWith(isLoading: false, models: models);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setSort(String sort) async {
    if (sort == state.sort) return;
    state = state.copyWith(sort: sort);
    await searchModels(state.query);
  }
}

final modelBrowserProvider =
    NotifierProvider<ModelBrowserNotifier, ModelBrowserState>(
  ModelBrowserNotifier.new,
);

final modelDetailsProvider = FutureProvider.family<HFModel, String>((
  ref,
  modelId,
) async {
  final hfService = ref.read(huggingFaceServiceProvider);
  return await hfService.getModelDetails(modelId);
});

final modelFilesProvider = FutureProvider.family<List<HFModelFile>, String>((
  ref,
  modelId,
) async {
  final hfService = ref.read(huggingFaceServiceProvider);
  return await hfService.getModelFiles(modelId);
});
