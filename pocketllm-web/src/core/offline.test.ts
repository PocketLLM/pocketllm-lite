import { afterEach, describe, expect, it, vi } from "vitest";
import { db, saveSetting } from "../db/db";
import { networkFetch } from "./network";

describe("Strict Offline enforcement", () => {
  afterEach(async () => {
    vi.restoreAllMocks();
    await saveSetting("strictOffline", false);
    await db.networkAudit.clear();
  });

  it("blocks internet before fetch is called and records the block", async () => {
    await saveSetting("strictOffline", true);
    const fetchSpy = vi.spyOn(globalThis, "fetch");

    await expect(networkFetch("https://example.com/private", {}, "external-resource"))
      .rejects.toThrow(/Strict Offline/i);

    expect(fetchSpy).not.toHaveBeenCalled();
    const audit = await db.networkAudit.orderBy("timestamp").last();
    expect(audit?.allowed).toBe(false);
    expect(audit?.scope).toBe("internet");
    expect(audit?.destination).toBe("https://example.com");
  });

  it("still permits loopback while Strict Offline is enabled", async () => {
    await saveSetting("strictOffline", true);
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response("ok", { status: 200 }));

    const response = await networkFetch("http://127.0.0.1:11434/api/tags", {}, "ollama-loopback");

    expect(response.ok).toBe(true);
    expect(fetchSpy).toHaveBeenCalledOnce();
  });
});
