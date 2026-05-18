// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'PocketLLM 精简版';

  @override
  String get chatSettings => '对话设置';

  @override
  String get enableTools => '原生智能代理工具';

  @override
  String get enableRag => '离线知识库 (RAG)';

  @override
  String get temperature => '温度';

  @override
  String get topP => '核采样 (Top P)';

  @override
  String get systemPrompt => '系统提示词';

  @override
  String get applyChanges => '保存并应用';

  @override
  String get cancel => '取消';

  @override
  String get deleteMessage => '删除消息';

  @override
  String get clearChat => '清空对话记录';

  @override
  String get settings => '设置';

  @override
  String get benchmarks => '性能测试';

  @override
  String get history => '历史记录';

  @override
  String get chat => '对话';
}
