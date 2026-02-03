import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/chat_message.dart';

final editingMessageProvider = StateProvider<ChatMessage?>((ref) => null);
