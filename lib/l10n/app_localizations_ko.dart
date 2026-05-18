// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'PocketLLM 라이트';

  @override
  String get chatSettings => '대화 설정';

  @override
  String get enableTools => '네이티브 에이전트 도구';

  @override
  String get enableRag => '지식 베이스 (RAG)';

  @override
  String get temperature => '온도';

  @override
  String get topP => '탑P';

  @override
  String get systemPrompt => '시스템 프롬프트';

  @override
  String get applyChanges => '변경 적용';

  @override
  String get cancel => '취소';

  @override
  String get deleteMessage => '메시지 삭제';

  @override
  String get clearChat => '대화 비우기';

  @override
  String get settings => '설정';

  @override
  String get benchmarks => '벤치마크';

  @override
  String get history => '기록';

  @override
  String get chat => '채팅';
}
