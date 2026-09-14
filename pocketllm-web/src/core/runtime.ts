import type { Provider } from "./types";

export interface GenerateRequest {
  provider: Provider;
  apiKey?: string;
  messages: Array<{ role: "system" | "user" | "assistant"; content: string }>;
  signal: AbortSignal;
  onToken: (token: string) => void;
}

export interface Runtime {
  id: string;
  generate(req: GenerateRequest): Promise<void>;
  test(provider: Provider, apiKey?: string): Promise<string[]>;
}

async function consumeSse(
  response: Response,
  pick: (payload: unknown) => string | undefined,
  onToken: (token: string) => void,
  signal: AbortSignal,
) {
  if (!response.ok) {
    const body = await response.text().catch(() => "");
    throw new Error(body || `Request failed with HTTP ${response.status}`);
  }
  if (!response.body) throw new Error("Streaming response had no body.");

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  while (true) {
    if (signal.aborted) throw new DOMException("Aborted", "AbortError");
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });

    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";
    for (const raw of lines) {
      const line = raw.trim();
      if (!line || !line.startsWith("data:")) continue;
      const data = line.slice(5).trim();
      if (data === "[DONE]") return;
      try {
        const token = pick(JSON.parse(data));
        if (token) onToken(token);
      } catch {
        // Ignore malformed partial event lines; the next event remains parseable.
      }
    }
  }
}

export const openAICompatibleRuntime: Runtime = {
  id: "openai-compatible",
  async generate({ provider, apiKey, messages, signal, onToken }) {
    const url = `${provider.baseUrl.replace(/\/$/, "")}/chat/completions`;
    const response = await fetch(url, {
      method: "POST",
      signal,
      headers: {
        "Content-Type": "application/json",
        ...(apiKey ? { Authorization: `Bearer ${apiKey}` } : {}),
      },
      body: JSON.stringify({
        model: provider.model,
        stream: true,
        messages,
      }),
    });

    await consumeSse(
      response,
      (payload) => {
        const p = payload as { choices?: Array<{ delta?: { content?: string } }> };
        return p.choices?.[0]?.delta?.content;
      },
      onToken,
      signal,
    );
  },
  async test(provider, apiKey) {
    const response = await fetch(`${provider.baseUrl.replace(/\/$/, "")}/models`, {
      headers: apiKey ? { Authorization: `Bearer ${apiKey}` } : undefined,
    });
    if (!response.ok) throw new Error(`Provider returned HTTP ${response.status}`);
    const data = (await response.json()) as { data?: Array<{ id?: string }> };
    return (data.data ?? []).flatMap((item) => (item.id ? [item.id] : []));
  },
};

export const ollamaRuntime: Runtime = {
  id: "ollama",
  async generate({ provider, messages, signal, onToken }) {
    const response = await fetch(`${provider.baseUrl.replace(/\/$/, "")}/api/chat`, {
      method: "POST",
      signal,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model: provider.model, stream: true, messages }),
    });

    if (!response.ok) {
      const body = await response.text().catch(() => "");
      throw new Error(body || `Ollama returned HTTP ${response.status}`);
    }
    if (!response.body) throw new Error("Ollama streaming response had no body.");

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    while (true) {
      if (signal.aborted) throw new DOMException("Aborted", "AbortError");
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";
      for (const line of lines) {
        if (!line.trim()) continue;
        const event = JSON.parse(line) as { message?: { content?: string }; done?: boolean };
        if (event.message?.content) onToken(event.message.content);
        if (event.done) return;
      }
    }
  },
  async test(provider) {
    const response = await fetch(`${provider.baseUrl.replace(/\/$/, "")}/api/tags`);
    if (!response.ok) throw new Error(`Ollama returned HTTP ${response.status}`);
    const data = (await response.json()) as { models?: Array<{ name?: string }> };
    return (data.models ?? []).flatMap((item) => (item.name ? [item.name] : []));
  },
};

export function runtimeFor(provider: Provider): Runtime {
  return provider.kind === "ollama" ? ollamaRuntime : openAICompatibleRuntime;
}
