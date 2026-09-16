/**
 * PocketLLM Lite Web — Domain Types
 * ------------------------------------------------------------------
 * Platform-independent data contracts shared by every layer:
 * repositories, services, runtimes and UI. Modeled directly on the
 * mobile app's data semantics so a future .pllm backup can flow
 * between web and mobile without translation loss.
 */

/* ============================== IDs ============================== */
export type UUID = string;

/* ========================= Generation ============================ */
/** Explicit state machine for a generation run (no boolean soup). */
export type GenerationState =
  | 'idle'
  | 'preparing'
  | 'retrievingMemory'
  | 'retrievingDocuments'
  | 'loadingModel'
  | 'streaming'
  | 'waitingForToolConfirmation'
  | 'runningTool'
  | 'continuingAfterTool'
  | 'finalizing'
  | 'completed'
  | 'cancelled'
  | 'error';

export interface GenerationSettings {
  temperature?: number;
  topP?: number;
  maxTokens?: number;
}

export interface GenerationMetrics {
  ttftMs?: number;
  durationMs?: number;
  tokensIn?: number;
  tokensOut?: number;
  tokensPerSecond?: number;
}

/* =========================== Attachments ========================== */
export interface Attachment {
  id: UUID;
  kind: 'image' | 'file';
  name: string;
  mimeType: string;
  sizeBytes: number;
  /** Object URL (session) — binary itself lives in OPFS when persisted. */
  url?: string;
  /** OPFS path when the attachment is persisted locally. */
  storagePath?: string;
  /** Base64 data URL for images sent to vision-capable runtimes. */
  dataUrl?: string;
}

/* =========================== Citations ============================ */
export interface Citation {
  documentId: UUID;
  documentName: string;
  chunkId: UUID;
  page?: number;
  /** Excerpt of the cited passage for preview panels. */
  excerpt: string;
  score: number;
}

/* ============================ Tool calls ========================== */
export type ToolCallStatus =
  | 'pending'
  | 'awaitingConfirmation'
  | 'confirmed'
  | 'denied'
  | 'running'
  | 'succeeded'
  | 'failed';

export interface ToolEvent {
  id: UUID;
  chatId: UUID;
  messageId: UUID;
  tool: string;
  /** Canonical JSON arguments, schema-validated before execution. */
  args: Record<string, unknown>;
  result?: unknown;
  error?: string;
  status: ToolCallStatus;
  createdAt: number;
}

/* ============================ Messages ============================ */
export type MessageRole = 'user' | 'assistant' | 'system';

export interface Message {
  id: UUID;
  chatId: UUID;
  parentMessageId: UUID | null;
  role: MessageRole;
  content: string;
  createdAt: number;
  updatedAt: number;
  /** Model + runtime that produced an assistant message. */
  modelId?: string;
  runtimeId?: RuntimeId;
  attachments: Attachment[];
  citations: Citation[];
  toolEvents: UUID[];
  starred: boolean;
  error?: string;
  generation?: GenerationSettings;
  metrics?: GenerationMetrics;
  /** Monotonic sequence within the chat. */
  seq: number;
}

/* ============================= Chats ============================== */
export interface Chat {
  id: UUID;
  title: string;
  /** Currently selected model + runtime. */
  modelId: string;
  runtimeId: RuntimeId;
  personaId: UUID | null;
  pinned: boolean;
  archived: boolean;
  tags: UUID[];
  memoryEnabled: boolean;
  /**
   * Knowledge retrieval scope: documents this chat retrieves from.
   * Empty array = global scope (all ready documents). Non-empty =
   * retrieval only searches the listed documents, making "Ask about
   * this document" hand-offs explicit instead of relying on the
   * automatic all-documents retrieval.
   */
  knowledgeDocIds: UUID[];
  /**
   * Per-chat retrieval-mode override. Null/undefined = inherit the
   * global default (`settings.knowledge.defaultRetrievalMode`); a
   * concrete value pins lexical / semantic / hybrid ranking for this
   * chat so a conversation can keep a stable retrieval behaviour
   * while the global setting changes.
   */
  retrievalMode?: RetrievalMode | null;
  /** Composer draft, autosaved while the user types. */
  draft: string;
  createdAt: number;
  updatedAt: number;
  lastMessageAt: number;
  messageCount: number;
}

