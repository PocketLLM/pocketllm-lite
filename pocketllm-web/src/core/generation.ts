import { db, logActivity, logError } from "../db/db";
import { buildContext, estimateTokens, summarizeLocally } from "./context";
import { citationsAsContext, retrieve } from "./rag";
import { extractHeuristicMemories, relevantMemories } from "./memory";
import { runtimeFromChatSelection, type RuntimeMessage } from "./runtime";
import { executeTool, parseToolCall, toolSystemPrompt } from "./tools";
import type { Chat, Citation, GenerationMetrics, GenerationState, Message, ToolEvent } from "./types";

export interface GenerationCallbacks {
  onState?: (state: GenerationState) => void;
  onToken?: (fullText: string) => void;
}

export interface PendingTool {
  event: ToolEvent;
  assistantContent: string;
}

export interface GenerationResult {
  content: string;
  citations: Citation[];
  toolEvents: ToolEvent[];
  pendingTool?: PendingTool;
  metrics: GenerationMetrics;
}

function attachmentText(message: Message) {
  const text = message.attachments?.filter((item) => item.text).map((item) => `\n\n[Attachment: ${item.name}]\n${item.text}`).join("") ?? "";
  return `${message.content}${text}`;
}

function runtimeMessages(messages: Message[], systemText: string): RuntimeMessage[] {
  return [
    ...(systemText ? [{ role: "system" as const, content: systemText }] : []),
    ...messages
      .filter((item) => item.role === "user" || item.role === "assistant")
      .map((item) => ({
        role: item.role as "user" | "assistant",
        content: attachmentText(item),
        images: item.attachments?.filter((attachment) => attachment.imageDataUrl).map((attachment) => attachment.imageDataUrl!) ?? [],
      })),
  ];
}

async function compose(chat: Chat, messages: Message[], onState?: (state: GenerationState) => void) {
  const latestUser = [...messages].reverse().find((message) => message.role === "user");
  const query = latestUser?.content ?? "";

  const [persona, prompt, skills, runtime] = await Promise.all([
    chat.personaId ? db.personas.get(chat.personaId) : undefined,
    chat.promptId ? db.prompts.get(chat.promptId) : undefined,
    db.skills.where("isEnabled").equals(1).toArray(),
    runtimeFromChatSelection(chat.providerId, chat.browserModelId),
  ]);

  let memories = [] as Awaited<ReturnType<typeof relevantMemories>>;
  if (chat.memoryEnabled !== false && !chat.noMemory && query) {
    onState?.("retrievingMemory");
    memories = await relevantMemories(query).catch(() => []);
  }

  let citations: Citation[] = [];
  if (chat.ragEnabled && query) {
    onState?.("retrievingDocuments");
    const mode = (await db.settings.get("ragRetrievalMode"))?.value as "keyword" | "semantic" | "hybrid" | undefined;
    citations = await retrieve(query, chat.selectedDocumentIds ?? [], mode ?? "hybrid").catch(async () => {
      return retrieve(query, chat.selectedDocumentIds ?? [], "keyword");
    });
  }

  const systemLayers = [
    "You are PocketLLM, a local-first assistant. Be useful and accurate. If context is missing, say so rather than fabricating.",
    persona?.systemPrompt ?? "",
    prompt?.content ?? "",
    skills.length ? `Enabled skills:\n${skills.map((skill) => `### ${skill.title}\n${skill.body}`).join("\n\n")}` : "",
    chat.toolsEnabled ? toolSystemPrompt() : "",
  ].filter(Boolean);

  const contextLimit = chat.browserModelId
    ? (await db.browserModels.get(chat.browserModelId))?.contextLimit ?? 4096
    : 8192;
  const reserve = Math.min(chat.maxTokens ?? 800, Math.floor(contextLimit * 0.3));
  const documentContext = citationsAsContext(citations);
  const built = buildContext(messages, {
    maxContextTokens: contextLimit,
    reserveOutputTokens: reserve,
    systemLayers,
    memories,
    documentContext,
    previousSummary: chat.rollingSummary,
  });

  if (built.omitted.length >= 4) {
    const summary = summarizeLocally(built.omitted);
    if (summary && summary !== chat.rollingSummary) {
      await db.chats.update(chat.id, { rollingSummary: summary, updatedAt: Date.now() });
    }
  }

  return { built, citations, runtime, persona };
}

async function streamOnce(
  chat: Chat,
  messages: Message[],
  callbacks: GenerationCallbacks,
  signal: AbortSignal,
) {
  callbacks.onState?.("preparing");
  const { built, citations, runtime, persona } = await compose(chat, messages, callbacks.onState);
  callbacks.onState?.("loadingModel");
  const metrics: GenerationMetrics = {
    startedAt: Date.now(),
    inputCharacters: built.selected.reduce((sum, item) => sum + item.content.length, 0) + built.systemText.length,
    outputCharacters: 0,
    estimatedInputTokens: estimateTokens(built.systemText) + built.selected.reduce((sum, item) => sum + estimateTokens(item.content), 0),
  };
  let content = "";
  callbacks.onState?.("streaming");
  await runtime.generate({
    messages: runtimeMessages(built.selected, built.systemText),
    signal,
    maxTokens: chat.maxTokens ?? 800,
    temperature: chat.temperature ?? persona?.temperature ?? 0.7,
    topP: chat.topP ?? 0.9,
    topK: chat.topK ?? 40,
    onToken(token) {
      if (!metrics.firstTokenAt) metrics.firstTokenAt = Date.now();
      content += token;
      metrics.outputCharacters = content.length;
      callbacks.onToken?.(content);
    },
  });
  metrics.completedAt = Date.now();
  metrics.estimatedOutputTokens = estimateTokens(content);
  return { content, citations, metrics, runtime };
}

