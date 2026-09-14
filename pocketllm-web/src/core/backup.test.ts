import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { decryptBackup } from "./backup";

describe("mobile/web backup compatibility fixture", () => {
  const fixture = fs.readFileSync(path.resolve(process.cwd(), "../fixtures/backups/mobile-v3-fixture.pllm"), "utf8");
  const webV4Fixture = fs.readFileSync(path.resolve(process.cwd(), "../fixtures/backups/web-v4-fixture.pllm"), "utf8");

  it("decrypts the canonical mobile schema-3 envelope", async () => {
    const payload = await decryptBackup(fixture, "fixture-password");
    expect(payload.schemaVersion).toBe(3);
    expect(payload.chats[0].id).toBe("fixture-chat-1");
    expect(payload.chats[0].messages[0].content).toBe("hello from mobile fixture");
    expect(payload.memories[0].fact).toBe("Prefers concise answers");
    expect(payload.personas[0].id).toBe("fixture-persona");
    expect(payload.documentIndex["fixture-doc"].name).toBe("fixture.md");
  });

  it("accepts the canonical web schema-4 envelope", async () => {
    const payload = await decryptBackup(webV4Fixture, "fixture-web-v4");
    expect(payload.schemaVersion).toBe(4);
    expect(payload.chats[0].id).toBe("web-chat-1");
    expect(payload.web.messages[0].content).toBe("hello from web fixture");
  });

  it("rejects an incorrect password", async () => {
    await expect(decryptBackup(fixture, "wrong-password")).rejects.toThrow(/incorrect password|corrupted/i);
  });
});
