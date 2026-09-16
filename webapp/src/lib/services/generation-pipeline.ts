/**
 * GenerationPipeline — the explicit streaming state machine.
 *
 *   idle → preparing → retrievingMemory → retrievingDocuments →
 *   loadingModel → streaming → (waitingForToolConfirmation →
 *   runningTool → continuingAfterTool)* → finalizing → completed
 *
 * Cancellation propagates UI → pipeline → runtime → fetch.
 * Tool calls are parsed, schema-validated and confirmed before any
 * execution. Streaming deltas are published in-memory for instant UI
 * updates while IndexedDB receives throttled snapshots.
 */
import { bus } from '@/lib/core/events/event-bus';
import { inferenceRouter } from './inference/inference-router';
import { AbortedError, type ChatTurn } from './inference/runtime';
import { chatService } from './chat-service';
import { memoryService } from './memory-service';
import {
  messageRepo,
  personaRepo,
  skillRepo,
  toolEventRepo,
} from '@/lib/core/db/repositories';
import { promptComposer } from './prompt-composer';
import { retrievalService } from './retrieval-service';
import { toolRegistry, parseToolCall } from './tool-registry';
import { logService } from './log-service';
import { settingsService } from './settings-service';
import type {
  Chat,
  GenerationState,
  Message,
  ToolEvent,
  UUID,
} from '@/lib/types/domain';
import { uuid } from '@/lib/utils';

export interface PipelineStatus {
  state: GenerationState;
  /** Human-readable status line ("Retrieving documents…"). */
  message: string;
  chatId: UUID | null;
}

export interface StreamFrame {
  chatId: UUID;
  messageId: UUID;
  content: string;
}

export interface SendOptions {
  chatId: UUID;
  content: string;
  attachments?: Message['attachments'];
  /** Edit path: branch from this message instead of appending. */
  branchFromMessageId?: UUID;
  /** Regeneration: reuse this user message and replace the reply. */
  regenerateAfterMessageId?: UUID;
}

const MAX_TOOL_ROUNDS = 3;

class GenerationPipeline {
  private abortController: AbortController | null = null;
  private currentChatId: UUID | null = null;
  private statusListeners = new Set<(s: PipelineStatus) => void>();
  private streamListeners = new Set<(f: StreamFrame) => void>();
  private confirmationResolver: ((approved: boolean) => void) | null = null;

  status: PipelineStatus = { state: 'idle', message: '', chatId: null };
  pendingToolEvent: ToolEvent | null = null;

  isStreaming(): boolean {
    return !['idle', 'completed', 'cancelled', 'error'].includes(this.status.state);
  }

  onStatus(fn: (s: PipelineStatus) => void): () => void {
    this.statusListeners.add(fn);
    return () => this.statusListeners.delete(fn);
  }

  onStream(fn: (f: StreamFrame) => void): () => void {
    this.streamListeners.add(fn);
    return () => this.streamListeners.delete(fn);
  }

  private setState(state: GenerationState, message = ''): void {
    this.status = { state, message, chatId: this.currentChatId };
    for (const fn of this.statusListeners) fn(this.status);
  }

  /** Stop button — available from the moment generation starts. */
  stop(): void {
    this.abortController?.abort();
    if (this.confirmationResolver) {
      this.confirmationResolver(false);
      this.confirmationResolver = null;
    }
  }

  /** Resolves a pending tool confirmation from the UI. */
  resolveToolConfirmation(approved: boolean): void {
    this.confirmationResolver?.(approved);
    this.confirmationResolver = null;
  }

  /* ------------------------------------------------------------------ */

