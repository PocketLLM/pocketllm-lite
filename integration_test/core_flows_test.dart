import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/generation_pipeline.dart';
import 'package:pocketllm_lite/services/backup_migration_service.dart';
import 'package:pocketllm_lite/services/document_ingestion_service.dart';
import 'package:pocketllm_lite/services/inference_service.dart';
import 'package:pocketllm_lite/services/local_memory_service.dart';
import 'package:pocketllm_lite/services/local_ocr_service.dart';
import 'package:pocketllm_lite/services/network_gateway.dart';
import 'package:pocketllm_lite/services/network_policy_service.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/services/tool_calling_service.dart';
import 'package:pocketllm_lite/services/vector_store_service.dart';
import 'package:pocketllm_lite/services/rag_service.dart';
import 'package:pocketllm_lite/features/rag/domain/document.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class _LocalRuntime implements InferenceService {
  bool loaded = false;
  int calls = 0;

  @override
  Future<void> loadModel(String modelId, {ProgressCallback? onProgress}) async {
    loaded = true;
    onProgress?.call(
      const InferenceProgress(progress: 1, status: 'Loaded test fixture'),
    );
  }

  @override
  Stream<ChatToken> chatStream(ChatRequest request) async* {
    if (!loaded) throw const InferenceError('Model is not loaded.');
    calls++;
    if (request.messages
        .any((message) => message.content.contains('tool_call_id'))) {
      yield const ChatToken(text: 'The calculated answer is 42.');
      return;
    }
    if (request.messages.last.content.contains('6 * 7')) {
      yield const ChatToken(
        text: '{"tool":"calculator","arguments":{"expression":"6 * 7"}}',
      );
      return;
    }
    yield const ChatToken(text: 'Local ');
    yield const ChatToken(text: 'answer');
  }

  @override
  Future<InferenceMetrics> getMetrics() async => const InferenceMetrics(
        completionTokens: 2,
        tokenCountsEstimated: false,
      );
  @override
  Future<List<double>> generateEmbeddings(String text, String modelId) async =>
      const [1, 0];
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<LLMModel>> listModels() async => const [];
  @override
  Future<void> unloadModel(String modelId) async => loaded = false;
}

class _CountingClient extends http.BaseClient {
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    return http.StreamedResponse(const Stream.empty(), 200);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late StorageService storage;
  late _LocalRuntime runtime;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pocketllm-e2e-');
    storage = StorageService();
    await storage.init(testPath: directory.path);
    await LocalMemoryService().init(storage);
    runtime = _LocalRuntime();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('local model loads, streams through the pipeline, and persists',
      (tester) async {
    await runtime.loadModel('fixture-local');
    final pipeline = GenerationPipeline(
      resolveInference: (_) async => runtime,
    );
    const request = ChatRequest(
      modelId: 'fixture-local',
      messages: [ChatRequestMessage(role: 'user', content: 'Say hello')],
    );
    final response = await pipeline.complete(request);
    expect(response.text, 'Local answer');

    final session = ChatSession(
      id: 'session-1',
      title: 'Integration chat',
      model: 'fixture-local',
      messages: [
        ChatMessage(
          role: 'user',
          content: 'Say hello',
          timestamp: DateTime.utc(2026),
        ),
        ChatMessage(
          role: 'assistant',
          content: response.text,
          timestamp: DateTime.utc(2026, 1, 1, 0, 0, 1),
        ),
      ],
      createdAt: DateTime.utc(2026),
    );
    await storage.saveChatSession(session, log: false);

    expect(storage.getChatSession('session-1')?.messages.last.content,
        'Local answer');
  });

  testWidgets('calculator tool validates, executes, and returns to the model',
      (tester) async {
    await runtime.loadModel('fixture-local');
    final pipeline = GenerationPipeline(
      resolveInference: (_) async => runtime,
      toolService: ToolCallingService(),
    );
    final result = await pipeline.complete(
      const ChatRequest(
        modelId: 'fixture-local',
        messages: [ChatRequestMessage(role: 'user', content: 'What is 6 * 7?')],
      ),
      options: const GenerationOptions(
        enableTools: true,
        allowedTools: {'calculator'},
      ),
    );

    expect(result.toolResults.single.success, isTrue);
    expect(result.toolResults.single.output, contains('42'));
    expect(result.text, 'The calculated answer is 42.');
    expect(runtime.calls, 2);
  });

