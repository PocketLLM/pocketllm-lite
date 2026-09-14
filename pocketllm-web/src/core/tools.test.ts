import { describe, expect, it } from "vitest";
import { executeTool, parseToolCall } from "./tools";
describe("tool calling", () => {
  it("evaluates arithmetic without eval", async () => {
    await expect(executeTool("calculator", { expression: "2 + 3 * (4 ^ 2)" })).resolves.toBe("50");
  });
  it("rejects extra schema arguments", async () => {
    await expect(executeTool("calculator", { expression: "2+2", injected: "nope" })).rejects.toThrow();
  });
  it("parses canonical tool calls", () => {
    const parsed = parseToolCall("<tool_call name=\"calculator\" args='{\"expression\":\"7*6\"}' />");
    expect(parsed?.tool.name).toBe("calculator");
  });
  it("rejects unknown tools", () => {
    expect(() => parseToolCall("<tool_call name=\"shell\" args='{}' />")).toThrow(/Unknown tool/);
  });
});
