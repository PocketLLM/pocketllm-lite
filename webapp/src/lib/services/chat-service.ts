/**
 * ChatService — chats, messages and branch management.
 *
 * Deleting a chat deletes its messages, branches, tool-event
 * references and drafts (data deletion semantics from the plan).
 * Editing an earlier user message creates a branch rather than
 * rewriting history.
 */
import { bus } from '@/lib/core/events/event-bus';
import {
  branchRepo,
  chatRepo,
  messageRepo,
  toolEventRepo,
} from '@/lib/core/db/repositories';
import type {
  Chat,
  ChatBranch,
  Message,
  UUID,
} from '@/lib/types/domain';
import { logService } from './log-service';
import { settingsService } from './settings-service';
import { uuid } from '@/lib/utils';

class ChatService {
  /* ---------------------------- chats ---------------------------- */

  async listChats(includeArchived = false): Promise<Chat[]> {
    const all = await chatRepo.getAll();
    return all
      .filter((c) => includeArchived || !c.archived)
      .sort((a, b) => {
        if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
        return b.lastMessageAt - a.lastMessageAt;
      });
  }

  async getChat(id: UUID): Promise<Chat | undefined> {
    return chatRepo.get(id);
  }

  async createChat(partial?: Partial<Chat>): Promise<Chat> {
    const now = Date.now();
    const settings = settingsService.get();
    const chat: Chat = {
      id: uuid(),
      title: 'New chat',
      modelId: partial?.modelId ?? settings.chat.defaultModelId,
      runtimeId: partial?.runtimeId ?? settings.chat.defaultRuntimeId,
      personaId: partial?.personaId ?? null,
      pinned: false,
      archived: false,
      tags: [],
      memoryEnabled: true,
      knowledgeDocIds: [],
      retrievalMode: null,
      draft: '',
      createdAt: now,
      updatedAt: now,
      lastMessageAt: now,
      messageCount: 0,
      ...partial,
    };
    await chatRepo.put(chat);
    bus.emit('chats:changed');
    void logService.bumpUsage({ chatsCreated: 1 });
    return chat;
  }

  async updateChat(id: UUID, patch: Partial<Chat>): Promise<Chat | undefined> {
    const chat = await chatRepo.get(id);
    if (!chat) return undefined;
    const next = { ...chat, ...patch, updatedAt: Date.now() };
    await chatRepo.put(next);
    bus.emit('chats:changed');
    return next;
  }

  /** Deleting a chat cascades to messages, branches, tool events. */
  async deleteChat(id: UUID): Promise<void> {
    const messages = await messageRepo.getByIndex('chatId', id);
    const branches = await branchRepo.getByIndex('chatId', id);
    const toolEvents = await toolEventRepo.getByIndex('chatId', id);
    await messageRepo.deleteMany(messages.map((m) => m.id));
    await branchRepo.deleteMany(branches.map((b) => b.id));
    await toolEventRepo.deleteMany(toolEvents.map((t) => t.id));
    await chatRepo.delete(id);
    bus.emit('chats:changed');
    void logService.recordActivity('chat.deleted', `Deleted ${messages.length} message chat`);
  }

  async deleteChats(ids: UUID[]): Promise<void> {
    for (const id of ids) await this.deleteChat(id);
  }

  /* --------------------------- messages --------------------------- */

  async listMessages(chatId: UUID): Promise<Message[]> {
    const messages = await messageRepo.getByIndex('chatId', chatId);
    return messages.sort((a, b) => a.seq - b.seq);
  }

  /**
   * Returns the currently-visible message chain: follows each branch's
   * active variant where divergence exists.
   */
  async visibleMessages(chatId: UUID): Promise<Message[]> {
    const all = await this.listMessages(chatId);
    const branches = await branchRepo.getByIndex('chatId', chatId);
    if (branches.length === 0) return all;
    const hidden = new Set<UUID>();
    for (const b of branches) {
      const inactive = b.variants.filter((v) => v !== b.activeMessageId);
      for (const v of inactive) {
        hidden.add(v);
        // Descendants of an inactive variant are hidden too.
        this.collectDescendants(all, v, hidden);
      }
    }
    return all.filter((m) => !hidden.has(m.id));
  }

  private collectDescendants(all: Message[], parentId: UUID, out: Set<UUID>): void {
    for (const m of all) {
      if (m.parentMessageId === parentId) {
        out.add(m.id);
        this.collectDescendants(all, m.id, out);
      }
    }
  }