  /**
   * Full send flow: persist user message, compose context, stream the
   * reply, run the tool loop, persist the assistant message.
   */
  async send(opts: SendOptions): Promise<void> {
    if (this.isStreaming()) return;
    this.abortController = new AbortController();
    this.currentChatId = opts.chatId;

    try {
      this.setState('preparing', 'Preparing…');
      const chat = await chatService.getChat(opts.chatId);
      if (!chat) throw new Error('Chat not found');

      // ----- 1. Persist the user message (or branch) -----
      let userMessage: Message;
      if (opts.branchFromMessageId) {
        const original = await messageRepo.get(opts.branchFromMessageId);
        if (!original) throw new Error('Message not found');
        // Branches attach at the original's parent; null means the
        // original is the chat root, which is a valid branch point.
        userMessage = await chatService.createBranch(
          chat.id,
          original.parentMessageId,
          {
            role: 'user',
            content: opts.content,
            starred: false,
            attachments: opts.attachments ?? [],
            citations: [],
            toolEvents: [],
          }
        );
      } else if (opts.regenerateAfterMessageId) {
        const existing = await messageRepo.get(opts.regenerateAfterMessageId);
        if (!existing) throw new Error('Message not found');
        userMessage = existing;
      } else {
        userMessage = await chatService.appendMessage({
          id: uuid(),
          chatId: chat.id,
          parentMessageId: null,
          role: 'user',
          content: opts.content,
          starred: false,
          attachments: opts.attachments ?? [],
          citations: [],
          toolEvents: [],
        });
      }

      // ----- 2. Compose context layers -----
      this.setState('retrievingMemory', 'Retrieving memory…');
      const memories = chat.memoryEnabled ? await memoryService.active() : [];
      if (memories.length) {
        void memoryService.markUsed(memories.map((m) => m.id));
      }

      this.setState('retrievingDocuments', 'Retrieving documents…');
      // Per-chat knowledge scope: when the chat lists specific documents,
      // retrieval searches only those; empty/undefined = all ready docs.
      // Per-chat retrieval-mode override: a pinned mode replaces the
      // global default for this chat's ranking strategy.
      const scope = chat.knowledgeDocIds && chat.knowledgeDocIds.length > 0
        ? { documentIds: chat.knowledgeDocIds }
        : undefined;
      const retrieved = await retrievalService.retrieve(opts.content, {
        ...scope,
        mode: chat.retrievalMode ?? undefined,
      });
      const documentContext = retrieved.map((c) => ({
        name: c.documentName,
        excerpt: c.text.slice(0, 1200),
      }));

      const persona = chat.personaId
        ? ((await personaRepo.get(chat.personaId)) ?? null)
        : null;
      const skills = (await skillRepo.getAll()).filter((s) => s.enabled);

      const systemPrompt = promptComposer.compose({
        persona,
        skills,
        memories,
        documentContext,
      });
      const toolSpec = toolRegistry.systemPromptSpec();

      // ----- 3. History turns -----
      const history = await chatService.visibleMessages(chat.id);
      const trimmed = history.slice(-settingsService.get().chat.maxContextMessages);
      const turns: ChatTurn[] = [
        {
          role: 'system',
          content: toolSpec ? `${systemPrompt}\n\n${toolSpec}` : systemPrompt,
        },
        ...trimmed.map((m) => ({ role: m.role, content: m.content })),
      ];
      // Images from this message go to the vision-capable runtimes.
      const images = (opts.attachments ?? userMessage.attachments)
        .filter((a) => a.kind === 'image' && a.dataUrl)
        .map((a) => a.dataUrl!);
      if (images.length && turns.length > 1) {
        turns[turns.length - 1].images = images;
      }

      // ----- 4. Generation + tool loop -----
      let assistantMessage: Message | null = null;
      let toolRounds = 0;
      let finalContent = '';

      for (;;) {
        this.setState('loadingModel', 'Loading model…');

        // Ensure an assistant message shell exists before streaming so
        // stream frames can reference a stable message id.
        if (!assistantMessage) {
          assistantMessage = await chatService.appendMessage({
            id: uuid(),
            chatId: chat.id,
            parentMessageId: userMessage.id,
            role: 'assistant',
            content: '',
            starred: false,
            attachments: [],
            citations: retrievalService.toCitations(retrieved),
            toolEvents: [],
            modelId: chat.modelId,
            runtimeId: chat.runtimeId,
          });
        }
        const shell = assistantMessage;

        const result = await this.streamTurn(chat, turns, shell.id, async (partial) => {
          await chatService.updateMessage(shell.id, { content: partial });
        });

        const content = result.content;

        // ----- 5. Tool-call detection -----
        const call = parseToolCall(content);
        if (call && toolRounds < MAX_TOOL_ROUNDS) {
          toolRounds++;
          await chatService.updateMessage(shell.id, { content });

          const toolEvent = await toolRegistry.execute(
            call,
            {
              chatId: chat.id,
              requestConfirmation: async (event) => {
                this.pendingToolEvent = event;
                this.setState(
                  'waitingForToolConfirmation',
                  `PocketLLM wants to run ${event.tool}`
                );
                const approved = await new Promise<boolean>((resolve) => {
                  this.confirmationResolver = resolve;
                });
                this.pendingToolEvent = null;
                return approved;
              },
            },
            shell.id
          );

          await toolEventRepo.put(toolEvent);
          shell.toolEvents.push(toolEvent.id);
          await chatService.updateMessage(shell.id, {
            toolEvents: shell.toolEvents,
          });
          bus.emit('toolEvents:changed');

          if (toolEvent.status === 'denied') {
            finalContent = `${content}\n\n*(The user declined this tool call.)*`;
            await chatService.updateMessage(shell.id, {
              content: finalContent,
            });
            break;
          }

          this.setState('runningTool', `Running ${call.tool}…`);
          this.setState('continuingAfterTool', 'Continuing…');
          turns.push({ role: 'assistant', content });
          turns.push({
            role: 'user',
            content: `TOOL_RESULT for ${call.tool} (status: ${toolEvent.status}):\n${JSON.stringify(
              toolEvent.result ?? { error: toolEvent.error },
              null,
              2
            )}\n\nContinue your reply to the user using this result. Do not emit another tool block for the same task.`,
          });
          assistantMessage = null;
          continue;
        }

        // No tool call → finalize this assistant message.
        await chatService.updateMessage(shell.id, {
          content,
          metrics: result.metrics,
        });
        finalContent = content;
        break;
      }

      // ----- 6. Finalize -----
      this.setState('finalizing', 'Saving…');
      await chatService.updateChat(chat.id, { updatedAt: Date.now() });
      void logService.bumpUsage({
        generations: 1,
        tokensOut: (await messageRepo.get(assistantMessage.id))?.metrics?.tokensOut ?? 0,
      });
      void logService.recordActivity('generation.completed', chat.title.slice(0, 60));

      const settings = settingsService.get();
      if (settings.chat.autoTitle && chat.title === 'New chat' && finalContent) {
        void this.autoTitle(chat.id, opts.content);
      }
      if (chat.memoryEnabled && settings.memory.autoExtract && finalContent && assistantMessage) {
        // Extraction is best-effort and async; surface the outcome (if any)
        // as a domain event so the UI can acknowledge it without coupling
        // this service to React.
        void memoryService
          .extractFromExchange(chat.id, userMessage, {
            ...assistantMessage,
            content: finalContent,
          })
          .then((created) => {
            if (created.length > 0) {
              bus.emit('memories:extracted', {
                chatId: chat.id,
                count: created.length,
                facts: created.map((m) => m.fact),
              });
            }
          })
          .catch(() => undefined);
      }

      this.setState('completed', '');
      this.currentChatId = null;
    } catch (err) {
      if (err instanceof AbortedError || this.abortController?.signal.aborted) {
        void logService.bumpUsage({ cancellations: 1 });
        void logService.recordActivity('generation.cancelled', 'Stopped by user');
        this.setState('cancelled', 'Generation cancelled');
      } else {
        const message = err instanceof Error ? err.message : String(err);
        void logService.recordError('chat', 'generation_failed', message);
        this.setState('error', message);
        if (this.currentChatId) {
          const chat = await chatService.getChat(this.currentChatId);
          if (chat) {
            const msgs = await chatService.visibleMessages(chat.id);
            const last = msgs[msgs.length - 1];
            if (last?.role === 'assistant') {
              await chatService.updateMessage(last.id, {
                error: message,
                content: last.content || '*Generation failed.*',
              });
            }
          }
        }
      }
      this.currentChatId = null;
    } finally {
      this.abortController = null;
    }
  }

