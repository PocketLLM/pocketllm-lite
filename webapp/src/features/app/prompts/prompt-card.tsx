'use client';

/**
 * PromptCard — one reusable prompt.
 *
 * Primary action "Use in chat" creates a new chat, prefills its
 * composer draft with the prompt body and navigates there. Copy,
 * edit and delete live in the header row.
 */
import { useState } from 'react';
import {
  Check,
  ClipboardCopy,
  Loader2,
  MessageSquarePlus,
  Pencil,
  Trash2,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { MetaPill } from '@/features/app/shared/ui';
import { toast } from '@/hooks/use-toast';
import { router } from '@/lib/core/router';
import { chatService } from '@/lib/services/chat-service';
import { formatRelativeTime } from '@/lib/utils';
import type { Prompt } from '@/lib/types/domain';

function truncate(text: string, max: number): string {
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

export function PromptCard({
  prompt,
  onEdit,
  onDelete,
}: {
  prompt: Prompt;
  onEdit: (prompt: Prompt) => void;
  onDelete: (prompt: Prompt) => void;
}) {
  const [using, setUsing] = useState(false);
  const [copied, setCopied] = useState(false);

  const handleUse = async () => {
    setUsing(true);
    try {
      const chat = await chatService.createChat({});
      await chatService.saveDraft(chat.id, prompt.body);
      toast({
        title: 'Prompt loaded into a new chat',
        description: `“${truncate(prompt.title, 60)}” is in the composer — edit it or hit send.`,
      });
      router.navigate(`/app/chat/${chat.id}`);
    } catch (err) {
      toast({
        title: 'Could not start chat',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
      setUsing(false);
    }
  };

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(prompt.body);
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    } catch {
      toast({
        title: 'Copy failed',
        description: 'The clipboard is unavailable in this browser.',
        variant: 'destructive',
      });
    }
  };

  return (
    <li className="flex h-full flex-col rounded-xl border border-border bg-card p-4">
      <div className="flex items-start justify-between gap-2">
        <h3 className="min-w-0 flex-1 text-sm font-medium leading-snug">
          {prompt.title}
        </h3>
        <div className="flex shrink-0 items-center gap-0.5">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => void handleCopy()}
            aria-label={
              copied
                ? `Copied “${truncate(prompt.title, 40)}”`
                : `Copy “${truncate(prompt.title, 40)}” to clipboard`
            }
            title={copied ? 'Copied' : 'Copy prompt'}
          >
            {copied ? (
              <Check aria-hidden className="text-success" />
            ) : (
              <ClipboardCopy aria-hidden className="text-muted-foreground" />
            )}
          </Button>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => onEdit(prompt)}
            aria-label={`Edit prompt “${truncate(prompt.title, 40)}”`}
            title="Edit prompt"
          >
            <Pencil aria-hidden />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="text-muted-foreground hover:text-destructive"
            onClick={() => onDelete(prompt)}
            aria-label={`Delete prompt “${truncate(prompt.title, 40)}”`}
            title="Delete prompt"
          >
            <Trash2 aria-hidden />
          </Button>
        </div>
      </div>

      <p className="mt-1.5 line-clamp-2 whitespace-pre-line text-[13px] leading-relaxed text-muted-foreground">
        {prompt.body}
      </p>

      <div className="mt-auto flex flex-wrap items-center justify-between gap-2 pt-3">
        <div className="flex flex-wrap items-center gap-2 text-[11px] text-muted-foreground">
          {prompt.category && <MetaPill>{prompt.category}</MetaPill>}
          <span>updated {formatRelativeTime(prompt.updatedAt)}</span>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={() => void handleUse()}
          disabled={using}
        >
          {using ? (
            <Loader2 className="animate-spin" aria-hidden />
          ) : (
            <MessageSquarePlus aria-hidden />
          )}
          Use in chat
        </Button>
      </div>
    </li>
  );
}
