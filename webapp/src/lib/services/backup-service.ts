/**
 * BackupService — encrypted `.pllm` export/import.
 *
 * Envelope: PBKDF2-HMAC-SHA256 (600k) → AES-256-GCM, 16-byte salt,
 * 12-byte IV — the same crypto parameters as the mobile app family.
 * Restore is transactional: validate everything into memory first;
 * only then commit. A failed import leaves current data untouched.
 */
import {
  activityRepo,
  branchRepo,
  chatRepo,
  chunkRepo,
  documentRepo,
  downloadRepo,
  errorRepo,
  labRunRepo,
  memoryRepo,
  messageRepo,
  networkAuditRepo,
  noteRepo,
  personaRepo,
  promptRepo,
  providerRepo,
  skillRepo,
  tagRepo,
  toolEventRepo,
  transcriptRepo,
} from '@/lib/core/db/repositories';
import {
  backupCrypto,
  CorruptBackupError,
  WrongPasswordError,
} from '@/lib/core/crypto/backup-crypto';
import { logService } from './log-service';
import { settingsService } from './settings-service';
import type { BackupEnvelope, BackupPayload } from '@/lib/types/domain';
import { APP_VERSION } from '@/lib/utils';

class BackupService {
  /** Builds the payload from all local stores. */
  private async collect(): Promise<BackupPayload> {
    const [
      chats,
      messages,
      branches,
      personas,
      prompts,
      skills,
      tags,
      notes,
      memories,
      documents,
      transcripts,
      labRuns,
      savedSearches,
    ] = await Promise.all([
      chatRepo.getAll(),
      messageRepo.getAll(),
      branchRepo.getAll(),
      personaRepo.getAll(),
      promptRepo.getAll(),
      skillRepo.getAll(),
      tagRepo.getAll(),
      noteRepo.getAll(),
      memoryRepo.getAll(),
      documentRepo.getAll(),
      transcriptRepo.getAll(),
      labRunRepo.getAll(),
      Promise.resolve(
        settingsService.get().search?.savedQueries ?? []
      ),
    ]);
    return {
      schemaVersion: 4,
      exportedAt: Date.now(),
      appVersion: APP_VERSION,
      chats,
      messages,
      branches,
      personas,
      prompts,
      skills,
      tags,
      notes,
      memories,
      documents,
      transcripts,
      labRuns,
      savedSearches,
    };
  }

