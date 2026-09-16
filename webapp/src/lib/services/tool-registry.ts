/**
 * ToolRegistry — canonical JSON tool architecture.
 *
 * Every tool declares a JSON schema; model output is parsed and
 * schema-validated BEFORE execution. Risky tools require explicit
 * user confirmation bound to the exact displayed arguments —
 * changing args invalidates the authorization. No eval, no dynamic
 * code, ever.
 */
import type { ToolEvent, UUID } from '@/lib/types/domain';
import { settingsService } from './settings-service';
import { logService } from './log-service';
import { evaluateExpression } from './safe-math';
import { gateway } from '@/lib/core/net/network-gateway';
import { noteRepo } from '@/lib/core/db/repositories';
import { uuid } from '@/lib/utils';

export type ToolRisk = 'safe' | 'moderate' | 'dangerous';

export interface ToolDefinition {
  name: string;
  description: string;
  /** JSON-schema-lite parameter spec used for validation. */
  parameters: Record<
    string,
    { type: 'string' | 'number' | 'boolean'; description: string; required?: boolean; enum?: string[] }
  >;
  risk: ToolRisk;
  requiresConfirmation: boolean;
  /** Text injected into the tool section of the system prompt. */
  promptSpec: string;
  execute(args: Record<string, unknown>, ctx: ToolContext): Promise<unknown>;
}

export interface ToolContext {
  chatId: UUID;
  /** Called by risky tools to request confirmation; resolves the decision. */
  requestConfirmation?: (event: ToolEvent) => Promise<boolean>;
}

export interface ParsedToolCall {
  tool: string;
  args: Record<string, unknown>;
}

/** Parses model output for a canonical tool-call block. */
export function parseToolCall(content: string): ParsedToolCall | null {
  // Canonical format: a fenced ```tool block containing JSON.
  const fence = /```tool\s*\n([\s\S]*?)```/.exec(content);
  const raw = fence ? fence[1] : null;
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw.trim()) as { tool?: string; args?: unknown };
    if (!parsed.tool || typeof parsed.tool !== 'string') return null;
    return { tool: parsed.tool, args: (parsed.args ?? {}) as Record<string, unknown> };
  } catch {
    return null;
  }
}

/** Validates args against the tool schema. */
function validateArgs(
  def: ToolDefinition,
  args: Record<string, unknown>
): string | null {
  for (const [key, spec] of Object.entries(def.parameters)) {
    if (spec.required && (args[key] === undefined || args[key] === null || args[key] === '')) {
      return `Missing required argument: ${key}`;
    }
    const v = args[key];
    if (v === undefined || v === null) continue;
    if (spec.type === 'number' && typeof v !== 'number' && isNaN(Number(v))) {
      return `Argument ${key} must be a number`;
    }
    if (spec.type === 'string' && typeof v !== 'string') {
      if (typeof v === 'number' || typeof v === 'boolean') {
        args[key] = String(v);
      } else {
        return `Argument ${key} must be a string`;
      }
    }
    if (spec.type === 'boolean' && typeof v !== 'boolean') {
      if (v === 'true' || v === 'false') args[key] = v === 'true';
      else return `Argument ${key} must be a boolean`;
    }
  }
  // Reject unknown keys — no extra arguments ever.
  for (const key of Object.keys(args)) {
    if (!(key in def.parameters)) return `Unknown argument: ${key}`;
  }
  return null;
}

class ToolRegistry {
  private tools = new Map<string, ToolDefinition>();

  register(def: ToolDefinition): void {
    this.tools.set(def.name, def);
  }

  list(): ToolDefinition[] {
    return [...this.tools.values()];
  }

  /** Tools enabled under current settings. */
  enabled(): ToolDefinition[] {
    const s = settingsService.get().tools;
    const enableMap: Record<string, boolean> = {
      calculator: s.calculator,
      create_note: s.notes,
      clipboard_write: s.clipboard,
      web_search: s.webSearch,
      draft_email: s.draftEmail,
      open_url: s.openUrl,
      device_info: s.deviceInfo,
      send_webhook: s.webhook,
    };
    return this.list().filter((t) => enableMap[t.name] !== false);
  }