  async appendMessage(message: Omit<Message, 'seq' | 'createdAt' | 'updatedAt'> & { seq?: number }): Promise<Message> {
    const existing = await messageRepo.getByIndex('chatId', message.chatId);
    const maxSeq = existing.reduce((m, x) => Math.max(m, x.seq), 0);
    const now = Date.now();
    const full: Message = {
      ...message,
      seq: message.seq ?? maxSeq + 1,
      createdAt: now,
      updatedAt: now,
    };
    await messageRepo.put(full);
    await chatRepo.put({
      ...(await chatRepo.get(message.chatId))!,
      lastMessageAt: now,
      updatedAt: now,
      messageCount: existing.length + 1,
    });
    bus.emit('messages:changed', { chatId: message.chatId });
    bus.emit('chats:changed');
    return full;
  }

  async updateMessage(id: UUID, patch: Partial<Message>): Promise<Message | undefined> {
    const m = await messageRepo.get(id);
    if (!m) return undefined;
    const next = { ...m, ...patch, updatedAt: Date.now() };
    await messageRepo.put(next);
    bus.emit('messages:changed', { chatId: m.chatId });
    return next;
  }

  async deleteMessage(id: UUID): Promise<void> {
    const m = await messageRepo.get(id);
    if (!m) return;
    await messageRepo.delete(id);
    bus.emit('messages:changed', { chatId: m.chatId });
  }

  /* --------------------------- branches --------------------------- */

  /**
   * Creates a sibling variant for the child of `parentMessageId`.
   * The new message becomes the active variant.
   */
  async createBranch(
    chatId: UUID,
    parentMessageId: UUID | null,
    variantMessage: Omit<Message, 'id' | 'chatId' | 'parentMessageId' | 'seq' | 'createdAt' | 'updatedAt'>
  ): Promise<Message> {
    const existingBranches = await branchRepo.getByIndex('chatId', chatId);
    const branch =
      existingBranches.find((b) => b.parentMessageId === parentMessageId) ?? null;

    const now = Date.now();
    const all = await messageRepo.getByIndex('chatId', chatId);
    const maxSeq = all.reduce((m, x) => Math.max(m, x.seq), 0);

    const message: Message = {
      ...variantMessage,
      id: uuid(),
      chatId,
      parentMessageId,
      seq: maxSeq + 1,
      createdAt: now,
      updatedAt: now,
    };
    await messageRepo.put(message);

    if (branch) {
      branch.variants.push(message.id);
      branch.activeMessageId = message.id;
      await branchRepo.put(branch);
    } else {
      // First divergence: the previous child becomes a variant too.
      const previousChild = all.find((m) => m.parentMessageId === parentMessageId);
      await branchRepo.put({
        id: uuid(),
        chatId,
        parentMessageId,
        variants: previousChild ? [previousChild.id, message.id] : [message.id],
        activeMessageId: message.id,
        label: 'Edit branch',
        createdAt: now,
      });
    }
    bus.emit('messages:changed', { chatId });
    bus.emit('branches:changed', { chatId });
    return message;
  }

  async switchVariant(chatId: UUID, branchId: UUID, messageId: UUID): Promise<void> {
    const branch = await branchRepo.get(branchId);
    if (!branch || !branch.variants.includes(messageId)) return;
    branch.activeMessageId = messageId;
    await branchRepo.put(branch);
    bus.emit('messages:changed', { chatId });
    bus.emit('branches:changed', { chatId });
  }

  async listBranches(chatId: UUID): Promise<ChatBranch[]> {
    return branchRepo.getByIndex('chatId', chatId);
  }

  /* --------------------------- search ----------------------------- */

  async searchChats(query: string, opts?: { includeArchived?: boolean }): Promise<Chat[]> {
    const q = query.trim().toLowerCase();
    const chats = await this.listChats(opts?.includeArchived);
    if (!q) return chats;
    const lower = q;
    // Match title first, then message contents.
    const byTitle = chats.filter((c) => c.title.toLowerCase().includes(lower));
    const remaining = chats.filter(
      (c) => !byTitle.includes(c) && !c.archived
    );
    const contentMatches: Chat[] = [];
    for (const c of remaining) {
      const msgs = await messageRepo.getByIndex('chatId', c.id);
      if (msgs.some((m) => m.content.toLowerCase().includes(lower))) {
        contentMatches.push(c);
      }
    }
    return [...byTitle, ...contentMatches];
  }

  /** Draft autosave — debouncing happens at the UI layer. */
  async saveDraft(chatId: UUID, draft: string): Promise<void> {
    const chat = await chatRepo.get(chatId);
    if (!chat || chat.draft === draft) return;
    chat.draft = draft;
    await chatRepo.put(chat);
    bus.emit('chats:changed');
  }
}

export const chatService = new ChatService();