  /** Exports an encrypted .pllm file and triggers a download. */
  async export(passphrase: string): Promise<void> {
    const payload = await this.collect();
    const envelope = await backupCrypto.encrypt(passphrase, payload);
    const file: BackupEnvelope = {
      magic: 'PLLM-BACKUP',
      schemaVersion: 4,
      createdAt: Date.now(),
      appVersion: APP_VERSION,
      kdf: {
        algorithm: 'PBKDF2-HMAC-SHA256',
        iterations: envelope.iterations,
        salt: envelope.salt,
      },
      cipher: { algorithm: 'AES-256-GCM', iv: envelope.iv },
      payload: envelope.payload,
    };
    const blob = new Blob([JSON.stringify(file, null, 2)], {
      type: 'application/octet-stream',
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `pocketllm-backup-${new Date().toISOString().slice(0, 10)}.pllm`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 5000);
    void logService.recordActivity('backup.exported', 'Encrypted .pllm export');
  }

  /**
   * Validates an archive (password + schema + entities) and returns a
   * preview summary WITHOUT touching live data.
   */
  async validate(
    file: File,
    passphrase: string
  ): Promise<{ payload: BackupPayload; summary: Record<string, number> }> {
    let envelope: BackupEnvelope;
    try {
      envelope = JSON.parse(await file.text()) as BackupEnvelope;
    } catch {
      throw new CorruptBackupError('File is not valid JSON');
    }
    if (envelope.magic !== 'PLLM-BACKUP') {
      throw new CorruptBackupError('Not a PocketLLM backup file');
    }
    if (![3, 4].includes(envelope.schemaVersion)) {
      throw new CorruptBackupError(
        `Unsupported schema version ${envelope.schemaVersion} (expected 3 or 4)`
      );
    }
    const payload = (await backupCrypto.decrypt(passphrase, {
      salt: envelope.kdf.salt,
      iv: envelope.cipher.iv,
      payload: envelope.payload,
      iterations: envelope.kdf.iterations,
    })) as BackupPayload;
    if (!payload || !Array.isArray(payload.chats)) {
      throw new CorruptBackupError('Payload failed entity validation');
    }
    const summary = {
      chats: payload.chats?.length ?? 0,
      messages: payload.messages?.length ?? 0,
      personas: payload.personas?.length ?? 0,
      prompts: payload.prompts?.length ?? 0,
      skills: payload.skills?.length ?? 0,
      memories: payload.memories?.length ?? 0,
      documents: payload.documents?.length ?? 0,
      notes: payload.notes?.length ?? 0,
      transcripts: payload.transcripts?.length ?? 0,
      savedSearches: payload.savedSearches?.length ?? 0,
    };
    return { payload, summary };
  }

  /**
   * Commits a validated payload. Entities merge by id (last-write-wins
   * on collision, incoming wins) — never deletes existing data. Saved
   * searches merge by value (case-insensitive, capped at 8 — the same
   * cap the History view enforces on manual saves).
   */
  async restore(payload: BackupPayload): Promise<void> {
    const p = payload;
    if (p.personas?.length) await personaRepo.putAll(p.personas);
    if (p.prompts?.length) await promptRepo.putAll(p.prompts);
    if (p.skills?.length) await skillRepo.putAll(p.skills);
    if (p.tags?.length) await tagRepo.putAll(p.tags);
    if (p.notes?.length) await noteRepo.putAll(p.notes);
    if (p.memories?.length) await memoryRepo.putAll(p.memories);
    if (p.documents?.length) await documentRepo.putAll(p.documents);
    if (p.chunks?.length) await chunkRepo.putAll(p.chunks);
    if (p.chats?.length) await chatRepo.putAll(p.chats);
    if (p.messages?.length) await messageRepo.putAll(p.messages);
    if (p.branches?.length) await branchRepo.putAll(p.branches);
    if (p.transcripts?.length) await transcriptRepo.putAll(p.transcripts);
    if (p.labRuns?.length) await labRunRepo.putAll(p.labRuns);
    if (p.savedSearches?.length) {
      const current = settingsService.get().search?.savedQueries ?? [];
      const merged = [...current];
      for (const q of p.savedSearches) {
        const trimmed = q.trim();
        if (
          trimmed &&
          merged.length < 8 &&
          !merged.some((m) => m.toLowerCase() === trimmed.toLowerCase())
        ) {
          merged.push(trimmed);
        }
      }
      settingsService.patch({ search: { savedQueries: merged } });
    }
    void logService.recordActivity(
      'backup.imported',
      `Restored ${p.chats?.length ?? 0} chats`
    );
  }

  /* ---------------------- destructive operations ---------------------- */

  /**
   * Reset — granular deletion with explicit confirmation at the UI
   * layer. Categories: chats, models, documents, memories, settings,
   * everything.
   */
  async reset(category: 'chats' | 'models' | 'documents' | 'memories' | 'settings' | 'everything'): Promise<void> {
    switch (category) {
      case 'chats': {
        const chats = await chatRepo.getAll();
        for (const c of chats) {
          const messages = await messageRepo.getByIndex('chatId', c.id);
          const branches = await branchRepo.getByIndex('chatId', c.id);
          const tools = await toolEventRepo.getByIndex('chatId', c.id);
          await messageRepo.deleteMany(messages.map((m) => m.id));
          await branchRepo.deleteMany(branches.map((b) => b.id));
          await toolEventRepo.deleteMany(tools.map((t) => t.id));
        }
        await chatRepo.clear();
        break;
      }
      case 'models': {
        await modelRepoClear();
        await downloadRepo.clear();
        break;
      }
      case 'documents': {
        const docs = await documentRepo.getAll();
        for (const d of docs) {
          const chunks = await chunkRepo.getByIndex('documentId', d.id);
          await chunkRepo.deleteMany(chunks.map((c) => c.id));
        }
        await documentRepo.clear();
        break;
      }
      case 'memories':
        await memoryRepo.clear();
        break;
      case 'settings': {
        const { settingsService } = await import('./settings-service');
        settingsService.reset();
        break;
      }
      case 'everything': {
        await this.reset('chats');
        await this.reset('models');
        await this.reset('documents');
        await this.reset('memories');
        await this.reset('settings');
        await noteRepo.clear();
        await promptRepo.clear();
        await skillRepo.clear();
        await tagRepo.clear();
        await personaRepo.clear();
        await labRunRepo.clear();
        await transcriptRepo.clear();
        await activityRepo.clear();
        await networkAuditRepo.clear();
        await errorRepo.clear();
        break;
      }
    }
  }
}

async function modelRepoClear(): Promise<void> {
  const { modelRepo } = await import('@/lib/core/db/repositories');
  await modelRepo.clear();
}

export const backupService = new BackupService();
export { WrongPasswordError, CorruptBackupError };
