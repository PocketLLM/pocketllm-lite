// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PocketLLM Lite';

  @override
  String get chatSettings => 'Chat Settings';

  @override
  String get enableTools => 'Native Agentic Tools';

  @override
  String get enableRag => 'Knowledge Base (RAG)';

  @override
  String get temperature => 'Temperature';

  @override
  String get topP => 'Top P';

  @override
  String get systemPrompt => 'System Prompt';

  @override
  String get applyChanges => 'Apply Changes';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteMessage => 'Delete Message';

  @override
  String get clearChat => 'Clear Conversation';

  @override
  String get settings => 'Settings';

  @override
  String get benchmarks => 'Benchmarks';

  @override
  String get history => 'History';

  @override
  String get chat => 'Chat';
}