/**
 * Branch point: when an earlier user message is edited, history is
 * not destructively rewritten — the edit creates a sibling branch.
 */
export interface ChatBranch {
  id: UUID;
  chatId: UUID;
  /** Message whose children diverge. Null when the chat's root message itself is branched. */
  parentMessageId: UUID | null;
  /** Sibling variants of the parent's child message. */
  variants: UUID[];
  activeMessageId: UUID | null;
  label?: string;
  createdAt: number;
}

/* ============================ Personas ============================ */
export interface Persona {
  id: UUID;
  name: string;
  emoji: string;
  instructions: string;
  temperature?: number;
  modelId?: string;
  runtimeId?: RuntimeId;
  createdAt: number;
  updatedAt: number;
}

/* ============================ Prompts ============================= */
export interface Prompt {
  id: UUID;
  title: string;
  body: string;
  /** Optional category tag rendered as a subtle chip. */
  category?: string;
  createdAt: number;
  updatedAt: number;
}

/* ============================ Skills ============================== */
export interface Skill {
  id: UUID;
  name: string;
  description: string;
  /** Prompt injected into composition when the skill is active. */
  instructions: string;
  source: 'local' | 'github';
  sourceUrl?: string;
  enabled: boolean;
  createdAt: number;
  updatedAt: number;
}

/* ============================= Tags =============================== */
export interface Tag {
  id: UUID;
  name: string;
  color: string;
  createdAt: number;
}

/* ============================ Memories ============================ */
export interface Memory {
  id: UUID;
  fact: string;
  subject: string;
  type: 'fact' | 'preference' | 'instruction' | 'context';
  confidence: number;
  sourceChatId?: UUID;
  createdAt: number;
  updatedAt: number;
  lastUsedAt?: number;
  pinned: boolean;
  enabled: boolean;
  sensitive: boolean;
  /** Set when a newer memory supersedes this one. */
  supersededBy?: UUID;
}

/* =========================== Documents ============================ */
export type DocumentStatus =
  | 'importing'
  | 'extracting'
  | 'chunking'
  | 'indexing'
  | 'ready'
  | 'failed';

export type RetrievalMode = 'lexical' | 'semantic' | 'hybrid';

export interface DocumentRecord {
  id: UUID;
  name: string;
  mimeType: string;
  sizeBytes: number;
  sha256: string;
  pageCount: number | null;
  chunkCount: number;
  status: DocumentStatus;
  retrievalMode: RetrievalMode;
  /** OPFS path of the stored source file. */
  storagePath?: string;
  indexSizeBytes: number;
  error?: string;
  createdAt: number;
  indexedAt?: number;
}

export interface DocumentChunk {
  id: UUID;
  documentId: UUID;
  page: number | null;
  seq: number;
  text: string;
  tokens: number;
}

/* =========================== Providers ============================ */
export type RuntimeId = 'assist' | 'ollama' | 'openai' | 'mock';
export type ProviderType = 'ollama' | 'openai-compatible';

export interface ProviderCapabilities {
  text: boolean;
  vision: boolean;
  embeddings: boolean;
  tools: boolean;
}

export interface Provider {
  id: UUID;
  type: ProviderType;
  name: string;
  baseUrl: string;
  modelId: string;
  /** API key — kept in memory only; persisted form is encrypted. */
  apiKey?: string;
  apiKeyStorage: 'session' | 'vault' | 'none';
  capabilities: ProviderCapabilities;
  lastTestedAt?: number;
  lastStatus?: 'connected' | 'unreachable' | 'untested';
  createdAt: number;
  updatedAt: number;
}

