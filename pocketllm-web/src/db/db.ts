import Dexie, { type EntityTable } from "dexie";
import type {
  ActivityEntry,
  AppSetting,
  AudioTranscript,
  BrowserModel,
  Chat,
  DocumentChunk,
  DownloadTask,
  ErrorEntry,
  KnowledgeDocument,
  LabRun,
  MemoryRecord,
  Message,
  NetworkAudit,
  Note,
  Persona,
  Prompt,
  Provider,
  Reminder,
  Skill,
  UsageEvent,
} from "../core/types";

class PocketDatabase extends Dexie {
  chats!: EntityTable<Chat, "id">;
  messages!: EntityTable<Message, "id">;
  providers!: EntityTable<Provider, "id">;
  browserModels!: EntityTable<BrowserModel, "id">;
  documents!: EntityTable<KnowledgeDocument, "id">;
  documentChunks!: EntityTable<DocumentChunk, "id">;
  personas!: EntityTable<Persona, "id">;
  prompts!: EntityTable<Prompt, "id">;
  skills!: EntityTable<Skill, "id">;
  memories!: EntityTable<MemoryRecord, "id">;
  notes!: EntityTable<Note, "id">;
  reminders!: EntityTable<Reminder, "id">;
  audioTranscripts!: EntityTable<AudioTranscript, "id">;
  downloads!: EntityTable<DownloadTask, "id">;
  networkAudit!: EntityTable<NetworkAudit, "id">;
  activity!: EntityTable<ActivityEntry, "id">;
  errors!: EntityTable<ErrorEntry, "id">;
  labRuns!: EntityTable<LabRun, "id">;
  usage!: EntityTable<UsageEvent, "id">;
  settings!: EntityTable<AppSetting, "key">;

  constructor() {
    super("pocketllm-web");
    this.version(1).stores({
      chats: "id, updatedAt, createdAt, archived, pinned",
      messages: "id, chatId, createdAt, starred",
      providers: "id, kind, updatedAt",
      documents: "id, createdAt, updatedAt",
      settings: "key",
    });

    this.version(2).stores({
      chats: "id, updatedAt, createdAt, archived, pinned, *tags",
      messages: "id, chatId, parentMessageId, branchRootId, createdAt, starred",
      providers: "id, kind, updatedAt",
      browserModels: "id, runtime, status, installed, updatedAt",
      documents: "id, sha256, createdAt, updatedAt",
      documentChunks: "id, documentId, index",
      personas: "id, updatedAt",
      prompts: "id, updatedAt",
      skills: "id, isEnabled, updatedAt",
      memories: "id, type, subject, pinned, enabled, updatedAt, supersededAt",
      notes: "id, pinned, updatedAt",
      reminders: "id, fireAt, delivered",
      audioTranscripts: "id, createdAt",
      downloads: "id, modelId, state, updatedAt",
      networkAudit: "id, timestamp, scope, allowed, purpose",
      activity: "id, timestamp, kind",
      errors: "id, timestamp, feature",
      labRuns: "id, kind, startedAt",
      usage: "id, kind, timestamp, runtime, model",
      settings: "key",
    }).upgrade(async (tx) => {
      await tx.table("providers").toCollection().modify((provider) => {
        provider.capabilities ??= {
          text: true,
          vision: false,
          embeddings: false,
          tools: false,
          audio: false,
        };
      });
      await tx.table("documents").toCollection().modify((document) => {
        document.sha256 ??= "legacy";
        document.chunkCount ??= 0;
        document.retrievalMode ??= "keyword";
      });
    });
  }
}

export const db = new PocketDatabase();

const defaultSettings: AppSetting[] = [
  { key: "appearance", value: "system" },
  { key: "accent", value: "violet" },
  { key: "strictOffline", value: false },
  { key: "autoMemoryExtraction", value: false },
  { key: "onlineModelBrowsing", value: true },
  { key: "tavilyEnabled", value: false },
  { key: "githubSkillsEnabled", value: false },
  { key: "ragRetrievalMode", value: "hybrid" },
  { key: "ragEmbeddingModel", value: "Xenova/all-MiniLM-L6-v2" },
  { key: "whisperModel", value: "Xenova/whisper-tiny.en" },
  { key: "language", value: "en" },
  { key: "onboardingComplete", value: false },
];

export async function ensureDefaults() {
  await db.transaction("rw", db.settings, db.personas, db.prompts, db.skills, async () => {
    for (const item of defaultSettings) {
      if (!(await db.settings.get(item.key))) await db.settings.put(item);
    }

    if ((await db.personas.count()) === 0) {
      const now = Date.now();
      await db.personas.bulkAdd([
        {
          id: "general",
          name: "General",
          systemPrompt: "Be useful, precise, honest about uncertainty, and concise unless the user asks for depth.",
          temperature: 0.7,
          avatarIcon: "✦",
          createdAt: now,
          updatedAt: now,
        },
        {
          id: "coder",
          name: "Builder",
          systemPrompt: "You are a pragmatic senior software engineer. Prefer correct, maintainable code and explain trade-offs briefly.",
          temperature: 0.25,
          avatarIcon: "⌘",
          createdAt: now,
          updatedAt: now,
        },
      ]);
    }

    if ((await db.prompts.count()) === 0) {
      const now = Date.now();
      await db.prompts.bulkAdd([
        { id: "explain", title: "Explain clearly", content: "Explain this clearly, with one concrete example and no filler.", createdAt: now, updatedAt: now },
        { id: "rewrite", title: "Rewrite", content: "Rewrite the following while preserving meaning and improving clarity:", createdAt: now, updatedAt: now },
      ]);
    }

    if ((await db.skills.count()) === 0) {
      const now = Date.now();
      await db.skills.add({
        id: "webdesign",
        title: "Web Design Expert",
        description: "Design polished, accessible and responsive interfaces.",
        body: "Use clear hierarchy, deliberate typography, responsive layouts, accessibility, and test all interactive states. Avoid generic AI-dashboard aesthetics.",
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      });
    }
  });
}

export async function setting<T>(key: string, fallback: T): Promise<T> {
  const row = await db.settings.get(key);
  return (row?.value as T | undefined) ?? fallback;
}

export async function saveSetting(key: string, value: unknown) {
  await db.settings.put({ key, value });
}

export async function logActivity(kind: string, title: string, detail?: string) {
  await db.activity.add({
    id: crypto.randomUUID(),
    timestamp: Date.now(),
    kind,
    title,
    detail,
  });
}

export async function logError(feature: string, error: unknown, runtime?: string, code?: string) {
  const safeMessage = error instanceof Error ? error.message : String(error);
  await db.errors.add({
    id: crypto.randomUUID(),
    timestamp: Date.now(),
    feature,
    runtime,
    code,
    safeMessage: safeMessage.slice(0, 1000),
    stack: error instanceof Error ? error.stack?.slice(0, 4000) : undefined,
    browser: navigator.userAgent.slice(0, 300),
    appVersion: "web-0.2.0",
  });
}
