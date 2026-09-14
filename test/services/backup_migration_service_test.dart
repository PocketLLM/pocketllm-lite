import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/backup_migration_service.dart';

void main() {
  group('authenticated backup', () {
    final service = BackupMigrationService();

    test('encrypts payload and restores it with the correct password',
        () async {
      final encrypted = await service.createEncryptedBackup(
        password: 'correct horse battery staple',
        settings: {'theme': 'dark'},
        chats: [
          {'id': 'c1', 'content': 'private chat text'},
        ],
        memories: [
          {'id': 'm1'},
        ],
        personas: [
          {'id': 'p1'},
        ],
        prompts: [
          {'id': 'prompt-1', 'content': 'Be concise'},
        ],
        skills: [
          {'id': 'skill-1', 'body': 'Verified skill instructions'},
        ],
        documentIndex: {
          'schemaVersion': 2,
          'documents': <String, dynamic>{},
          'chunks': <String, dynamic>{},
          'embeddings': <String, dynamic>{},
        },
      );

      expect(encrypted, contains('AES-256-GCM'));
      expect(encrypted, isNot(contains('private chat text')));
      expect(encrypted, isNot(contains('"theme":"dark"')));

      final restored = await service.decryptBackup(
        encryptedJson: encrypted,
        password: 'correct horse battery staple',
      );
      expect(restored.schemaVersion, 4);
      expect(restored.settings['theme'], 'dark');
      expect(restored.chats.single['id'], 'c1');
      expect(restored.prompts.single['id'], 'prompt-1');
      expect(restored.skills.single['id'], 'skill-1');
      expect(restored.documentIndex['schemaVersion'], 2);
    });

    test('wrong password and ciphertext corruption fail authentication',
        () async {
      final encrypted = await service.createEncryptedBackup(
        password: 'correct horse battery staple',
        settings: const {},
        chats: const [],
        memories: const [],
        personas: const [],
      );

      expect(
        () => service.decryptBackup(
          encryptedJson: encrypted,
          password: 'incorrect password',
        ),
        throwsA(isA<BackupDecryptError>()),
      );

      final envelope = jsonDecode(encrypted) as Map<String, dynamic>;
      final bytes = base64Decode(envelope['ciphertext'] as String);
      bytes[0] ^= 0xff;
      envelope['ciphertext'] = base64Encode(bytes);
      expect(
        () => service.decryptBackup(
          encryptedJson: jsonEncode(envelope),
          password: 'correct horse battery staple',
        ),
        throwsA(isA<BackupDecryptError>()),
      );
    });
  });
}
