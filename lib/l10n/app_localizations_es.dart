// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'PocketLLM Lite';

  @override
  String get chatSettings => 'Ajustes de Chat';

  @override
  String get enableTools => 'Herramientas de Agente Nativas';

  @override
  String get enableRag => 'Base de Conocimiento (RAG)';

  @override
  String get temperature => 'Temperatura';

  @override
  String get topP => 'Top P';

  @override
  String get systemPrompt => 'Fórmula del Sistema';

  @override
  String get applyChanges => 'Aplicar Cambios';

  @override
  String get cancel => 'Cancelar';

  @override
  String get deleteMessage => 'Eliminar Mensaje';

  @override
  String get clearChat => 'Limpiar Conversación';

  @override
  String get settings => 'Ajustes';

  @override
  String get benchmarks => 'Rendimiento';

  @override
  String get history => 'Historial';

  @override
  String get chat => 'Chat';
}
