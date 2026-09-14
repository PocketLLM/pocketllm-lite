export type ProviderKind = "ollama" | "openai-compatible";

export interface Chat {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
  archived: boolean;
  pinned: boolean;
  draft?: string;
  providerId?: string;
}

export interface Message {
  id: string;
  chatId: string;
  parentMessageId?: string;
  role: "user" | "assistant" | "system" | "tool";
  content: string;
  createdAt: number;
  starred?: boolean;
  model?: string;
  runtime?: string;
}

export interface Provider {
  id: string;
  name: string;
  kind: ProviderKind;
  baseUrl: string;
  model: string;
  createdAt: number;
  updatedAt: number;
}

export interface KnowledgeDocument {
  id: string;
  name: string;
  mimeType: string;
  size: number;
  text: string;
  createdAt: number;
  updatedAt: number;
}

export interface AppSetting {
  key: string;
  value: unknown;
}

export type GenerationState =
  | "idle"
  | "preparing"
  | "streaming"
  | "completed"
  | "cancelled"
  | "error";