  /* --------------------------- internals --------------------------- */

  /**
   * Runs one generation turn, streaming deltas to listeners and
   * throttling IndexedDB snapshots (the onPartial callback).
   */
  private async streamTurn(
    chat: Chat,
    turns: ChatTurn[],
    assistantMessageId: UUID,
    onPartial: (partial: string) => Promise<void>
  ) {
    let partialContent = '';
    let lastSnapshot = 0;
    let snapshotBusy = false;

    const result = await inferenceRouter.generate(chat.runtimeId, turns, {
      signal: this.abortController?.signal,
      onToken: (delta) => {
        partialContent += delta;
        // In-memory broadcast for instant UI.
        const frame = { chatId: chat.id, messageId: assistantMessageId, content: partialContent };
        for (const fn of this.streamListeners) fn(frame);
        // Throttled persistence (~3/sec).
        const now = performance.now();
        if (!snapshotBusy && now - lastSnapshot > 320) {
          lastSnapshot = now;
          snapshotBusy = true;
          void onPartial(partialContent)
            .catch(() => undefined)
            .finally(() => {
              snapshotBusy = false;
            });
        }
      },
    });

    // Ensure the final content is persisted even when no token fired
    // (non-streaming fallbacks) or a snapshot was still pending.
    await onPartial(result.content);
    return result;
  }

  private async autoTitle(chatId: UUID, firstMessage: string): Promise<void> {
    try {
      const { gateway } = await import('@/lib/core/net/network-gateway');
      const res = await gateway.request('assist-title', '/api/title', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: firstMessage.slice(0, 500) }),
      });
      if (!res.ok) return;
      const json = (await res.json()) as { title?: string };
      if (json.title) {
        await chatService.updateChat(chatId, { title: json.title.slice(0, 80) });
      }
    } catch {
      // Offline or blocked — title stays "New chat".
    }
  }
}

export const pipeline = new GenerationPipeline();