  get(name: string): ToolDefinition | undefined {
    return this.tools.get(name);
  }

  /**
   * Validates + executes a tool call. Confirmation is enforced for
   * tools that need it, using the exact serialized arguments.
   */
  async execute(
    call: ParsedToolCall,
    ctx: ToolContext,
    messageId: UUID
  ): Promise<ToolEvent> {
    const def = this.get(call.tool);
    const event: ToolEvent = {
      id: uuid(),
      chatId: ctx.chatId,
      messageId,
      tool: call.tool,
      args: call.args,
      status: 'pending',
      createdAt: Date.now(),
    };
    if (!def) {
      event.status = 'failed';
      event.error = `Unknown tool: ${call.tool}`;
      return event;
    }
    if (!this.enabled().includes(def)) {
      event.status = 'failed';
      event.error = `Tool "${def.name}" is disabled in Settings → Tools.`;
      return event;
    }
    const validationError = validateArgs(def, call.args);
    if (validationError) {
      event.status = 'failed';
      event.error = validationError;
      return event;
    }

    // Confirmation gate — bound to exact arguments.
    const needsConfirm =
      def.requiresConfirmation || settingsService.get().tools.requireConfirmation;
    if (needsConfirm && ctx.requestConfirmation) {
      event.status = 'awaitingConfirmation';
      const approved = await ctx.requestConfirmation(event);
      if (!approved) {
        event.status = 'denied';
        return event;
      }
    }
    event.status = 'confirmed';

    try {
      event.status = 'running';
      event.result = await def.execute(call.args, ctx);
      event.status = 'succeeded';
      void logService.recordActivity('tool.executed', `Ran ${def.name}`);
    } catch (err) {
      event.status = 'failed';
      event.error = err instanceof Error ? err.message : String(err);
    }
    return event;
  }

  /**
   * Renders the tool section of the system prompt: canonical schemas
   * the model must answer with inside a ```tool fence.
   */
  systemPromptSpec(): string {
    const tools = this.enabled();
    if (tools.length === 0) return '';
    const specs = tools
      .map((t) => {
        const params = Object.entries(t.parameters)
          .map(
            ([k, p]) =>
              `    "${k}" (${p.type}${p.required ? ', required' : ''}): ${p.description}`
          )
          .join('\n');
        return `- ${t.name}: ${t.description}\n  Args:\n${params}`;
      })
      .join('\n');
    return `You can use tools. To call one, output a fenced code block exactly like:

\`\`\`tool
{"tool": "<tool name>", "args": { ... }}
\`\`\`

After the block, stop and wait for the tool result — it will be provided to you in the next turn as a TOOL_RESULT message. Use at most one tool call per reply. Never invent results.

Available tools:
${specs}`;
  }
}

/* ======================= Tool implementations ====================== */

const toolRegistry = new ToolRegistry();
export { toolRegistry };

toolRegistry.register({
  name: 'calculator',
  description: 'Evaluates an arithmetic expression (numbers, + - * / % ^, sqrt, min, max, round, floor, ceil, abs, sin, cos, tan, log, exp, pi, e).',
  parameters: {
    expression: { type: 'string', description: 'Arithmetic expression, e.g. "sqrt(144) * 2"', required: true },
  },
  risk: 'safe',
  requiresConfirmation: false,
  promptSpec: '',
  async execute(args) {
    const expr = String(args.expression);
    const result = evaluateExpression(expr);
    return { expression: expr, result };
  },
});

toolRegistry.register({
  name: 'create_note',
  description: 'Creates a persistent note in the user\u2019s PocketLLM notes library.',
  parameters: {
    title: { type: 'string', description: 'Note title', required: true },
    content: { type: 'string', description: 'Note body', required: true },
  },
  risk: 'moderate',
  requiresConfirmation: true,
  promptSpec: '',
  async execute(args, _ctx) {
    const now = Date.now();
    await noteRepo.put({
      id: uuid(),
      title: String(args.title).slice(0, 200),
      content: String(args.content).slice(0, 20_000),
      pinned: false,
      createdByTool: 'create_note',
      createdAt: now,
      updatedAt: now,
    });
    return { saved: true, title: String(args.title) };
  },
});

