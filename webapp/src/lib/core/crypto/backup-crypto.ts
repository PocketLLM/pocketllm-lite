/**
 * BackupCryptoService — Web Crypto implementation of the PocketLLM
 * backup envelope: PBKDF2-HMAC-SHA256 (600,000 iterations) key
 * derivation + AES-256-GCM authenticated encryption.
 *
 * The envelope is byte-compatible in *structure* with the mobile app
 * (.pllm schema family) so imports/exports can interoperate.
 */

const KDF_ITERATIONS = 600_000;
const SALT_BYTES = 16;
const IV_BYTES = 12;

function bufferToBase64(buf: ArrayBuffer | Uint8Array): string {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  let binary = '';
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

function base64ToBuffer(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

export interface EncryptedEnvelope {
  salt: string; // base64
  iv: string; // base64
  payload: string; // base64 ciphertext
  iterations: number;
}

export class BackupCryptoService {
  /** Derives an AES-256-GCM key from passphrase + salt via PBKDF2. */
  private async deriveKey(
    passphrase: string,
    salt: Uint8Array
  ): Promise<CryptoKey> {
    const enc = new TextEncoder();
    const material = await crypto.subtle.importKey(
      'raw',
      enc.encode(passphrase),
      'PBKDF2',
      false,
      ['deriveKey']
    );
    return crypto.subtle.deriveKey(
      {
        name: 'PBKDF2',
        salt: salt as unknown as BufferSource,
        iterations: KDF_ITERATIONS,
        hash: 'SHA-256',
      },
      material,
      { name: 'AES-GCM', length: 256 },
      false,
      ['encrypt', 'decrypt']
    );
  }

  /** Encrypts a JSON payload into the .pllm envelope. */
  async encrypt(passphrase: string, data: unknown): Promise<EncryptedEnvelope> {
    const salt = crypto.getRandomValues(new Uint8Array(SALT_BYTES));
    const iv = crypto.getRandomValues(new Uint8Array(IV_BYTES));
    const key = await this.deriveKey(passphrase, salt);
    const enc = new TextEncoder();
    const plaintext = enc.encode(JSON.stringify(data));
    const ciphertext = await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv: iv as unknown as BufferSource },
      key,
      plaintext
    );
    return {
      salt: bufferToBase64(salt),
      iv: bufferToBase64(iv),
      payload: bufferToBase64(ciphertext),
      iterations: KDF_ITERATIONS,
    };
  }

  /**
   * Decrypts a .pllm envelope. Throws `WrongPasswordError` when the
   * passphrase is wrong (AES-GCM auth failure) and `CorruptBackupError`
   * for malformed input.
   */
  async decrypt(passphrase: string, envelope: EncryptedEnvelope): Promise<unknown> {
    if (!envelope?.salt || !envelope?.iv || !envelope?.payload) {
      throw new CorruptBackupError('Missing envelope fields');
    }
    let salt: Uint8Array;
    let iv: Uint8Array;
    try {
      salt = base64ToBuffer(envelope.salt);
      iv = base64ToBuffer(envelope.iv);
    } catch {
      throw new CorruptBackupError('Invalid base64 in envelope');
    }
    const key = await this.deriveKey(passphrase, salt);
    let plaintext: ArrayBuffer;
    try {
      plaintext = await crypto.subtle.decrypt(
        { name: 'AES-GCM', iv: iv as unknown as BufferSource },
        key,
        base64ToBuffer(envelope.payload) as unknown as BufferSource
      );
    } catch {
      throw new WrongPasswordError();
    }
    try {
      return JSON.parse(new TextDecoder().decode(plaintext));
    } catch {
      throw new CorruptBackupError('Payload is not valid JSON');
    }
  }

  /** Convenience: compute the SHA-256 of a file/blob (hex). */
  async sha256Hex(data: Blob | ArrayBuffer): Promise<string> {
    const buf =
      data instanceof Blob
        ? await data.arrayBuffer()
        : (data as ArrayBuffer);
    const digest = await crypto.subtle.digest('SHA-256', buf);
    const bytes = new Uint8Array(digest);
    return Array.from(bytes)
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');
  }
}

export class WrongPasswordError extends Error {
  constructor() {
    super('Wrong backup password, or the file has been tampered with.');
    this.name = 'WrongPasswordError';
  }
}
export class CorruptBackupError extends Error {
  constructor(detail: string) {
    super(`Backup file is corrupted: ${detail}`);
    this.name = 'CorruptBackupError';
  }
}

export const backupCrypto = new BackupCryptoService();
