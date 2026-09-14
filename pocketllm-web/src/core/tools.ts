import { z } from "zod";
import { db, setting } from "../db/db";
import { classifyDestination, networkFetch } from "./network";
import { probeCapabilities } from "./capabilities";
import type { ToolEvent } from "./types";

type ToolDefinition = {
  name: string;
  description: string;
  risk: ToolEvent["risk"];
  requiresConfirmation: boolean;
  schema: z.ZodTypeAny;
  execute: (args: any) => Promise<string>;
};

class ExpressionParser {
  private index = 0;
  constructor(private readonly source: string) {}

  parse() {
    const value = this.expression();
    this.skip();
    if (this.index !== this.source.length || !Number.isFinite(value)) throw new Error("Invalid arithmetic expression.");
    return value;
  }

  private expression(): number {
    let value = this.term();
    while (true) {
      this.skip();
      const char = this.source[this.index];
      if (char !== "+" && char !== "-") break;
      this.index += 1;
      const right = this.term();
      value = char === "+" ? value + right : value - right;
    }
    return value;
  }

  private term(): number {
    let value = this.power();
    while (true) {
      this.skip();
      const char = this.source[this.index];
      if (char !== "*" && char !== "/") break;
      this.index += 1;
      const right = this.power();
      if (char === "/" && right === 0) throw new Error("Division by zero.");
      value = char === "*" ? value * right : value / right;
    }
    return value;
  }

  private power(): number {
    let value = this.unary();
    this.skip();
    if (this.source[this.index] === "^") {
      this.index += 1;
      value = value ** this.power();
    }
    return value;
  }

  private unary(): number {
    this.skip();
    const char = this.source[this.index];
    if (char === "+" || char === "-") {
      this.index += 1;
      const value = this.unary();
      return char === "-" ? -value : value;
    }
    return this.primary();
  }

  private primary(): number {
    this.skip();
    if (this.source[this.index] === "(") {
      this.index += 1;
      const value = this.expression();
      this.skip();
      if (this.source[this.index] !== ")") throw new Error("Missing closing parenthesis.");
      this.index += 1;
      return value;
    }
    const start = this.index;
    while (/[0-9.]/.test(this.source[this.index] ?? "")) this.index += 1;
    const token = this.source.slice(start, this.index);
    if (!token || !/^\d*\.?\d+$/.test(token)) throw new Error("Expected a number.");
    return Number(token);
  }

  private skip() {
    while (/\s/.test(this.source[this.index] ?? "")) this.index += 1;
  }
}

