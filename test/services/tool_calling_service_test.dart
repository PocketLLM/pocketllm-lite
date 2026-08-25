import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/device_tool_action_service.dart';
import 'package:pocketllm_lite/services/tool_calling_service.dart';

class _RecordingDeviceActions implements DeviceToolActionService {
  String? clipboard;
  Map<String, dynamic>? note;
  DateTime? reminderTime;
  Uri? openedUrl;
  String? emailRecipient;

  @override
  Future<void> copyToClipboard(String text) async => clipboard = text;

  @override
  Future<Map<String, dynamic>> createNote(
    String title,
    String content,
  ) async {
    return note = {'id': 'note-1', 'title': title, 'content': content};
  }

  @override
  Future<void> openEmailDraft({
    required String recipient,
    required String subject,
    required String body,
  }) async {
    emailRecipient = recipient;
  }

  @override
  Future<void> openWebUrl(Uri uri) async => openedUrl = uri;

  @override
  Future<int> scheduleReminder(
    String title,
    String body,
    DateTime when,
  ) async {
    reminderTime = when;
    return 42;
  }
}

void main() {
  final service = ToolCallingService();

  test('parses canonical JSON tool calls and validates strict arguments', () {
    final call = service.parseToolCall(
      '{"tool":"calculator","arguments":{"expression":"(2 + 3) * 4"}}',
    );
    expect(call?['name'], 'calculator');
    final tool = service.getTool('calculator')!;
    expect(
        service.validateArguments(tool, {'expression': '(2 + 3) * 4'}), isNull);
    expect(service.validateArguments(tool, {'expression': 20}),
        contains('string'));
    expect(
      service.validateArguments(tool, {'expression': '2', 'shell': 'rm'}),
      contains('Unsupported'),
    );
  });

  test('calculator handler uses safe precedence-aware evaluation', () async {
    final tool = service.getTool('calculator')!;
    expect(await tool.handler({'expression': '(2 + 3) * -4'}), contains('-20'));
    expect(
      () => tool.handler({'expression': '1 / 0'}),
      throwsA(
          predicate((error) => error.toString().contains('Division by zero'))),
    );
  });

  test('parses multiple tool calls and rejects invalid execution', () async {
    final calls = service.parseToolCalls(
      '{"tool":"calculator","arguments":{"expression":"2+2"}}\n'
      '{"tool":"calculator","arguments":{"expression":4}}',
    );
    expect(calls, hasLength(2));
    final invalid = await service.execute(calls.last);
    expect(invalid.success, isFalse);
    expect(invalid.error, contains('must be a string'));
  });

  test('does not expose canned knowledge search', () {
    expect(service.getTool('knowledge_search'), isNull);
  });

  test('system information is local and contains measured platform fields',
      () async {
    final tool = service.getTool('system_info')!;
    expect(tool.requiresNetwork, isFalse);
    final output = await tool.handler(const {});
    expect(output, contains('cpuArchitecture'));
    expect(output, contains('cpuCores'));
    expect(output, isNot(contains('PocketLLM Native Core')));
  });

  test('side-effect tools require confirmation and execute real adapters',
      () async {
    final actions = _RecordingDeviceActions();
    final tools = ToolCallingService(deviceActions: actions);
    const call = ParsedToolCall(
      id: 'note-call',
      name: 'notes',
      arguments: {'title': 'Release', 'content': 'Verify signing'},
    );

    final denied = await tools.execute(call);
    expect(denied.success, isFalse);
    expect(actions.note, isNull);

    final approved = await tools.execute(
      call,
      confirm: (tool, call) async => true,
    );
    expect(approved.success, isTrue);
    expect(actions.note?['content'], 'Verify signing');
    expect(tools.getTool('notes')?.filesystemScope, contains('write'));
  });

  test('reminders require offset-aware ISO time', () async {
    final actions = _RecordingDeviceActions();
    final tools = ToolCallingService(deviceActions: actions);
    const call = ParsedToolCall(
      id: 'reminder-call',
      name: 'reminders',
      arguments: {
        'title': 'Check build',
        'body': 'Inspect the artifact',
        'scheduled_at': '2030-01-02T03:04:05',
      },
    );
    final result = await tools.execute(
      call,
      confirm: (tool, call) async => true,
    );
    expect(result.success, isFalse);
    expect(result.error, contains('explicit UTC offset'));
    expect(actions.reminderTime, isNull);
  });
}
