'use client';

/**
 * ModelSelector — the chat header pill for switching runtimes/models.
 * Shows availability honestly (Ollama unreachable = empty + hint).
 */
import { useEffect, useRef, useState } from 'react';
import { ChevronDown, Check, Sparkles, Server, Plug, Boxes } from 'lucide-react';
import { useAppStore } from '@/lib/store/app-store';
import { chatService } from '@/lib/services/chat-service';
import { inferenceRouter } from '@/lib/services/inference/inference-router';
import { cn } from '@/lib/utils';
import type { Chat, RuntimeId } from '@/lib/types/domain';

const RUNTIME_META: Record<RuntimeId, { label: string; hint: string; icon: React.ComponentType<{ className?: string }> }> = {
  assist: { label: 'PocketLLM Assist', hint: 'Built-in · needs network', icon: Sparkles },
  ollama: { label: 'Ollama', hint: 'Your computer · local', icon: Server },
  openai: { label: 'OpenAI-compatible', hint: 'Your endpoint', icon: Plug },
  mock: { label: 'Offline Sandbox', hint: 'Deterministic · no network', icon: Boxes },
};

export function ModelSelector({ chat }: { chat: Chat }) {
  const { models, refreshModels } = useAppStore();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    document.addEventListener('mousedown', onClick);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onClick);
      document.removeEventListener('keydown', onKey);
    };
  }, []);

  const select = async (runtimeId: RuntimeId, modelId: string) => {
    await chatService.updateChat(chat.id, { runtimeId, modelId });
    setOpen(false);
  };

  const currentModel = models.find((m) => m.runtimeId === chat.runtimeId && m.id === chat.modelId);
  const currentMeta = RUNTIME_META[chat.runtimeId];
  const CurrentIcon = currentMeta?.icon ?? Sparkles;

  const byRuntime = ['assist', 'ollama', 'openai', 'mock'] as const;

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => {
          setOpen(!open);
          void refreshModels();
        }}
        aria-haspopup="listbox"
        aria-expanded={open}
        className="flex items-center gap-1.5 rounded-full border border-border bg-card px-3 py-1.5 text-[13px] font-medium hover:border-brand-strong"
      >
        <CurrentIcon className="h-3.5 w-3.5 text-muted-foreground" />
        <span className="max-w-[160px] truncate sm:max-w-none">
          {currentModel?.label ?? chat.modelId}
        </span>
        <ChevronDown className={cn('h-3.5 w-3.5 text-muted-foreground transition-transform', open && 'rotate-180')} />
      </button>

      {open && (
        <div
          role="listbox"
          className="absolute left-0 top-full z-50 mt-1.5 w-72 overflow-hidden rounded-xl border border-border bg-popover shadow-lg animate-in-up"
        >
          <p className="border-b border-border px-3 py-2 text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
            Runtime · model
          </p>
          <div className="max-h-80 overflow-y-auto scrollbar-slim">
            {byRuntime.map((runtimeId) => {
              const runtimeModels = models.filter((m) => m.runtimeId === runtimeId);
              const meta = RUNTIME_META[runtimeId];
              const Icon = meta.icon;
              return (
                <div key={runtimeId} className="py-1">
                  <div className="flex items-center gap-2 px-3 py-1.5">
                    <Icon className="h-3 w-3 text-muted-foreground" />
                    <span className="text-[11px] font-medium text-muted-foreground">{meta.label}</span>
                    <span className="ml-auto text-[10px] text-muted-foreground/60">{meta.hint}</span>
                  </div>
                  {runtimeModels.length === 0 ? (
                    <button
                      className="w-full px-3 py-1.5 pl-8 text-left text-[11px] text-muted-foreground/60 hover:bg-muted"
                      onClick={() => {
                        setOpen(false);
                        window.location.hash = '/app/providers';
                      }}
                    >
                      Not configured — open Providers →
                    </button>
                  ) : (
                    runtimeModels.map((m) => (
                      <button
                        key={`${m.runtimeId}:${m.id}`}
                        role="option"
                        aria-selected={chat.runtimeId === m.runtimeId && chat.modelId === m.id}
                        onClick={() => void select(m.runtimeId, m.id)}
                        className={cn(
                          'flex w-full items-center gap-2 px-3 py-2 pl-8 text-left text-[13px] hover:bg-muted',
                          chat.runtimeId === m.runtimeId && chat.modelId === m.id && 'bg-muted'
                        )}
                      >
                        <span className="min-w-0 flex-1">
                          <span className="block truncate">{m.label}</span>
                          {m.detail && (
                            <span className="block truncate text-[11px] text-muted-foreground">
                              {m.detail}
                            </span>
                          )}
                        </span>
                        {chat.runtimeId === m.runtimeId && chat.modelId === m.id && (
                          <Check className="h-3.5 w-3.5 text-brand-strong" />
                        )}
                      </button>
                    ))
                  )}
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}