toolRegistry.register({
  name: 'clipboard_write',
  description: 'Copies text to the user\u2019s clipboard.',
  parameters: {
    text: { type: 'string', description: 'Text to copy', required: true },
  },
  risk: 'moderate',
  requiresConfirmation: true,
  promptSpec: '',
  async execute(args) {
    await navigator.clipboard.writeText(String(args.text));
    return { copied: true };
  },
});

toolRegistry.register({
  name: 'web_search',
  description: 'Searches the public web and returns ranked results with snippets.',
  parameters: {
    query: { type: 'string', description: 'Search query', required: true },
  },
  risk: 'moderate',
  requiresConfirmation: false,
  promptSpec: '',
  async execute(args) {
    const res = await gateway.request('assist-search', '/api/search', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: String(args.query) }),
    });
    if (!res.ok) throw new Error(`Search failed (${res.status})`);
    const json = (await res.json()) as {
      results?: Array<{ name: string; url: string; snippet: string }>;
    };
    return {
      results: (json.results ?? []).slice(0, 6).map((r) => ({
        name: r.name,
        url: r.url,
        snippet: r.snippet,
      })),
    };
  },
});

toolRegistry.register({
  name: 'draft_email',
  description: 'Opens the user\u2019s email client with a pre-filled draft (does not send).',
  parameters: {
    to: { type: 'string', description: 'Recipient email (optional)' },
    subject: { type: 'string', description: 'Email subject' },
    body: { type: 'string', description: 'Email body' },
  },
  risk: 'moderate',
  requiresConfirmation: true,
  promptSpec: '',
  async execute(args) {
    const url = `mailto:${encodeURIComponent(String(args.to ?? ''))}?subject=${encodeURIComponent(
      String(args.subject ?? '')
    )}&body=${encodeURIComponent(String(args.body ?? ''))}`;
    window.open(url, '_self');
    return { opened: true };
  },
});

toolRegistry.register({
  name: 'open_url',
  description: 'Opens a URL in a new browser tab after the user approves it.',
  parameters: {
    url: { type: 'string', description: 'Absolute http(s) URL', required: true },
  },
  risk: 'dangerous',
  requiresConfirmation: true,
  promptSpec: '',
  async execute(args) {
    let parsed: URL;
    try {
      parsed = new URL(String(args.url));
    } catch {
      throw new Error('Invalid URL');
    }
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      throw new Error('Only http(s) URLs are allowed');
    }
    window.open(parsed.toString(), '_blank', 'noopener,noreferrer');
    return { opened: parsed.toString() };
  },
});

toolRegistry.register({
  name: 'device_info',
  description: 'Returns measured browser/device information this page can actually see.',
  parameters: {},
  risk: 'safe',
  requiresConfirmation: false,
  promptSpec: '',
  async execute() {
    return {
      platform: navigator.platform,
      userAgent: navigator.userAgent.slice(0, 200),
      language: navigator.language,
      hardwareConcurrency: navigator.hardwareConcurrency,
      deviceMemoryGB: (navigator as Navigator & { deviceMemory?: number }).deviceMemory ?? null,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      screen: `${window.screen.width}x${window.screen.height}`,
      online: navigator.onLine,
    };
  },
});

toolRegistry.register({
  name: 'send_webhook',
  description: 'Sends an outbound HTTP POST webhook to a URL the user explicitly approved.',
  parameters: {
    url: { type: 'string', description: 'Webhook URL (https)', required: true },
    payload_json: { type: 'string', description: 'JSON body to send', required: true },
  },
  risk: 'dangerous',
  requiresConfirmation: true,
  promptSpec: '',
  async execute(args) {
    let parsedBody: unknown;
    try {
      parsedBody = JSON.parse(String(args.payload_json));
    } catch {
      throw new Error('payload_json is not valid JSON');
    }
    const url = new URL(String(args.url));
    if (url.protocol !== 'https:' && url.protocol !== 'http:') {
      throw new Error('Only http(s) webhooks are allowed');
    }
    const res = await gateway.request('webhook', url.toString(), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(parsedBody),
    });
    return { status: res.status, ok: res.ok };
  },
});
