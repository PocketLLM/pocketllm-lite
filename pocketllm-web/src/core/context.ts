import type { MemoryRecord, Message } from "./types";

export function estimateTokens(text: string) {
  return Math.ceil(text.length / 4);
}

export function buildContext(
  messages: Message[],
  options: {
    maxContextTokens: number;
    reserveOutputTokens: number;
    systemLayers: string[];
    memories: MemoryRecord[];
    documentContext?: string;
    previousSummary?: string;
  },
) {
  const systemText = options.systemLayers.filter(Boolean).join("\n\n");
  const memoryText = options.memories.length
    ? `Relevant user memories:\n${options.memories.map((item) => `- ${item.fact}`).join("\n")}`
    : "";
  const fixed = [systemText, memoryText, options.documentContext, options.previousSummary ? `Earlier conversation summary:\n${options.previousSummary}` : ""].filter(Boolean).join("\n\n");
  const budget = Math.max(256, options.maxContextTokens - options.reserveOutputTokens - estimateTokens(fixed));

  const newest = messages.at(-1);
  if (newest && estimateTokens(newest.content) > budget) {
    throw new Error("This message is too large for the selected model context. Shorten it or use a model with a larger context window.");
  }

  const selected: Message[] = [];
  let used = 0;
  for (let index = messages.length - 1; index >= 0; index -= 1) {
    const item = messages[index];
    const cost = estimateTokens(item.content) + 8;
    if (used + cost > budget && selected.length) break;
    if (used + cost <= budget) {
      selected.unshift(item);
      used += cost;
    }
  }

  const omitted = messages.slice(0, Math.max(0, messages.length - selected.length));
  return {
    systemText: fixed,
    selected,
    omitted,
    breakdown: {
      maxContextTokens: options.maxContextTokens,
      reservedOutputTokens: options.reserveOutputTokens,
      fixedTokens: estimateTokens(fixed),
      recentChatTokens: used,
      omittedMessages: omitted.length,
    },
  };
}

export function summarizeLocally(messages: Message[]) {
  const meaningful = messages.filter((message) => message.role === "user" || message.role === "assistant").slice(-18);
  if (!meaningful.length) return "";
  return meaningful
    .map((message) => `${message.role === "user" ? "User" : "Assistant"}: ${message.content.replace(/\s+/g, " ").slice(0, 260)}`)
    .join("\n")
    .slice(0, 5000);
}
