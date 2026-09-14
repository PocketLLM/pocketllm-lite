import Dexie from "dexie";
import { afterEach, describe, expect, it } from "vitest";
import { PocketDatabase } from "./db";

const created: string[] = [];

afterEach(async () => {
  for (const name of created.splice(0)) {
    await Dexie.delete(name);
  }
});

describe("IndexedDB migrations", () => {
  it("upgrades legacy provider and document records without losing data", async () => {
    const name = `pocketllm-migration-${crypto.randomUUID()}`;
    created.push(name);

    const legacy = new Dexie(name);
    legacy.version(1).stores({
      chats: "id, updatedAt, createdAt, archived, pinned",
      messages: "id, chatId, createdAt, starred",
      providers: "id, kind, updatedAt",
      documents: "id, createdAt, updatedAt",
      settings: "key",
    });
    await legacy.open();
    const now = Date.now();
    await legacy.table("providers").add({
      id: "legacy-provider",
      name: "Legacy Ollama",
      kind: "ollama",
      baseUrl: "http://127.0.0.1:11434",
      model: "qwen",
      createdAt: now,
      updatedAt: now,
    });
    await legacy.table("documents").add({
      id: "legacy-document",
      name: "legacy.txt",
      mimeType: "text/plain",
      size: 5,
      text: "hello",
      createdAt: now,
      updatedAt: now,
    });
    legacy.close();

    const migrated = new PocketDatabase(name);
    await migrated.open();

    const provider = await migrated.providers.get("legacy-provider");
    expect(provider?.name).toBe("Legacy Ollama");
    expect(provider?.capabilities).toEqual({
      text: true,
      vision: false,
      embeddings: false,
      tools: false,
      audio: false,
    });

    const document = await migrated.documents.get("legacy-document");
    expect(document?.text).toBe("hello");
    expect(document?.sha256).toBe("legacy");
    expect(document?.chunkCount).toBe(0);
    expect(document?.retrievalMode).toBe("keyword");

    migrated.close();
  });
});
