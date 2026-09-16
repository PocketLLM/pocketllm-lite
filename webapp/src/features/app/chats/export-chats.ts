/**
 * Chat export — downloads selected chats (with their messages) as a
 * single JSON file, or as one combined Markdown document. Runs fully
 * client-side; nothing leaves the device.
 */
import { chatService } from '@/lib/services/chat-service';
import { toolEventRepo } from '@/lib/core/db/repositories';
import { messageToMarkdown } from '@/features/app/chat/chat-export';
import type { Chat, ToolEvent } from '@/lib/types/domain';

/** Triggers a browser download for a blob. */
export function downloadBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.rel = 'noopener';
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1_000);
}

function slugify(text: string): string {
  const slug = text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40);
  return slug || 'untitled';
}

function fileTimestamp(): string {
  const d = new Date();
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}`;
}

/**
 * Exports chats (including their full message history) to a JSON file.
 * Returns the filename used, for confirmation toasts.
 */
export async function exportChats(chats: Chat[]): Promise<string> {
  if (chats.length === 0) throw new Error('Nothing to export');

  const exported: Array<Chat & { messages: unknown[] }> = [];
  for (const chat of chats) {
    const messages = await chatService.listMessages(chat.id);
    exported.push({ ...chat, messages });
  }

  const payload = {
    format: 'pocketllm/chats-export',
    version: 1,
    exportedAt: new Date().toISOString(),
    appVersion: '1.0.38-web',
    chats: exported,
  };

  const filename =
    chats.length === 1
      ? `pocketllm-chat-${slugify(chats[0].title)}.json`
      : `pocketllm-chats-${fileTimestamp()}.json`;

  downloadBlob(
    new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' }),
    filename
  );
  return filename;
}

/**
 * Exports chats as ONE combined, human-readable Markdown document:
 * a title page with a linked table of contents, then every chat with its
 * full message history. Returns the filename used for the toast.
 */
export async function exportChatsToMarkdown(chats: Chat[]): Promise<string> {
  if (chats.length === 0) throw new Error('Nothing to export');

  const allToolEvents = (await toolEventRepo.getAll()) as ToolEvent[];
  const toolById = new Map(allToolEvents.map((t) => [t.id, t] as const));

  const parts: string[] = [
    '# PocketLLM chats export',
    '',
    `> ${chats.length} conversation${chats.length === 1 ? '' : 's'} · exported ${new Date().toLocaleString()} · produced entirely on this device.`,
    '',
  ];

  // Table of contents first, so long exports stay navigable.
  parts.push('## Contents', '');
  for (const chat of chats) {
    const anchor = chat.title
      .toLowerCase()
      .replace(/[^\w\s-]/g, '')
      .trim()
      .replace(/\s+/g, '-');
    parts.push(`- [${chat.title || 'Untitled chat'}](#${anchor})`);
  }
  parts.push('', '---', '');

  for (const chat of chats) {
    const messages = (await chatService.listMessages(chat.id)).filter(
      (m) => m.role !== 'system'
    );
    const stats =
      messages.length > 0
        ? `${messages.length} messages · started ${new Date(messages[0].createdAt).toLocaleDateString()}`
        : 'no messages';
    parts.push(
      `## ${chat.title || 'Untitled chat'}`,
      '',
      `> ${stats}${chat.archived ? ' · archived' : ''}${chat.pinned ? ' · pinned' : ''}`,
      ''
    );
    for (const m of messages) parts.push(messageToMarkdown(m, toolById), '');
    parts.push('---', '');
  }

  const filename = `pocketllm-chats-${fileTimestamp()}.md`;
  downloadBlob(
    new Blob([parts.join('\n')], { type: 'text/markdown;charset=utf-8' }),
    filename
  );
  return filename;
}
