import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/rag_service.dart';
import '../domain/document.dart';

class RagDocumentsState {
  final bool isLoading;
  final List<IngestedDocument> documents;
  final String? error;

  RagDocumentsState({
    this.isLoading = false,
    this.documents = const [],
    this.error,
  });

  RagDocumentsState copyWith({
    bool? isLoading,
    List<IngestedDocument>? documents,
    String? error,
  }) {
    return RagDocumentsState(
      isLoading: isLoading ?? this.isLoading,
      documents: documents ?? this.documents,
      error: error,
    );
  }
}

class RagDocumentsNotifier extends Notifier<RagDocumentsState> {
  late final RAGService _ragService;

  @override
  RagDocumentsState build() {
    _ragService = ref.watch(ragServiceProvider);
    Future.microtask(_loadDocuments);
    return RagDocumentsState();
  }

  Future<void> _loadDocuments() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final docs = await _ragService.getDocuments();
      state = state.copyWith(isLoading: false, documents: docs);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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
