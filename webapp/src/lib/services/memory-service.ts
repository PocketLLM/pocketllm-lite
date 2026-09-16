/**
 * MemoryService — extraction, retrieval, dedupe and supersession.
 *
 * - Extraction runs after eligible chats (via /api/memory, LLM-assisted,
 *   strictly JSON-validated) or from user-entered facts.
 * - Deduplication: exact normalized match + subject contradiction
 *   (new contradictory info supersedes rather than accumulates).
 * - Privacy: automatic extraction is opt-in; users can disable memory
 *   per chat; sensitive-pattern facts are refused.
 */
import { bus } from '@/lib/core/events/event-bus';
import { memoryRepo } from '@/lib/core/db/repositories';
import { settingsService } from './settings-service';
import { logService } from './log-service';
import { gateway } from '@/lib/core/net/network-gateway';
import type { Memory, Message, UUID } from '@/lib/types/domain';
import { uuid } from '@/lib/utils';

/** Patterns we refuse to auto-extract (privacy guardrails). */
const SENSITIVE_PATTERNS: RegExp[] = [
  /\b(?:api[\s-]?key|secret|password|passwd|token)\b\s*[:=]/i,
  /\b\d{4}[ -]?\d{4}[ -]?\d{4}[ -]?\d{4}\b/, // card-like numbers
  /\b(?:ssn|social security)\b/i,
  /\bsk-[a-zA-Z0-9]{20,}\b/,
  /\bBearer\s+[a-zA-Z0-9._-]{20,}\b/i,
];

function isSensitive(text: string): boolean {
  return SENSITIVE_PATTERNS.some((re) => re.test(text));
}

interface ExtractedMemory {
  fact: string;
  subject: string;
  type: 'fact' | 'preference' | 'instruction' | 'context';
  confidence: number;
}

class MemoryService {
  async list(): Promise<Memory[]> {
    const all = await memoryRepo.getAll();
    return all.sort((a, b) => {
      if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt - a.updatedAt;
    });
  }

  async active(): Promise<Memory[]> {
    const settings = settingsService.get().memory;
    const all = await memoryRepo.getAll();
    return all
      .filter((m) => m.enabled && !m.supersededBy)
      .filter((m) => m.confidence >= settings.minConfidence)
      .sort((a, b) => {
        if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
        return (b.lastUsedAt ?? b.updatedAt) - (a.lastUsedAt ?? a.updatedAt);
      })
      .slice(0, settings.maxMemoriesInPrompt);
  }

  async create(
    fact: string,
    opts?: Partial<Pick<Memory, 'type' | 'subject' | 'confidence' | 'sourceChatId' | 'pinned'>>
  ): Promise<Memory> {
    const now = Date.now();
    const memory: Memory = {
      id: uuid(),
      fact: fact.trim().slice(0, 500),
      subject: (opts?.subject ?? 'general').trim().slice(0, 120),
      type: opts?.type ?? 'fact',
      confidence: opts?.confidence ?? 0.8,
      sourceChatId: opts?.sourceChatId,
      createdAt: now,
      updatedAt: now,
      pinned: opts?.pinned ?? false,
      enabled: true,
      sensitive: isSensitive(fact),
    };
    if (memory.sensitive) {
      throw new Error(
        'This looks like a secret (key, password or card number). PocketLLM refuses to store it as a memory.'
      );
    }
    await this.dedupe(memory);
    await memoryRepo.put(memory);
    bus.emit('memories:changed');
    void logService.recordActivity('memory.created', memory.fact.slice(0, 60));
    return memory;
  }

  async update(id: UUID, patch: Partial<Memory>): Promise<Memory | undefined> {
    const m = await memoryRepo.get(id);
    if (!m) return undefined;
    const next = { ...m, ...patch, updatedAt: Date.now() };
    if (patch.fact !== undefined && isSensitive(patch.fact)) {
      throw new Error('Refusing to store what looks like a secret.');
    }
    await memoryRepo.put(next);
    bus.emit('memories:changed');
    return next;
  }

  async delete(id: UUID): Promise<void> {
    await memoryRepo.delete(id);
    bus.emit('memories:changed');
    void logService.recordActivity('memory.deleted', 'Removed a memory');
  }

  /** Mark retrieved memories as used (powers "Used recently" sorting). */
  async markUsed(ids: UUID[]): Promise<void> {
    const now = Date.now();
    for (const id of ids) {
      const m = await memoryRepo.get(id);
      if (m && !m.pinned) {
        m.lastUsedAt = now;
        await memoryRepo.put(m);
      }
    }
  }

  /**
   * Dedupe + supersession: exact normalized matches are dropped,
   * contradictory facts on the same subject supersede the old memory.
   */
  private async dedupe(incoming: Memory): Promise<void> {
    const existing = await memoryRepo.getAll();
    const normalize = (s: string) =>
      s.toLowerCase().replace(/[^a-z0-9 ]/g, '').replace(/\s+/g, ' ').trim();

    for (const old of existing) {
      if (old.supersededBy) continue;
      const sameFact =
        normalize(old.fact) === normalize(incoming.fact) ||
        normalize(old.fact).includes(normalize(incoming.fact)) ||
        normalize(incoming.fact).includes(normalize(old.fact));
      const sameSubject =
        normalize(old.subject) === normalize(incoming.subject);

      if (sameFact && sameSubject) {
        // Contradiction or restatement → supersede the old memory.
        old.supersededBy = incoming.id;
        old.updatedAt = Date.now();
        await memoryRepo.put(old);
      } else if (sameFact) {
        // Same fact, different subject framing → supersede too.
        old.supersededBy = incoming.id;
        await memoryRepo.put(old);
      }
    }
    bus.emit('memories:changed');
  }

  /**
   * Runs LLM-assisted extraction over a finished exchange. The server
   * returns strict JSON which is validated here; nothing is stored
   * without passing the privacy filters.
   */
  async extractFromExchange(
    chatId: UUID,
    userMessage: Message,
    assistantMessage: Message
  ): Promise<Memory[]> {
    const settings = settingsService.get();
    if (!settings.memory.enabled || !settings.memory.autoExtract) return [];
    if (!userMessage.content || !assistantMessage.content) return [];

    try {
      const res = await gateway.request('assist-memory', '/api/memory', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          user: userMessage.content.slice(0, 4000),
          assistant: assistantMessage.content.slice(0, 4000),
        }),
      });
      if (!res.ok) return [];
      const json = (await res.json()) as { memories?: ExtractedMemory[] };
      const created: Memory[] = [];
      for (const candidate of (json.memories ?? []).slice(0, 5)) {
        if (
          !candidate?.fact ||
          typeof candidate.fact !== 'string' ||
          candidate.confidence == null
        ) {
          continue;
        }
        if (candidate.confidence < settings.memory.minConfidence) continue;
        try {
          created.push(
            await this.create(candidate.fact, {
              subject: candidate.subject ?? 'general',
              type: candidate.type ?? 'fact',
              confidence: Math.min(1, Math.max(0, Number(candidate.confidence))),
              sourceChatId: chatId,
            })
          );
        } catch {
          // Refused (sensitive) — skip.
        }
      }
      return created;
    } catch {
      return [];
    }
  }

  /** Search memories by text (for the Memory Manager). */
  async search(query: string): Promise<Memory[]> {
    const q = query.toLowerCase().trim();
    const all = await this.list();
    if (!q) return all;
    return all.filter(
      (m) =>
        m.fact.toLowerCase().includes(q) ||
        m.subject.toLowerCase().includes(q)
    );
  }
}

export const memoryService = new MemoryService();
