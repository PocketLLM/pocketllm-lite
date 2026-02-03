import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/chat_message.dart';
import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';

/// A widget that rebuilds only when the starred status of a specific message changes.
/// This is an optimization over using [ValueListenableBuilder] on the entire starred messages list,
/// which causes all bubbles to rebuild whenever any message is starred.
class StarredMessageBuilder extends ConsumerStatefulWidget {
  final ChatMessage message;
  final Widget Function(BuildContext context, bool isStarred) builder;

  const StarredMessageBuilder({
    super.key,
    required this.message,
    required this.builder,
  });

  @override
  ConsumerState<StarredMessageBuilder> createState() =>
      _StarredMessageBuilderState();
}

class _StarredMessageBuilderState extends ConsumerState<StarredMessageBuilder> {
  bool? _isStarred;
  StorageService? _storageService;

  @override
  void initState() {
    super.initState();
    // Initialize storage service and listener
    _storageService = ref.read(storageServiceProvider);
    _isStarred = _storageService!.isMessageStarred(widget.message);
    _storageService!.starredMessagesListenable.addListener(
      _onStarredMessagesChanged,
    );
  }

  @override
  void didUpdateWidget(StarredMessageBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If message instance changes, we need to re-check status
    if (oldWidget.message != widget.message) {
      _checkIsStarred();
    }
  }

  @override
  void dispose() {
    _storageService?.starredMessagesListenable.removeListener(
      _onStarredMessagesChanged,
    );
    super.dispose();
  }

  void _onStarredMessagesChanged() {
    _checkIsStarred();
  }

  void _checkIsStarred() {
    if (_storageService == null) return;

    final newIsStarred = _storageService!.isMessageStarred(widget.message);
    // Only rebuild if the status effectively changed
    if (newIsStarred != _isStarred) {
      setState(() {
        _isStarred = newIsStarred;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _isStarred ?? false);
  }
}
