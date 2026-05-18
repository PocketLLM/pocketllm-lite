// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'PocketLLM ライト';

  @override
  String get chatSettings => 'チャット設定';

  @override
  String get enableTools => 'ネイティブエージェントツール';

  @override
  String get enableRag => '知識ベース (RAG)';

  @override
  String get temperature => '温度';

  @override
  String get topP => 'トップP';

  @override
  String get systemPrompt => 'システムプロンプト';

  @override
  String get applyChanges => '変更を適用';

  @override
  String get cancel => 'キャンセル';

  @override
  String get deleteMessage => 'メッセージを削除';

  @override
  String get clearChat => '会話をクリア';

  @override
  String get settings => '設定';

  @override
  String get benchmarks => 'ベンチマーク';

  @override
  String get history => '履歴';

  @override
  String get chat => 'チャット';
}