  testWidgets('memory survives reinitialization and strict offline blocks I/O',
      (tester) async {
    await LocalMemoryService().saveMemory(
      UserMemoryEntry(
        id: 'memory-1',
        type: MemoryType.preference,
        subject: 'user',
        fact: 'The user prefers concise answers.',
        confidence: 0.95,
        createdAt: DateTime.utc(2026),
        memoryKey: 'response_style',
      ),
    );
    await LocalMemoryService().init(storage);
    expect(LocalMemoryService().getMemories().single.fact, contains('concise'));

    await storage.saveSetting(AppConstants.strictOfflineModeKey, true);
    final policy = NetworkPolicyService()..init(storage);
    final client = _CountingClient();
    final gateway = NetworkGateway(client: client, policy: policy);

    expect(
      () => gateway.get(
        Uri.parse('https://api.tavily.com/search'),
        purpose: ConnectionPurpose.webSearch,
        trigger: 'integration test',
        infoSent: 'test query',
      ),
      throwsA(isA<NetworkPolicyError>()),
    );
    expect(client.requests, 0);
  });

  testWidgets('PDF pages ingest, index, retrieve, and cite the correct page',
      (tester) async {
    final pdf = PdfDocument();
    pdf.pages.add().graphics.drawString(
          'General project background and planning notes.',
          PdfStandardFont(PdfFontFamily.helvetica, 12),
          bounds: const Rect.fromLTWH(40, 40, 450, 100),
        );
    pdf.pages.add().graphics.drawString(
          'Berlin launch logistics require the blue access badge.',
          PdfStandardFont(PdfFontFamily.helvetica, 12),
          bounds: const Rect.fromLTWH(40, 40, 450, 100),
        );
    final fixture = File('${directory.path}/verified_fixture.pdf');
    await fixture.writeAsBytes(await pdf.save(), flush: true);
    pdf.dispose();

    final ingested = await DocumentIngestionService().ingestFile(fixture);
    final document = ingested['document'] as IngestedDocument;
    final chunks = ingested['chunks'] as List<DocumentChunk>;
    expect(document.metadata['pageCount'], 2);
    expect(chunks.any((chunk) => chunk.metadata['page'] == 2), isTrue);

    final vectors = chunks
        .map(
          (chunk) => chunk.content.contains('blue access badge')
              ? <double>[0, 1]
              : <double>[1, 0],
        )
        .toList(growable: false);
    final withSources = chunks
        .map(
          (chunk) => DocumentChunk(
            id: chunk.id,
            documentId: chunk.documentId,
            content: chunk.content,
            index: chunk.index,
            metadata: {
              ...chunk.metadata,
              'filename': document.filename,
            },
          ),
        )
        .toList(growable: false);
    final store = VectorStoreService();
    await store.storeDocument(document, withSources, vectors);
    final matches = await store.searchHybrid(
      queryText: 'Which badge is required for Berlin?',
      queryEmbedding: const [0, 1],
      topK: 1,
    );
    final context = RetrievedDocumentContext(matches);

    expect(matches.single.chunk.metadata['page'], 2);
    expect(context.promptContext, contains('[verified_fixture.pdf, page 2]'));
    expect(context.promptContext, contains('blue access badge'));
  });

  testWidgets('encrypted backup rejects a wrong password and restores data',
      (tester) async {
    final backup = BackupMigrationService();
    final encrypted = await backup.createEncryptedBackup(
      password: 'integration test password',
      settings: {'theme_mode': 'dark'},
      chats: [
        {
          'id': 'restored-e2e',
          'title': 'Restored E2E chat',
          'model': 'fixture-local',
          'messages': <dynamic>[],
          'createdAt': DateTime.utc(2026, 8, 25).toIso8601String(),
        },
      ],
      memories: const [],
      personas: const [],
    );
    expect(encrypted, isNot(contains('Restored E2E chat')));
    await expectLater(
      backup.decryptBackup(
        encryptedJson: encrypted,
        password: 'wrong password',
      ),
      throwsA(isA<BackupDecryptError>()),
    );

    final payload = await backup.decryptBackup(
      encryptedJson: encrypted,
      password: 'integration test password',
    );
    await storage.restoreBackupDataAtomically(payload.toJson());

    expect(storage.getChatSession('restored-e2e')?.title, 'Restored E2E chat');
    expect(storage.getSetting('theme_mode'), 'dark');
  });

  testWidgets('Android OCR reads text from the supplied generated image',
      (tester) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
    final paragraphBuilder = ParagraphBuilder(
      ParagraphStyle(
        textDirection: TextDirection.ltr,
        fontSize: 60,
      ),
    )
      ..pushStyle(
        TextStyle(
          color: Color(0xFF000000),
          fontSize: 60,
          fontWeight: FontWeight.w700,
        ),
      )
      ..addText('POCKETLLM OCR 2026');
    final paragraph = paragraphBuilder.build()
      ..layout(const ParagraphConstraints(width: 900));
    canvas.drawParagraph(paragraph, const Offset(30, 60));
    final picture = recorder.endRecording();
    final image = await picture.toImage(960, 220);
    final png = await image.toByteData(format: ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    expect(png, isNotNull);

    final result = await LocalOcrService().processImageBytes(
      png!.buffer.asUint8List(),
    );
    final normalized = result.rawText.toUpperCase();

    expect(normalized, contains('POCKETLLM'));
    expect(normalized, contains('2026'));
  });
}
