import { describe, expect, it } from "vitest";
import { classifyDestination } from "./network";
describe("network destination classification", () => {
  it("classifies loopback", () => {
    expect(classifyDestination("http://127.0.0.1:11434/api/tags")).toBe("loopback");
    expect(classifyDestination("http://localhost:11434")).toBe("loopback");
  });
  it("classifies private LAN", () => {
    expect(classifyDestination("http://192.168.1.20:11434")).toBe("lan");
    expect(classifyDestination("http://10.0.0.9")).toBe("lan");
    expect(classifyDestination("http://my-pc.local")).toBe("lan");
  });
  it("classifies public destinations as internet", () => expect(classifyDestination("https://huggingface.co/api/models")).toBe("internet"));
});
