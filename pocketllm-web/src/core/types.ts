export type ProviderKind = "ollama" | "openai-compatible";
export type RuntimeKind = ProviderKind | "wllama" | "chrome-ai";
export type MemoryType =
  | "personalFact"
  | "preference"
  | "project"
  | "people"
  | "goal"
  | "writingStyle"
  | "reusableInstruction";

export interface RuntimeCapabilities {
  text: boolean;
  vision: boolean;
  embeddings: boolean;
  tools: boolean;
  audio: boolean;
}

export interface AttachmentRef {
  id: string;
  name: string;
  mimeType: string;
  size: number;
  opfsPath?: string;
  text?: string;
  imageDataUrl?: string;
}

export interface Citation {
  id: string;
  documentId: string;
  documentName: string;
  chunkId: string;
  page?: number;
  excerpt: string;
  score: number;
}

export interface ToolEvent {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
  state: "pending" | "approved" | "denied" | "running" | "completed" | "failed";
  risk: "low" | "medium" | "high";
  result?: string;
  error?: string;
  createdAt: number;
  updatedAt: number;
}

export interface GenerationMetrics {
  startedAt: number;
  firstTokenAt?: number;
  completedAt?: number;
  inputCharacters: number;
  outputCharacters: number;
  estimatedInputTokens?: number;
  estimatedOutputTokens?: number;
}

export interface Chat {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
  archived: boolean;
  pinned: boolean;
  draft?: string;
  providerId?: string;
  browserModelId?: string;
  personaId?: string;
  promptId?: string;
  tags?: string[];
  ragEnabled?: boolean;
  selectedDocumentIds?: string[];
  toolsEnabled?: boolean;
  memoryEnabled?: boolean;
  noMemory?: boolean;
  temperature?: number;
  topP?: number;
  topK?: number;
  maxTokens?: number;
  rollingSummary?: string;
}

export interface Message {
  id: string;
  chatId: string;
  parentMessageId?: string;
  branchRootId?: string;
  role: "user" | "assistant" | "system" | "tool";
  content: string;
  createdAt: number;
  updatedAt?: number;
  starred?: boolean;
  model?: string;
  runtime?: RuntimeKind;
  attachments?: AttachmentRef[];
  citations?: Citation[];
  toolEvents?: ToolEvent[];
  generation?: GenerationMetrics;
}

export interface Provider {
  id: string;
  name: string;
  kind: ProviderKind;
  baseUrl: string;
  model: string;
  capabilities: RuntimeCapabilities;
  rememberSecret?: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface BrowserModel {
  id: string;
  name: string;
  runtime: "wllama" | "chrome-ai";
  source: "huggingface" | "url" | "file" | "built-in";
  sourceUrl?: string;
  hfRepo?: string;
  hfFile?: string;
  opfsPath?: string;
  sha256?: string;
  size?: number;
  quantization?: string;
  parameterClass?: string;
  contextLimit?: number;
  license?: string;
  capabilities: RuntimeCapabilities;
  installed: boolean;
  status: "available" | "queued" | "downloading" | "verifying" | "ready" | "failed";
  createdAt: number;
  updatedAt: number;
  lastUsedAt?: number;
}

export interface Persona {
  id: string;
  name: string;
  systemPrompt: string;
  temperature: number;
  avatarIcon: string;
  modelId?: string;
  createdAt: number;
  updatedAt: number;
}

export interface Prompt {
  id: string;
  title: string;
  content: string;
  createdAt: number;
  updatedAt: number;
}

export interface Skill {
  id: string;
  title: string;
  description: string;
  body: string;
  githubUrl?: string;
  isEnabled: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface MemoryRecord {
  id: string;
  type: MemoryType;
  subject: string;
  fact: string;
  confidence: number;
  sourceMessageId?: string;
  sensitive: boolean;
  pinned: boolean;
  enabled: boolean;
  createdAt: number;
  updatedAt: number;
  lastUsedAt?: number;
  embedding?: number[];
  memoryKey?: string;
  supersededAt?: number;
  supersededById?: string;
}

export interface KnowledgeDocument {
  id: string;
  name: string;
  mimeType: string;
  size: number;
  sha256: string;
  opfsPath?: string;
  text: string;
  pageCount?: number;
  chunkCount: number;
  retrievalMode: "keyword" | "semantic" | "hybrid";
  embeddingModel?: string;
  indexedAt?: number;
  createdAt: number;
  updatedAt: number;
}

export interface DocumentChunk {
  id: string;
  documentId: string;
  index: number;
  content: string;
  page?: number;
  startOffset?: number;
  endOffset?: number;
  embedding?: number[];
  metadata?: Record<string, unknown>;
}

export interface Note {
  id: string;
  title: string;
  content: string;
  pinned: boolean;
  createdAt: number;
  updatedAt: number;
}

export interface Reminder {
  id: string;
  title: string;
  fireAt: number;
  delivered: boolean;
  createdAt: number;
}

export interface AudioTranscript {
  id: string;
  name: string;
  text: string;
  language?: string;
  durationSeconds?: number;
  model: string;
  createdAt: number;
}

export interface DownloadTask {
  id: string;
  modelId: string;
  url: string;
  fileName: string;
  opfsPath: string;
  state: "queued" | "downloading" | "paused" | "verifying" | "installing" | "ready" | "failed" | "cancelled";
  downloadedBytes: number;
  expectedBytes?: number;
  etag?: string;
  lastModified?: string;
  sha256?: string;
  error?: string;
  createdAt: number;
  updatedAt: number;
}

export interface NetworkAudit {
  id: string;
  timestamp: number;
  destination: string;
  scope: "loopback" | "lan" | "internet";
  purpose: string;
  allowed: boolean;
  blockReason?: string;
}

export interface ActivityEntry {
  id: string;
  timestamp: number;
  kind: string;
  title: string;
  detail?: string;
}

export interface ErrorEntry {
  id: string;
  timestamp: number;
  feature: string;
  runtime?: string;
  code?: string;
  safeMessage: string;
  stack?: string;
}

export interface LabRun {
  id: string;
  kind: "prompt" | "compare" | "benchmark";
  prompt: string;
  model: string;
  runtime: RuntimeKind;
  output: string;
  startedAt: number;
  completedAt: number;
  firstTokenAt?: number;
  outputCharacters: number;
  estimatedTokens?: number;
}

export interface UsageEvent {
  id: string;
  kind: "generation" | "document-indexed" | "model-used" | "tool-call";
  timestamp: number;
  runtime?: RuntimeKind;
  model?: string;
  count?: number;
}

export interface AppSetting {
  key: string;
  value: unknown;
}

export type GenerationState =
  | "idle"
  | "preparing"
  | "retrievingMemory"
  | "retrievingDocuments"
  | "loadingModel"
  | "streaming"
  | "waitingForToolConfirmation"
  | "runningTool"
  | "continuingAfterTool"
  | "finalizing"
  | "completed"
  | "cancelled"
  | "error";

export interface CapabilityReport {
  webgpu: boolean;
  wasm: boolean;
  crossOriginIsolated: boolean;
  sharedArrayBuffer: boolean;
  hardwareConcurrency: number;
  storageQuota?: number;
  storageUsage?: number;
  persistentStorage: boolean;
  chromeAI: "available" | "downloading" | "downloadable" | "unavailable" | "unknown";
  microphone: boolean;
  speechRecognition: boolean;
  notifications: boolean;
}
