import { describe, expect, it } from "vitest";
import { buildContext, estimateTokens } from "./context";
import type { Message } from "./types";
const message = (content: string, createdAt: number): Message => ({ id: String(createdAt), chatId: "c1", role: "user", content, createdAt });
describe("context budget", () => {
  it("never silently truncates an oversized newest message", () => {
    expect(() => buildContext([message("x".repeat(9000), 2)], { maxContextTokens: 512, reserveOutputTokens: 128, systemLayers: [], memories: [] })).toThrow(/too large/i);
  });
  it("keeps newest fitting history and reports omitted messages", () => {
    const messages = Array.from({ length: 20 }, (_, i) => message("turn " + i + " " + "x".repeat(120), i));
    const result = buildContext(messages, { maxContextTokens: 500, reserveOutputTokens: 100, systemLayers: ["policy"], memories: [] });
    expect(result.selected.at(-1)?.id).toBe("19");
    expect(result.omitted.length).toBeGreaterThan(0);
  });
  it("estimates tokens conservatively", () => expect(estimateTokens("12345678")).toBe(2));
});