export async function generateWithPipeline(
  chat: Chat,
  messages: Message[],
  callbacks: GenerationCallbacks,
  signal: AbortSignal,
): Promise<GenerationResult> {
  const toolEvents: ToolEvent[] = [];
  let working = [...messages];
  let finalCitations: Citation[] = [];
  let metrics: GenerationMetrics = {
    startedAt: Date.now(),
    inputCharacters: 0,
    outputCharacters: 0,
  };

  try {
    for (let round = 0; round < 5; round += 1) {
      const streamed = await streamOnce(chat, working, callbacks, signal);
      let content = streamed.content;
      finalCitations = streamed.citations;
      metrics = streamed.metrics;

      if (!chat.toolsEnabled) {
        callbacks.onState?.("finalizing");
        return { content, citations: finalCitations, toolEvents, metrics };
      }

      let parsed: ReturnType<typeof parseToolCall>;
      try {
        parsed = parseToolCall(content);
      } catch (error) {
        callbacks.onState?.("finalizing");
        return { content: `${content}\n\n[Tool call rejected: ${error instanceof Error ? error.message : "invalid tool call"}]`, citations: finalCitations, toolEvents, metrics };
      }
      if (!parsed) {
        callbacks.onState?.("finalizing");
        return { content, citations: finalCitations, toolEvents, metrics };
      }

      const now = Date.now();
      const event: ToolEvent = {
        id: crypto.randomUUID(),
        name: parsed.tool.name,
        arguments: parsed.args,
        state: parsed.tool.requiresConfirmation ? "pending" : "running",
        risk: parsed.tool.risk,
        createdAt: now,
        updatedAt: now,
      };
      toolEvents.push(event);

      if (parsed.tool.requiresConfirmation) {
        callbacks.onState?.("waitingForToolConfirmation");
        return {
          content,
          citations: finalCitations,
          toolEvents,
          pendingTool: { event, assistantContent: content },
          metrics,
        };
      }

      callbacks.onState?.("runningTool");
      try {
        const result = await executeTool(event.name, event.arguments);
        event.state = "completed";
        event.result = result;
        event.updatedAt = Date.now();
        callbacks.onState?.("continuingAfterTool");
        working = [
          ...working,
          {
            id: crypto.randomUUID(),
            chatId: chat.id,
            role: "assistant",
            content,
            createdAt: Date.now(),
          },
          {
            id: crypto.randomUUID(),
            chatId: chat.id,
            role: "user",
            content: `Tool result for ${event.name}:\n${result}\nContinue the answer. Do not repeat the tool call.`,
            createdAt: Date.now() + 1,
          },
        ];
        callbacks.onToken?.("");
      } catch (error) {
        event.state = "failed";
        event.error = error instanceof Error ? error.message : String(error);
        event.updatedAt = Date.now();
        content += `\n\n[Tool failed: ${event.error}]`;
        return { content, citations: finalCitations, toolEvents, metrics };
      }
    }
    throw new Error("Tool loop limit reached.");
  } catch (error) {
    await logError("generation-pipeline", error);
    throw error;
  }
}

export async function approveToolAndContinue(
  chat: Chat,
  history: Message[],
  pending: PendingTool,
  callbacks: GenerationCallbacks,
  signal: AbortSignal,
) {
  callbacks.onState?.("runningTool");
  const event = { ...pending.event, state: "running" as const, updatedAt: Date.now() };
  const result = await executeTool(event.name, event.arguments);
  const completed: ToolEvent = { ...event, state: "completed", result, updatedAt: Date.now() };
  callbacks.onState?.("continuingAfterTool");
  const synthetic: Message[] = [
    ...history,
    {
      id: crypto.randomUUID(),
      chatId: chat.id,
      role: "assistant",
      content: pending.assistantContent,
      createdAt: Date.now(),
      toolEvents: [completed],
    },
    {
      id: crypto.randomUUID(),
      chatId: chat.id,
      role: "user",
      content: `Tool result for ${completed.name}:\n${result}\nContinue the answer using this result.`,
      createdAt: Date.now() + 1,
    },
  ];
  const streamed = await streamOnce(chat, synthetic, callbacks, signal);
  return { ...streamed, toolEvent: completed };
}

export async function recordGenerationUsage(chat: Chat, model: string, runtime: Message["runtime"]) {
  await db.usage.add({
    id: crypto.randomUUID(),
    kind: "generation",
    timestamp: Date.now(),
    runtime,
    model,
    count: 1,
  });
  await logActivity("generation", "Response generated", model);
}

export async function maybeExtractMemories(message: Message) {
  if (message.role !== "user") return;
  await extractHeuristicMemories(message.content, message.id).catch(() => undefined);
}
