import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/rag_service.dart';
import '../domain/document.dart';
import '../domain/rag_models.dart';
import '../../../core/domain/background_task.dart';
import '../../../core/providers.dart';

class RagDocumentsState {
  final bool isLoading;
  final List<IngestedDocument> documents;
  final String? error;
  final RagSetupStatus? setup;
  final List<BackgroundTask> tasks;

  RagDocumentsState({
    this.isLoading = false,
    this.documents = const [],
    this.error,
    this.setup,
    this.tasks = const [],
  });

  RagDocumentsState copyWith({
    bool? isLoading,
    List<IngestedDocument>? documents,
    String? error,
    RagSetupStatus? setup,
    List<BackgroundTask>? tasks,
  }) {
    return RagDocumentsState(
      isLoading: isLoading ?? this.isLoading,
      documents: documents ?? this.documents,
      error: error,
      setup: setup ?? this.setup,
      tasks: tasks ?? this.tasks,
    );
  }
}

class RagDocumentsNotifier extends Notifier<RagDocumentsState> {
  late final RAGService _ragService;

  @override
  RagDocumentsState build() {
    _ragService = ref.watch(ragServiceProvider);
    final taskService = ref.watch(backgroundTaskServiceProvider);
    void syncTasks() {
      state = state.copyWith(
        tasks: taskService.snapshot
            .where((task) => task.type == BackgroundTaskType.documentIndex)
            .toList(growable: false),
      );
    }

    taskService.tasks.addListener(syncTasks);
    ref.onDispose(() => taskService.tasks.removeListener(syncTasks));
    Future.microtask(_loadDocuments);
    return RagDocumentsState(
      tasks: taskService.snapshot
          .where((task) => task.type == BackgroundTaskType.documentIndex)
          .toList(growable: false),
    );
  }

  Future<void> _loadDocuments() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final values = await Future.wait([
        _ragService.getDocuments(),
        _ragService.getSetupStatus(),
      ]);
      state = state.copyWith(
        isLoading: false,
        documents: values[0] as List<IngestedDocument>,
        setup: values[1] as RagSetupStatus,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => _loadDocuments();

  Future<void> configure({
    required RagRetrievalMode mode,
    String? embeddingModelId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _ragService.configure(
        mode: mode,
        embeddingModelId: embeddingModelId,
      );
      await _loadDocuments();
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> ingestFile(File file) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _ragService.ingestDocument(file);
      await _loadDocuments(); // Reload to get the new list
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteDocument(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _ragService.deleteDocument(id);
      await _loadDocuments();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final ragDocumentsProvider =
    NotifierProvider<RagDocumentsNotifier, RagDocumentsState>(
  RagDocumentsNotifier.new,
);
