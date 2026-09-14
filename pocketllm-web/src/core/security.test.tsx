import { cleanup, render } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { Markdown } from "../components/Markdown";
import { isSensitiveMemory } from "./memory";

afterEach(() => cleanup());

describe("browser security boundaries", () => {
  it("sanitizes rendered assistant markdown", () => {
    const { container } = render(
      <Markdown content={'<img src="x" onerror="window.__pwned=1"><script>window.__pwned=2</script><a href="javascript:alert(1)">bad</a>'} />,
    );
    expect(container.querySelector("script")).toBeNull();
    expect(container.querySelector("img")?.getAttribute("onerror")).toBeNull();
    const href = container.querySelector("a")?.getAttribute("href");
    expect(href === null || href === undefined || !/^javascript:/i.test(href)).toBe(true);
  });

  it("refuses obvious secrets as automatic memory candidates", () => {
    expect(isSensitiveMemory("my password is correct horse battery staple")).toBe(true);
    expect(isSensitiveMemory("api_key = sk-example-secret")).toBe(true);
    expect(isSensitiveMemory("-----BEGIN PRIVATE KEY-----")).toBe(true);
    expect(isSensitiveMemory("I prefer concise technical explanations")).toBe(false);
  });
});
