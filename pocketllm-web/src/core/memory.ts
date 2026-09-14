import { db, setting } from "../db/db";
import type { MemoryRecord, MemoryType } from "./types";
import { cosine, embedText } from "./embeddings";

const sensitivePatterns = [
  /\b(password|passphrase|api[_ -]?key|access[_ -]?token|private[_ -]?key|secret)\b/i,
  /\b(?:\d[ -]*?){13,19}\b/,
  /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
  /\b(bank account|routing number|social security|ssn)\b/i,
];

export function isSensitiveMemory(text: string) {
  return sensitivePatterns.some((pattern) => pattern.test(text));
}

function normalize(text: string) {
  return text.toLowerCase().replace(/\s+/g, " ").trim();
}

export async function saveMemory(input: Omit<MemoryRecord, "updatedAt"> & { updatedAt?: number }) {
  if (!input.fact.trim() || isSensitiveMemory(input.fact)) return false;
  const now = Date.now();
  const embedding = input.embedding ?? await embedText(input.fact).catch(() => undefined);
  const candidate: MemoryRecord = { ...input, embedding, updatedAt: input.updatedAt ?? now };
  const existing = await db.memories.where("subject").equals(input.subject).toArray();
  const duplicate = existing.find((item) =>
    !item.supersededAt &&
    item.type === input.type &&
    (
      normalize(item.fact) === normalize(input.fact) ||
      (item.embedding && embedding && cosine(item.embedding, embedding) >= 0.94) ||
      (item.memoryKey && input.memoryKey && item.memoryKey === input.memoryKey)
    ),
  );

  if (duplicate) {
    await db.memories.update(duplicate.id, {
      fact: input.fact,
      confidence: Math.max(duplicate.confidence, input.confidence),
      embedding,
      updatedAt: now,
      enabled: true,
    });
    return true;
  }

  const sameKey = input.memoryKey
    ? existing.find((item) => !item.supersededAt && item.memoryKey === input.memoryKey && item.id !== input.id)
    : undefined;
  if (sameKey) {
    await db.memories.update(sameKey.id, {
      enabled: false,
      supersededAt: now,
      supersededById: input.id,
      updatedAt: now,
    });
  }

  await db.memories.put(candidate);
  return true;
}

export async function extractHeuristicMemories(text: string, sourceMessageId?: string) {
  if (!(await setting("autoMemoryExtraction", false))) return [];
  const patterns: Array<{ type: MemoryType; key: string; regex: RegExp }> = [
    { type: "personalFact", key: "name", regex: /\bmy name is ([^.!?\n]{2,60})/i },
    { type: "preference", key: "preference", regex: /\bi (?:really )?(?:prefer|like|love) ([^.!?\n]{2,120})/i },
    { type: "goal", key: "goal", regex: /\bmy goal is (?:to )?([^.!?\n]{2,160})/i },
    { type: "project", key: "project", regex: /\bi(?:'m| am) (?:building|working on) ([^.!?\n]{2,160})/i },
  ];
  const saved: MemoryRecord[] = [];
  for (const pattern of patterns) {
    const match = text.match(pattern.regex);
    if (!match?.[1]) continue;
    const fact = match[0].trim();
    if (isSensitiveMemory(fact)) continue;
    const now = Date.now();
    const memory: MemoryRecord = {
      id: crypto.randomUUID(),
      type: pattern.type,
      subject: "user",
      fact,
      confidence: 0.82,
      sourceMessageId,
      sensitive: false,
      pinned: false,
      enabled: true,
      createdAt: now,
      updatedAt: now,
      memoryKey: pattern.key,
    };
    if (await saveMemory(memory)) saved.push(memory);
  }
  return saved;
}

export async function relevantMemories(query: string, limit = 6) {
  const records = (await db.memories.toArray()).filter((item) => item.enabled && !item.supersededAt && !item.sensitive);
  if (!records.length) return [];
  const queryEmbedding = await embedText(query).catch(() => []);
  return records
    .map((record) => ({
      record,
      score: record.pinned ? 1.1 : queryEmbedding.length && record.embedding ? cosine(queryEmbedding, record.embedding) : normalize(query).includes(normalize(record.subject)) ? 0.5 : 0.1,
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map((item) => item.record);
}
