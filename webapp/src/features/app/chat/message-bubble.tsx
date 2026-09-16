'use client';

/**
 * MessageBubble — a single chat message.
 *
 * Renders markdown (sanitized by react-markdown), inline tool-call
 * cards, citations, attachments and the full action row:
 * copy / edit / regenerate / branch / star / save-to-notes / delete /
 * read aloud.
 */
import { memo, useMemo, useState } from 'react';
import {
  Copy,
  Check,
  Pencil,
  RefreshCw,
  GitBranch,
  Star,
  Trash2,
  Volume2,
  Square,
  AlertCircle,
  ChevronDown,
  FileText,
  NotebookPen,
  Wrench,
  X,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react';
import type { Message, ToolEvent } from '@/lib/types/domain';
import { MarkdownMessage } from '@/features/app/shared/markdown-message';
import { audioService } from '@/lib/services/audio-service';
import { chatService } from '@/lib/services/chat-service';
import { noteRepo } from '@/lib/core/db/repositories';
import { bus } from '@/lib/core/events/event-bus';
import { router } from '@/lib/core/router';
import { cn, formatClock, uuid } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';
import { ToastAction } from '@/components/ui/toast';

/** Variant switcher props for a message with branched children. */
export interface BranchInfo {
  id: string;
  count: number;
  index: number;
  onSwitch: (dir: 1 | -1) => void;
}

interface MessageBubbleProps {
  message: Message;
  toolEvents: ToolEvent[];
  isStreamingThis: boolean;
  isLastAssistant: boolean;
  /** Animate entrance (message appended after this chat was opened). */
  animate?: boolean;
  /** First message in the chat — anchors the turn rhythm. */
  isFirst?: boolean;
  branch?: BranchInfo;
  /** j/k keyboard navigation cursor is on this message. */
  selected?: boolean;
  onRegenerate: () => void;
  onDeleted: () => void;
  showTokens: boolean;
  /** Pin the timestamp outside the hover-revealed action row. */
  alwaysTimestamps?: boolean;
}

export const MessageBubble = memo(function MessageBubble({
  message,
  toolEvents,
  isStreamingThis,
  isLastAssistant,
  animate,
  isFirst,
  branch,
  selected,
  onRegenerate,
  onDeleted,
  showTokens,
  alwaysTimestamps,
}: MessageBubbleProps) {
  const [copied, setCopied] = useState(false);
  const [editing, setEditing] = useState(false);
  const [editValue, setEditValue] = useState(message.content);
  const [speaking, setSpeaking] = useState(false);
  const [citationsOpen, setCitationsOpen] = useState(false);
  const [savedNote, setSavedNote] = useState(false);
  const isUser = message.role === 'user';

  const tools = useMemo(
    () => toolEvents.filter((t) => message.toolEvents.includes(t.id)),
    [toolEvents, message.toolEvents]
  );

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(message.content);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      toast({ title: 'Clipboard blocked by the browser', variant: 'destructive' });
    }
  };

  /**
   * Saves this message as a Note — the cross-feature counterpart of the
   * Knowledge→Chat "Ask about this document" hand-off. The note keeps a
   * source attribution footer so its origin stays honest; the Notes view
   * refreshes live via the `notes:changed` event.
   */
  const saveToNotes = async () => {
    const firstLine =
      message.content
        .split('\n')
        .map((l) => l.replace(/^[#>*\-\s]+/, '').replace(/[`*]/g, '').trim())
        .find((l) => l.length > 0) ?? 'Saved message';
    const title = firstLine.slice(0, 60) || 'Saved message';
    const now = Date.now();
    await noteRepo.put({
      id: uuid(),
      title,
      content: `${message.content}\n\n---\nSaved from a PocketLLM chat · ${new Date(now).toLocaleString()}`,
      pinned: false,
      createdAt: now,
      updatedAt: now,
    });
    bus.emit('notes:changed');
    setSavedNote(true);
    setTimeout(() => setSavedNote(false), 1600);
    toast({
      title: 'Saved to Notes',
      description: `“${title.slice(0, 40)}${title.length > 40 ? '…' : ''}” is waiting in your Notes.`,
      action: (
        <ToastAction
          altText="Open Notes"
          onClick={() => router.navigate('/app/notes')}
        >
          Open
        </ToastAction>
      ),
    });
  };

  const speak = () => {
    if (speaking) {
      audioService.stopSpeaking();
      setSpeaking(false);
      return;
    }
    setSpeaking(true);
    audioService.speak(message.content, { onEnd: () => setSpeaking(false) });
  };

  const star = async () => {
    await chatService.updateMessage(message.id, { starred: !message.starred });
  };

  const remove = async () => {
    await chatService.deleteMessage(message.id);
    onDeleted();
  };

  const saveEdit = async () => {
    const value = editValue.trim();
    setEditing(false);
    if (!value || value === message.content) return;
    // Editing an earlier user message creates a branch (non-destructive).
    window.dispatchEvent(
      new CustomEvent('pocketllm:edit-branch', {
        detail: { messageId: message.id, content: value },
      })
    );
  };

  return (
    <article
      data-message-id={message.id}
      className={cn(
        'group/msg flex flex-col gap-1 py-3',
        // New turns (every user message except the very first) get extra
        // top spacing so conversation rhythm reads as turns, not a flat list.
        isUser && !isFirst && 'mt-3',
        isUser ? 'items-end' : 'items-start',
        animate && 'animate-msg-in'
      )}
      aria-label={`${isUser ? 'You' : 'Assistant'} message`}
    >
      {/* Attachments */}
      {message.attachments.length > 0 && (
        <div className="flex max-w-full flex-wrap gap-2 pb-1">
          {message.attachments.map((a) =>
            a.kind === 'image' && (a.dataUrl ?? a.url) ? (
               
              <img
                key={a.id}
                src={a.dataUrl ?? a.url}
                alt={a.name}
                className="h-28 w-28 rounded-xl border border-border object-cover"
              />
            ) : (
              <span
                key={a.id}
                className="inline-flex items-center gap-1.5 rounded-lg border border-border bg-card px-2.5 py-1.5 text-xs text-muted-foreground"
              >
                <FileText className="h-3.5 w-3.5" />
                {a.name}
              </span>
            )
          )}
        </div>
      )}

      {/* Bubble */}
      {editing ? (
        <div className="w-full max-w-[85%] rounded-2xl border-2 border-brand-strong bg-card p-3">
          <textarea
            value={editValue}
            onChange={(e) => setEditValue(e.target.value)}
            className="min-h-[80px] w-full resize-y bg-transparent text-[15px] outline-none"
            aria-label="Edit message"
            autoFocus
          />
          <div className="flex justify-end gap-2 pt-2">
            <button
              className="rounded-lg px-3 py-1.5 text-xs hover:bg-muted"
              onClick={() => setEditing(false)}
            >
              Cancel
            </button>
            <button
              className="rounded-lg bg-primary px-3 py-1.5 text-xs font-medium text-primary-foreground"
              onClick={saveEdit}
            >
              Save as branch
            </button>
          </div>
        </div>
      ) : (
        <div
          className={cn(
            'relative max-w-[92%] rounded-2xl px-4 py-2.5 text-[15px] leading-relaxed transition-all duration-150 sm:max-w-[80%] xl:max-w-[75%]',
            isUser
              ? 'bg-primary text-primary-foreground shadow-sm [margin-bottom:2px]'
              : 'border border-border bg-card py-3 hover:border-brand-strong/40 hover:shadow-sm',
            isStreamingThis && 'streaming-caret',
            // j/k navigation cursor — brand ring + slight lift.
            selected &&
              'ring-2 ring-brand/70 ring-offset-2 ring-offset-background shadow-md'
          )}
        >
          {isUser ? (
            <p className="whitespace-pre-wrap break-words">{message.content}</p>
          ) : (
            <MarkdownMessage content={message.content} />
          )}
        </div>
      )}

      {/* Tool events */}
      {tools.length > 0 && (
        <div className="flex w-full max-w-[92%] flex-col gap-2 sm:max-w-[80%] xl:max-w-[75%]">
          {tools.map((ev) => (
            <ToolEventCard key={ev.id} event={ev} />
          ))}
        </div>
      )}

      {/* Error */}
      {message.error && (
        <div
          role="alert"
          className="flex w-full max-w-[92%] items-start gap-2 rounded-xl border border-destructive/40 bg-destructive/10 px-3 py-2 text-[13px] text-destructive sm:max-w-[80%] xl:max-w-[75%]"
        >
          <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
          <div>
            <p className="font-medium">Generation failed</p>
            <p className="opacity-90">{message.error}</p>
          </div>
        </div>
      )}

      {/* Branch variant switcher — shown on the message ABOVE the variants */}
      {branch && !isStreamingThis && (
        <div className="flex w-full max-w-[92%] items-center gap-1 sm:max-w-[80%] xl:max-w-[75%]">
          <div className="inline-flex items-center gap-0.5 rounded-full border border-border bg-card py-0.5 pl-2 pr-0.5 text-[11px] text-muted-foreground shadow-sm">
            <GitBranch className="h-3 w-3 text-brand-strong" aria-hidden />
            <span className="ml-1 tabular-nums">
              {branch.index + 1}/{branch.count}
            </span>
            <button
              onClick={() => branch.onSwitch(-1)}
              disabled={branch.count < 2}
              className="rounded-full p-1 transition-colors hover:bg-muted hover:text-foreground disabled:opacity-30"
              aria-label="Previous variant"
              title="Previous variant"
            >
              <ChevronLeft className="h-3 w-3" />
            </button>
            <button
              onClick={() => branch.onSwitch(1)}
              disabled={branch.count < 2}
              className="rounded-full p-1 transition-colors hover:bg-muted hover:text-foreground disabled:opacity-30"
              aria-label="Next variant"
              title="Next variant"
            >
              <ChevronRight className="h-3 w-3" />
            </button>
          </div>
        </div>
      )}

      {/* Citations */}
      {message.citations.length > 0 && !isUser && (
        <div className="w-full max-w-[92%] sm:max-w-[80%] xl:max-w-[75%]">
          <button
            onClick={() => setCitationsOpen(!citationsOpen)}
            className="mt-0.5 inline-flex items-center gap-2 rounded-full border border-border bg-card px-2.5 py-1 text-[11px] text-muted-foreground transition-colors hover:border-brand-strong hover:bg-muted/50 hover:text-foreground"
            aria-expanded={citationsOpen}
          >
            <FileText className="h-3 w-3" />
            {message.citations.length} source{message.citations.length > 1 ? 's' : ''}
            <ChevronDown className={cn('h-3 w-3 transition-transform', citationsOpen && 'rotate-180')} />
          </button>
          {citationsOpen && (
            <ul className="mt-2 space-y-2">
              {message.citations.map((c, i) => (
                <li
                  key={c.chunkId}
                  className="rounded-xl border border-border bg-card p-3 text-[13px]"
                >
                  <div className="flex items-center justify-between gap-2">
                    <span className="flex items-center gap-1.5 font-medium">
                      <span className="flex h-4 w-4 items-center justify-center rounded bg-brand text-[10px] font-bold text-brand-foreground">
                        {i + 1}
                      </span>
                      {c.documentName}
                      {c.page ? <span className="text-muted-foreground">· p.{c.page}</span> : null}
                    </span>
                    <span className="font-mono text-[10px] text-muted-foreground">
                      {c.score.toFixed(2)}
                    </span>
                  </div>
                  <p className="mt-1.5 line-clamp-3 text-muted-foreground">{c.excerpt}</p>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      {/* Actions */}
      {!editing && !isStreamingThis && (
        <div
          className={cn(
            'flex items-center gap-0.5',
            'absolute-static mt-0.5',
            isUser && 'flex-row-reverse'
          )}
        >
          {/* Timestamp — always visible when the setting asks for it,
              otherwise it rides along with the hover-revealed actions. */}
          {alwaysTimestamps && (
            <time
              dateTime={new Date(message.createdAt).toISOString()}
              className="pr-1 text-[10px] tabular-nums text-muted-foreground/60"
            >
              {formatClock(message.createdAt)}
            </time>
          )}
          <div
            className={cn(
              'flex items-center gap-0.5 opacity-0 transition-opacity focus-within:opacity-100 group-hover/msg:opacity-100'
            )}
          >
            {!alwaysTimestamps && (
              <span className="pr-1 text-[10px] tabular-nums text-muted-foreground/60">
                {formatClock(message.createdAt)}
              </span>
            )}
          <ActionButton label={copied ? 'Copied' : 'Copy'} onClick={copy}>
            {copied ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
          </ActionButton>
          {isUser && (
            <ActionButton label="Edit (creates a branch)" onClick={() => setEditing(true)}>
              <Pencil className="h-3.5 w-3.5" />
            </ActionButton>
          )}
          {!isUser && isLastAssistant && (
            <ActionButton label="Regenerate" onClick={onRegenerate}>
              <RefreshCw className="h-3.5 w-3.5" />
            </ActionButton>
          )}
          {!isUser && (
            <ActionButton label="Read aloud" onClick={speak}>
              {speaking ? <Square className="h-3.5 w-3.5" /> : <Volume2 className="h-3.5 w-3.5" />}
            </ActionButton>
          )}
          <ActionButton
            label={message.starred ? 'Unstar' : 'Star'}
            onClick={star}
            active={message.starred}
          >
            <Star className={cn('h-3.5 w-3.5', message.starred && 'fill-brand text-brand-strong')} />
          </ActionButton>
          <ActionButton
            label={savedNote ? 'Saved to Notes' : 'Save to notes'}
            onClick={() => void saveToNotes()}
            active={savedNote}
          >
            {savedNote ? (
              <Check className="h-3.5 w-3.5" />
            ) : (
              <NotebookPen className="h-3.5 w-3.5" />
            )}
          </ActionButton>
          {!isUser && showTokens && message.metrics && (
            <span className="pl-1 font-mono text-[10px] text-muted-foreground/50">
              {message.metrics.tokensPerSecond ? `${message.metrics.tokensPerSecond} tok/s · ` : ''}
              {message.metrics.tokensOut ? `~${message.metrics.tokensOut} tok` : ''}
            </span>
          )}
          <ActionButton label="Delete message" onClick={remove} danger>
            <Trash2 className="h-3.5 w-3.5" />
          </ActionButton>
          </div>
        </div>
      )}
    </article>
  );
});

function ActionButton({
  label,
  onClick,
  children,
  active,
  danger,
}: {
  label: string;
  onClick: () => void;
  children: React.ReactNode;
  active?: boolean;
  danger?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      title={label}
      aria-label={label}
      className={cn(
        'rounded-md p-1.5 text-muted-foreground/70 transition-all hover:bg-muted hover:text-foreground active:scale-90',
        active && 'text-brand-strong',
        danger && 'hover:text-destructive'
      )}
    >
      {children}
    </button>
  );
}

/** Visible tool execution card (confirmation happens in the banner). */
function ToolEventCard({ event }: { event: ToolEvent }) {
  const [open, setOpen] = useState(false);
  const tone =
    event.status === 'succeeded'
      ? 'border-success/40 bg-success/5'
      : event.status === 'failed' || event.status === 'denied'
        ? 'border-destructive/40 bg-destructive/5'
        : 'border-border bg-muted/50';

  return (
    <div className={cn('rounded-xl border px-3 py-2 text-[13px]', tone)}>
      <button
        className="flex w-full items-center gap-2 text-left"
        onClick={() => setOpen(!open)}
        aria-expanded={open}
      >
        <Wrench className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
        <span className="font-mono text-[12px] font-medium">{event.tool}</span>
        <span
          className={cn(
            'rounded-full px-1.5 py-0.5 text-[10px] font-medium',
            event.status === 'succeeded' && 'bg-success/15 text-success',
            event.status === 'failed' && 'bg-destructive/15 text-destructive',
            event.status === 'denied' && 'bg-muted text-muted-foreground',
            event.status === 'running' && 'bg-brand text-brand-foreground'
          )}
        >
          {event.status}
        </span>
        <ChevronDown
          className={cn('ml-auto h-3.5 w-3.5 text-muted-foreground transition-transform', open && 'rotate-180')}
        />
      </button>
      {open && (
        <div className="mt-2 space-y-2 border-t border-border/60 pt-2">
          <div>
            <p className="mb-1 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">
              Arguments (validated)
            </p>
            <pre className="overflow-x-auto rounded-lg bg-background/80 p-2 font-mono text-[11px]">
              {JSON.stringify(event.args, null, 2)}
            </pre>
          </div>
          {event.error ? (
            <p className="text-destructive">{event.error}</p>
          ) : event.result != null ? (
            <div>
              <p className="mb-1 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">
                Result
              </p>
              <pre className="max-h-48 overflow-auto rounded-lg bg-background/80 p-2 font-mono text-[11px] scrollbar-slim">
                {JSON.stringify(event.result, null, 2)}
              </pre>
            </div>
          ) : null}
        </div>
      )}
      {event.status === 'awaitingConfirmation' && (
        <p className="mt-1 text-[11px] text-muted-foreground">
          Waiting for your confirmation…
        </p>
      )}
    </div>
  );
}

void X;
