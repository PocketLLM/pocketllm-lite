import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class BackupDecryptError implements Exception {
  final String message;
  const BackupDecryptError(this.message);

  @override
  String toString() => message;
}

class BackupArchivePayload {
  final int schemaVersion;
  final String appVersion;
  final DateTime exportedAt;
  final Map<String, dynamic> settings;
  final List<dynamic> chats;
  final List<dynamic> memories;
  final List<dynamic> personas;
  final List<dynamic> prompts;

  const BackupArchivePayload({
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.settings,
    required this.chats,
    required this.memories,
    required this.personas,
    this.prompts = const [],
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'settings': settings,
        'chats': chats,
        'memories': memories,
        'personas': personas,
        'prompts': prompts,
      };

  factory BackupArchivePayload.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 2) {
      throw const BackupDecryptError('Unsupported backup format version.');
    }
    return BackupArchivePayload(
      schemaVersion: json['schemaVersion'] as int,
      appVersion: json['appVersion'] as String? ?? 'unknown',
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
      chats: List<dynamic>.from(json['chats'] as List? ?? const []),
      memories: List<dynamic>.from(json['memories'] as List? ?? const []),
      personas: List<dynamic>.from(json['personas'] as List? ?? const []),
      prompts: List<dynamic>.from(json['prompts'] as List? ?? const []),
    );
  }
}

class BackupMigrationService {
  static const int _iterations = 600000;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;

  final Cipher _cipher;
  final KdfAlgorithm _kdf;
  final Random _random;

  BackupMigrationService({Cipher? cipher, KdfAlgorithm? kdf, Random? random})
      : _cipher = cipher ?? AesGcm.with256bits(),
        _kdf = kdf ??
            Pbkdf2(
              macAlgorithm: Hmac.sha256(),
              iterations: _iterations,
              bits: 256,
            ),
        _random = random ?? Random.secure();

  Future<String> createEncryptedBackup({
    required String password,
    required Map<String, dynamic> settings,
    required List<dynamic> chats,
    required List<dynamic> memories,
    required List<dynamic> personas,
    List<dynamic> prompts = const [],
  }) async {
    if (password.length < 8) {
      throw const BackupDecryptError(
        'Use a backup password with at least 8 characters.',
      );
    }
    final payload = BackupArchivePayload(
      schemaVersion: 2,
      appVersion: '1.0.36',
      exportedAt: DateTime.now(),
      settings: settings,
      chats: chats,
      memories: memories,
      personas: personas,
      prompts: prompts,
    );
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final key = await _deriveKey(password, salt);
    final secretBox = await _cipher.encrypt(
      utf8.encode(jsonEncode(payload.toJson())),
      secretKey: key,
      nonce: nonce,
    );
    return jsonEncode({
      'format': 'pocketllm-backup',
      'version': 2,
      'kdf': {
        'name': 'PBKDF2-HMAC-SHA256',
        'iterations': _iterations,
        'salt': base64Encode(salt),
      },
      'cipher': {
        'name': 'AES-256-GCM',
        'nonce': base64Encode(secretBox.nonce),
        'mac': base64Encode(secretBox.mac.bytes),
      },
      'ciphertext': base64Encode(secretBox.cipherText),
    });
  }

  Future<BackupArchivePayload> decryptBackup({
    required String encryptedJson,
    required String password,
  }) async {
    try {
      final envelope = jsonDecode(encryptedJson) as Map<String, dynamic>;
      if (envelope['format'] != 'pocketllm-backup' ||
          envelope['version'] != 2) {
        throw const BackupDecryptError('Not a supported PocketLLM backup.');
      }
      final kdf = Map<String, dynamic>.from(envelope['kdf'] as Map);
      final cipher = Map<String, dynamic>.from(envelope['cipher'] as Map);
      if (kdf['name'] != 'PBKDF2-HMAC-SHA256' ||
          kdf['iterations'] != _iterations ||
          cipher['name'] != 'AES-256-GCM') {
        throw const BackupDecryptError('Unsupported backup cryptography.');
      }
      final salt = base64Decode(kdf['salt'] as String);
      final key = await _deriveKey(password, salt);
      final clearBytes = await _cipher.decrypt(
        SecretBox(
          base64Decode(envelope['ciphertext'] as String),
          nonce: base64Decode(cipher['nonce'] as String),
          mac: Mac(base64Decode(cipher['mac'] as String)),
        ),
        secretKey: key,
      );
      return BackupArchivePayload.fromJson(
        jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>,
      );
    } on BackupDecryptError {
      rethrow;
    } on SecretBoxAuthenticationError {
      throw const BackupDecryptError(
        'Incorrect password or the backup has been corrupted.',
      );
    } on FormatException {
      throw const BackupDecryptError('The backup file is malformed.');
    } catch (_) {
      throw const BackupDecryptError(
        'The backup could not be decrypted or validated.',
      );
    }
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) {
    return _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));
}