const tools: ToolDefinition[] = [
  {
    name: "calculator",
    description: "Evaluate arithmetic with +, -, *, /, ^ and parentheses.",
    risk: "low",
    requiresConfirmation: false,
    schema: z.object({ expression: z.string().min(1).max(300) }).strict(),
    async execute({ expression }) {
      return String(new ExpressionParser(expression).parse());
    },
  },
  {
    name: "system_info",
    description: "Return browser-exposed runtime capability information.",
    risk: "low",
    requiresConfirmation: false,
    schema: z.object({}).strict(),
    async execute() {
      return JSON.stringify(await probeCapabilities());
    },
  },
  {
    name: "create_note",
    description: "Create a local note in PocketLLM.",
    risk: "medium",
    requiresConfirmation: true,
    schema: z.object({ title: z.string().min(1).max(160), content: z.string().max(20000) }).strict(),
    async execute({ title, content }) {
      const now = Date.now();
      await db.notes.add({ id: crypto.randomUUID(), title, content, pinned: false, createdAt: now, updatedAt: now });
      return "Note created locally.";
    },
  },
  {
    name: "copy_to_clipboard",
    description: "Copy text to the browser clipboard.",
    risk: "medium",
    requiresConfirmation: true,
    schema: z.object({ text: z.string().max(20000) }).strict(),
    async execute({ text }) {
      await navigator.clipboard.writeText(text);
      return "Text copied to clipboard.";
    },
  },
  {
    name: "create_reminder",
    description: "Create a reminder. Browser-closed delivery is not guaranteed.",
    risk: "medium",
    requiresConfirmation: true,
    schema: z.object({ title: z.string().min(1).max(200), fireAt: z.number().int().positive() }).strict(),
    async execute({ title, fireAt }) {
      if (fireAt <= Date.now()) throw new Error("Reminder time must be in the future.");
      await db.reminders.add({ id: crypto.randomUUID(), title, fireAt, delivered: false, createdAt: Date.now() });
      return "Reminder saved. Delivery is reliable while PocketLLM is open; closed-browser delivery is browser-dependent.";
    },
  },
  {
    name: "draft_email",
    description: "Open the user's mail client with a prepared email draft.",
    risk: "medium",
    requiresConfirmation: true,
    schema: z.object({ to: z.string().max(320).optional(), subject: z.string().max(300).optional(), body: z.string().max(10000).optional() }).strict(),
    async execute({ to = "", subject = "", body = "" }) {
      const url = `mailto:${encodeURIComponent(to)}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
      window.location.assign(url);
      return "Email draft opened.";
    },
  },
  {
    name: "open_url",
    description: "Open an HTTP(S) URL in a new browser tab.",
    risk: "high",
    requiresConfirmation: true,
    schema: z.object({ url: z.string().url() }).strict(),
    async execute({ url }) {
      const parsed = new URL(url);
      if (!["http:", "https:"].includes(parsed.protocol)) throw new Error("Only HTTP(S) URLs can be opened.");
      const strict = await setting("strictOffline", false);
      if (strict && classifyDestination(url) !== "loopback") throw new Error("Strict Offline blocks opening this network URL.");
      window.open(url, "_blank", "noopener,noreferrer");
      return "URL opened.";
    },
  },
  {
    name: "web_search",
    description: "Search the web using Tavily when explicitly enabled.",
    risk: "high",
    requiresConfirmation: true,
    schema: z.object({ query: z.string().min(2).max(500) }).strict(),
    async execute({ query }) {
      if (!(await setting("tavilyEnabled", false))) throw new Error("Tavily web search is disabled.");
      const key = sessionStorage.getItem("tavily-key");
      if (!key) throw new Error("Tavily API key is not configured for this session.");
      const response = await networkFetch("https://api.tavily.com/search", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ api_key: key, query, search_depth: "basic", max_results: 5 }),
      }, "web-search");
      if (!response.ok) throw new Error(`Tavily returned HTTP ${response.status}`);
      const data = await response.json() as { results?: Array<{ title?: string; url?: string; content?: string }> };
      return (data.results ?? []).map((item, index) => `[${index + 1}] ${item.title ?? "Result"}\n${item.url ?? ""}\n${item.content ?? ""}`).join("\n\n");
    },
  },
  {
    name: "send_webhook",
    description: "Send an outbound HTTP webhook. Inbound webhooks are not available from a normal browser app.",
    risk: "high",
    requiresConfirmation: true,
    schema: z.object({
      url: z.string().url(),
      method: z.enum(["POST", "PUT", "PATCH"]).default("POST"),
      headers: z.record(z.string()).optional(),
      body: z.unknown().optional(),
    }).strict(),
    async execute({ url, method, headers = {}, body }) {
      const response = await networkFetch(url, {
        method,
        headers: { "Content-Type": "application/json", ...headers },
        body: body === undefined ? undefined : JSON.stringify(body),
      }, "webhook");
      const text = await response.text();
      if (!response.ok) throw new Error(`Webhook returned HTTP ${response.status}: ${text.slice(0, 300)}`);
      return text.slice(0, 3000) || `Webhook completed with HTTP ${response.status}`;
    },
  },
];

export function toolDefinitionsForPrompt() {
  return tools.map((tool) => ({
    name: tool.name,
    description: tool.description,
    risk: tool.risk,
    requiresConfirmation: tool.requiresConfirmation,
  }));
}

export function toolSystemPrompt() {
  const definitions = toolDefinitionsForPrompt().map((tool) => `- ${tool.name}: ${tool.description}`).join("\n");
  return `When a tool is required, output exactly one XML-style call and no prose before it:
<tool_call name="tool_name" args='{"key":"value"}' />
Available tools:
${definitions}
Never invent tool names or arguments.`;
}

export function parseToolCall(text: string) {
  const match = text.match(/<tool_call\s+name=["']([^"']+)["']\s+args=(["'])([\s\S]*?)\2\s*\/>/i);
  if (!match) return null;
  const name = match[1];
  let args: unknown;
  try {
    args = JSON.parse(match[3]);
  } catch {
    throw new Error("Tool call arguments were not valid JSON.");
  }
  const tool = tools.find((item) => item.name === name);
  if (!tool) throw new Error(`Unknown tool: ${name}`);
  const parsed = tool.schema.parse(args);
  return { tool, args: parsed as Record<string, unknown>, raw: match[0] };
}

export async function executeTool(name: string, args: Record<string, unknown>) {
  const tool = tools.find((item) => item.name === name);
  if (!tool) throw new Error(`Unknown tool: ${name}`);
  const parsed = tool.schema.parse(args);
  return tool.execute(parsed);
}

export function startReminderLoop() {
  let timer = 0;
  const tick = async () => {
    const due = (await db.reminders.filter((item) => !item.delivered).toArray()).filter((item) => item.fireAt <= Date.now());
    for (const reminder of due) {
      if ("Notification" in window) {
        if (Notification.permission === "default") await Notification.requestPermission().catch(() => undefined);
        if (Notification.permission === "granted") new Notification("PocketLLM reminder", { body: reminder.title });
      }
      await db.reminders.update(reminder.id, { delivered: true });
    }
  };
  void tick();
  timer = window.setInterval(() => void tick(), 30_000);
  return () => window.clearInterval(timer);
}