/* ============================ Models ============================== */
export type ModelTier = 'tiny' | 'small' | 'medium' | 'custom';
export type ModelRuntime =
  | 'browser-gguf'
  | 'ollama'
  | 'openai-compatible'
  | 'assist';

/** Catalog entry describing a downloadable GGUF model. */
export interface ModelCatalogEntry {
  id: string;
  name: string;
  author: string;
  tier: ModelTier;
  quantization: string;
  paramsClass: string;
  contextLimit: number | null;
  sizeBytes: number;
  license: string;
  repoUrl: string;
  downloadUrl: string;
  sha256?: string;
  /** Capabilities are only marked when verified — unknown stays unknown. */
  capabilities: {
    tools: 'verified' | 'unknown';
    vision: 'verified' | 'unknown';
    embeddings: 'verified' | 'unknown';
  };
  runtimes: ModelRuntime[];
  description: string;
}

/** Installed model manifest (mirrors mobile ModelManifest semantics). */
export interface ModelManifest {
  id: UUID;
  catalogId?: string;
  name: string;
  runtime: ModelRuntime;
  fileName: string;
  sizeBytes: number;
  sha256?: string;
  quantization?: string;
  paramsClass?: string;
  contextLimit: number | null;
  capabilities: {
    tools: 'verified' | 'unknown';
    vision: 'verified' | 'unknown';
    embeddings: 'verified' | 'unknown';
  };
  storagePath?: string;
  verified: boolean;
  downloadedAt: number;
  lastUsedAt?: number;
  /** Set when the file backing this manifest has been removed. */
  deleted?: boolean;
}

/* ========================== Downloads ============================= */
export type DownloadState =
  | 'queued'
  | 'downloading'
  | 'paused'
  | 'verifying'
  | 'installing'
  | 'ready'
  | 'failed'
  | 'cancelled';

export interface DownloadTask {
  id: UUID;
  modelCatalogId: string;
  url: string;
  filename: string;
  state: DownloadState;
  bytesDownloaded: number;
  bytesTotal: number;
  etag?: string;
  lastModified?: string;
  expectedSha256?: string;
  error?: string;
  createdAt: number;
  updatedAt: number;
}

/* ============================ Notes =============================== */
export interface Note {
  id: UUID;
  title: string;
  content: string;
  pinned: boolean;
  /** Set when the note was created by a tool call. */
  createdByTool?: string;
  createdAt: number;
  updatedAt: number;
}

/* ====================== Audio transcripts ========================= */
export interface AudioTranscript {
  id: UUID;
  name: string;
  durationMs: number;
  text: string;
  source: 'recording' | 'upload';
  mimeType: string;
  createdAt: number;
}

/* ============================ Logs ================================ */
export interface NetworkAuditEntry {
  id: UUID;
  ts: number;
  purpose: string;
  destination: string;
  allowed: boolean;
  reason?: string;
  scope: 'loopback' | 'lan' | 'internet';
}

export interface ActivityEntry {
  id: UUID;
  ts: number;
  type:
    | 'chat.created'
    | 'chat.deleted'
    | 'generation.completed'
    | 'generation.cancelled'
    | 'document.indexed'
    | 'model.downloaded'
    | 'model.deleted'
    | 'memory.created'
    | 'memory.deleted'
    | 'backup.exported'
    | 'backup.imported'
    | 'tool.executed';
  label: string;
  meta?: Record<string, string | number>;
}

export interface ErrorEntry {
  id: UUID;
  ts: number;
  feature: string;
  code: string;
  message: string;
  stack?: string;
  appVersion: string;
}

/* ============================= Lab ================================ */
export interface LabRunResult {
  runtimeId: RuntimeId;
  modelId: string;
  content: string;
  metrics?: GenerationMetrics;
  error?: string;
}

