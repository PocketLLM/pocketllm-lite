/**
 * UtilityTasks — one-shot helper completions (chat titles, prompt
 * enhancement, follow-up questions, memory extraction).
 *
 * These run on a runtime the USER connected (Ollama or an
 * OpenAI-compatible endpoint) through the same InferenceRouter and
 * NetworkGateway as chat, so Strict Offline, auditing and cancellation
 * behave identically. There is no hosted fallback: when no model is
 * connected every task throws UtilityUnavailableError and callers fall
 * back to a local, honestly-labelled behaviour.
 */
import { inferenceRouter } from '@/lib/services/inference/inference-router';
import type { RuntimeId } from '@/lib/types/domain';

/** Thrown when no real model is connected (or the policy blocks it). */
export class UtilityUnavailableError extends Error {
  constructor(message = 'Connect a model in Providers to use this feature.') {
    super(message);
    this.name = 'UtilityUnavailableError';
  }
}

export interface UtilityMemoryCandidate {
  fact: string;
  subject: string;
  type: 'fact' | 'preference' | 'instruction' | 'context';
  confidence: number;
}

interface CompleteOptions {
  runtimeId?: RuntimeId;
  /** Used only when the picked runtime is the same as `runtimeId`. */
  modelId?: string;
  maxTokens: number;
  signal?: AbortSignal;
}

/** Runs a single system+user completion and returns the trimmed text. */
async function complete(system: string, user: string, opts: CompleteOptions): Promise<string> {
  const runtimeId = await inferenceRouter.pickUtilityRuntime(opts.runtimeId);
  if (!runtimeId) throw new UtilityUnavailableError();
  try {
    const result = await inferenceRouter.generate(
      runtimeId,
      [
        { role: 'system', content: system },
        { role: 'user', content: user },
      ],
      {
        modelId: runtimeId === opts.runtimeId ? opts.modelId : undefined,
        settings: { temperature: 0.3, maxTokens: opts.maxTokens },
        signal: opts.signal,
      }
    );
    return result.content.trim();
  } catch (err) {
    // Blocked by Strict Offline / unreachable endpoint: not an error the
    // user needs to see for a background helper.
    if (err instanceof Error && err.name === 'RuntimeUnavailableError') {
      throw new UtilityUnavailableError(err.message);
    }
    throw err;
  }
}

/** Strips <think>…</think> blocks some reasoning models emit. */
function stripThinking(text: string): string {
  return text.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();
}

class UtilityTasks {
  /** 2–5 word chat title from the first user message. */
  async generateTitle(message: string, runtimeId?: RuntimeId, modelId?: string): Promise<string> {
    const raw = stripThinking(
      await complete(
        'Generate a 2-5 word title for a chat that starts with the message below. Use the same language as the message. Title Case. Output ONLY the title — no quotes, no punctuation at the end.',
        message.slice(0, 600),
        { runtimeId, modelId, maxTokens: 24 }
      )
    );
    const firstLine = raw.split('\n').find((l) => l.trim()) ?? '';
    return firstLine
      .trim()
      .replace(/^["'«»“”]+|["'«»“”.]+$/g, '')
      .slice(0, 80);
  }

  /** Rewrites a rough prompt into a clear, self-contained instruction. */
  async enhancePrompt(prompt: string, runtimeId?: RuntimeId, modelId?: string): Promise<string> {
    const out = stripThinking(
      await complete(
        "You are a prompt-enhancement assistant. Rewrite the user's rough prompt into a single, clear, self-contained instruction for an AI assistant. Preserve the user's intent and language. Keep it under 120 words. Output ONLY the improved prompt — no preamble, no quotes, no explanation.",
        prompt.slice(0, 4000),
        { runtimeId, modelId, maxTokens: 320 }
      )
    );
    return out.replace(/^["“]|["”]$/g, '').trim();
  }

  /** Three short follow-up questions for an exchange. */
  async suggestFollowUps(user: string, assistant: string, runtimeId?: RuntimeId): Promise<string[]> {
    const content = stripThinking(
      await complete(
        'You propose follow-up questions for a chat between a user and an AI assistant. ' +
          'Read the exchange and suggest exactly THREE distinct, natural follow-up questions the user might ask next. ' +
          'Rules: each question under 9 words; no numbering, no quotes, no explanation; ' +
          'they must relate to the actual topic; vary the angle (go deeper, apply it, challenge it). ' +
          'Output ONLY a JSON array of three strings, e.g. ["How does X work?","Can you show an example?","What are the risks?"]',
        `User asked: ${user.slice(0, 1500) || '(empty)'}\n\nAssistant replied: ${assistant.slice(0, 2500) || '(empty)'}`,
        { runtimeId, maxTokens: 120 }
      )
    );
    const match = /\[[\s\S]*\]/.exec(content);
    if (!match) throw new Error('Model returned no suggestion list');
    const parsed: unknown = JSON.parse(match[0]);
    const suggestions = Array.isArray(parsed)
      ? parsed
          .filter((s): s is string => typeof s === 'string')
          .map((s) => s.trim())
          .filter(Boolean)
          .slice(0, 3)
      : [];
    if (suggestions.length === 0) throw new Error('No usable suggestions');
    return suggestions;
  }

  /**
   * Extracts candidate long-term memories from a finished exchange.
   * Output is validated field-by-field; callers still apply the privacy
   * filters before anything is stored.
   */
  async extractMemories(
    user: string,
    assistant: string,
    runtimeId?: RuntimeId
  ): Promise<UtilityMemoryCandidate[]> {
    const content = stripThinking(
      await complete(
        `You extract long-term memories about the USER from a conversation exchange. Rules:
- Only durable facts worth remembering across future chats (name, preferences, projects, constraints, goals).
- NEVER store secrets: API keys, passwords, tokens, card numbers, addresses — skip them entirely.
- Each memory: fact (one sentence), subject (topic key like "name", "coffee preference"), type (fact|preference|instruction|context), confidence (0.0-1.0).
- Max 3 memories. Skip trivial small talk.
Respond with ONLY a JSON array: [{"fact": "...", "subject": "...", "type": "...", "confidence": 0.9}]. Empty array [] if nothing is worth remembering.`,
        `USER SAID:\n${user.slice(0, 4000)}\n\nASSISTANT REPLIED:\n${assistant.slice(0, 4000)}`,
        { runtimeId, maxTokens: 400 }
      )
    );
    const match = /\[[\s\S]*\]/.exec(content.replace(/```json\s*|```/g, ''));
    if (!match) return [];
    let parsed: unknown;
    try {
      parsed = JSON.parse(match[0]);
    } catch {
      return [];
    }
    if (!Array.isArray(parsed)) return [];
    const types = ['fact', 'preference', 'instruction', 'context'] as const;
    return parsed
      .filter(
        (m): m is UtilityMemoryCandidate =>
          !!m &&
          typeof m.fact === 'string' &&
          m.fact.length > 3 &&
          typeof m.confidence === 'number'
      )
      .slice(0, 5)
      .map((m) => ({
        fact: String(m.fact).slice(0, 400),
        subject: String(m.subject ?? 'general').slice(0, 100),
        type: types.includes(m.type) ? m.type : 'fact',
        confidence: Math.min(1, Math.max(0, Number(m.confidence) || 0.5)),
      }));
  }
}

export const utilityTasks = new UtilityTasks();
