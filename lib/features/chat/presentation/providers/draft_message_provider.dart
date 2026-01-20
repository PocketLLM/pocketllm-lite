import 'package:flutter_riverpod/legacy.dart';

/// Provider to handle draft messages sent from other widgets (like suggestion chips)
/// to the ChatInput.
final draftMessageProvider = StateProvider<String?>((ref) => null);
