import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../services/storage_service.dart';
import '../../domain/models/chat_message.dart';

/// A widget that listens to starred messages changes but only rebuilds
/// its child when the starred status of the specific [message] changes.
///
/// This avoids O(N) rebuilds of all ChatBubbles when a single message is starred.
class StarredMessageBuilder extends StatefulWidget {
  final StorageService storageService;
  final ChatMessage message;
  final Widget Function(BuildContext context, bool isStarred) builder;

  const StarredMessageBuilder({
    super.key,
    required this.storageService,
    required this.message,
    required this.builder,
  });

  @override
  State<StarredMessageBuilder> createState() => _StarredMessageBuilderState();
}

class _StarredMessageBuilderState extends State<StarredMessageBuilder> {
  late bool _isStarred;
  ValueListenable<Box>? _listenable;

  @override
  void initState() {
    super.initState();
    _isStarred = widget.storageService.isMessageStarred(widget.message);
    _listenable = widget.storageService.starredMessagesListenable;
    _listenable!.addListener(_checkForUpdates);
  }

  @override
  void didUpdateWidget(StarredMessageBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if listenable changed (e.g. storage service replaced or cache reset)
    final newListenable = widget.storageService.starredMessagesListenable;
    if (newListenable != _listenable) {
      _listenable?.removeListener(_checkForUpdates);
      _listenable = newListenable;
      _listenable!.addListener(_checkForUpdates);
    }

    // Check if message changed (e.g. recycling in ListView)
    if (widget.message != oldWidget.message) {
      _checkForUpdates();
    }
  }

  @override
  void dispose() {
    _listenable?.removeListener(_checkForUpdates);
    super.dispose();
  }

  void _checkForUpdates() {
    final newStarred = widget.storageService.isMessageStarred(widget.message);
    if (newStarred != _isStarred) {
      setState(() {
        _isStarred = newStarred;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _isStarred);
  }
}
