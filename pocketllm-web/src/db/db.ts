import Dexie, { type EntityTable } from "dexie";
import type { AppSetting, Chat, KnowledgeDocument, Message, Provider } from "../core/types";

class PocketDatabase extends Dexie {
  chats!: EntityTable<Chat, "id">;
  messages!: EntityTable<Message, "id">;
  providers!: EntityTable<Provider, "id">;
  documents!: EntityTable<KnowledgeDocument, "id">;
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
  }
}

export const db = new PocketDatabase();

export async function ensureDefaults() {
  const appearance = await db.settings.get("appearance");
  if (!appearance) await db.settings.put({ key: "appearance", value: "system" });

  const strictOffline = await db.settings.get("strictOffline");
  if (!strictOffline) await db.settings.put({ key: "strictOffline", value: false });
}