export interface LabRun {
  id: UUID;
  kind: 'prompt' | 'comparison' | 'benchmark';
  prompt: string;
  systemPrompt?: string;
  parameters?: GenerationSettings;
  results: LabRunResult[];
  createdAt: number;
}

/* =========================== Settings ============================= */
export interface AppSettings {
  general: {
    displayName: string;
    sendOnEnter: boolean;
    compactMode: boolean;
    reduceMotion: boolean;
  };
  appearance: {
    theme: 'light' | 'dark' | 'system';
    fontSize: 'sm' | 'md' | 'lg';
    accent: 'sandy' | 'amber' | 'rose' | 'mint';
  };
  chat: {
    defaultRuntimeId: RuntimeId;
    defaultModelId: string;
    showTokenCounters: boolean;
    streamingEnabled: boolean;
    autoTitle: boolean;
    maxContextMessages: number;
    /** 'hover' shows timestamps with the action row; 'always' pins them. */
    showTimestamps: 'hover' | 'always';
    /** Offer follow-up question chips after each assistant reply. */
    followUpSuggestions: boolean;
    /** One-time j/k keyboard navigation hint has been dismissed. */
    jkHintDismissed: boolean;
  };
  memory: {
    enabled: boolean;
    autoExtract: boolean;
    maxMemoriesInPrompt: number;
    minConfidence: number;
  };
  knowledge: {
    defaultRetrievalMode: RetrievalMode;
    chunkSize: number;
    topK: number;
  };
  tools: {
    calculator: boolean;
    notes: boolean;
    clipboard: boolean;
    webSearch: boolean;
    draftEmail: boolean;
    openUrl: boolean;
    deviceInfo: boolean;
    webhook: boolean;
    requireConfirmation: boolean;
  };
  privacy: {
    strictOffline: boolean;
    allowLoopback: boolean;
    allowLan: boolean;
    auditNetwork: boolean;
  };
  network: {
    allowedPurposes: string[];
  };
  language: {
    locale: string;
  };
  /** Search-related UI state — saved queries in the History view. */
  search: {
    /** Queries the user bookmarked for one-click re-running (max 8, newest first). */
    savedQueries: string[];
  };
  storage: {
    logRetentionDays: number;
  };
  meta: {
    schemaVersion: number;
    lastActiveChatId?: UUID;
    setupCompleted: boolean;
    onboardingStep?: number;
  };
}

/* ============================ Backup ============================== */
/** Envelope written to `.pllm` files (schema v4, cross-platform). */
export interface BackupEnvelope {
  magic: 'PLLM-BACKUP';
  schemaVersion: 4;
  createdAt: number;
  appVersion: string;
  kdf: {
    algorithm: 'PBKDF2-HMAC-SHA256';
    iterations: number;
    salt: string; // base64
  };
  cipher: {
    algorithm: 'AES-256-GCM';
    iv: string; // base64
  };
  /** base64 ciphertext of the JSON payload. */
  payload: string;
}

export interface BackupPayload {
  schemaVersion: 4;
  exportedAt: number;
  appVersion: string;
  chats: Chat[];
  messages: Message[];
  branches: ChatBranch[];
  personas: Persona[];
  prompts: Prompt[];
  skills: Skill[];
  tags: Tag[];
  notes: Note[];
  memories: Memory[];
  documents: DocumentRecord[];
  chunks?: DocumentChunk[];
  transcripts: AudioTranscript[];
  settings?: AppSettings;
  labRuns: LabRun[];
  /** Saved searches from History (optional — schema v4 archives from
   *  before round 7 lack it; restore merges when present). */
  savedSearches?: string[];
}

/* ======================= Usage statistics ========================= */
export interface UsageDay {
  id: string; // YYYY-MM-DD
  generations: number;
  cancellations: number;
  tokensIn: number;
  tokensOut: number;
  chatsCreated: number;
  documentsIndexed: number;
}
