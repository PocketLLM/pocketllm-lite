'use client';

/**
 * PersonaSelector — chat-header pill for switching the active persona
 * (or none). Personas layer instructions + optional model overrides.
 */
import { useEffect, useRef, useState } from 'react';
import { ChevronDown, UserRound, X } from 'lucide-react';
import { personaRepo } from '@/lib/core/db/repositories';
import { bus } from '@/lib/core/events/event-bus';
import { chatService } from '@/lib/services/chat-service';
import { cn } from '@/lib/utils';
import type { Chat, Persona } from '@/lib/types/domain';

export function PersonaSelector({ chat }: { chat: Chat }) {
  const [open, setOpen] = useState(false);
  const [personas, setPersonas] = useState<Persona[]>([]);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const load = () =>
      void personaRepo.getAll().then((all) =>
        setPersonas(all.sort((a, b) => a.name.localeCompare(b.name)))
      );
    load();
    return bus.on('personas:changed', load);
  }, []);

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

  const active = personas.find((p) => p.id === chat.personaId) ?? null;

  const select = async (id: string | null) => {
    await chatService.updateChat(chat.id, { personaId: id });
    setOpen(false);
  };

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen(!open)}
        aria-haspopup="listbox"
        aria-expanded={open}
        className={cn(
          'flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-[13px] transition-colors',
          active
            ? 'border-brand-strong bg-brand/20 font-medium'
            : 'border-border bg-card text-muted-foreground hover:border-brand-strong hover:text-foreground'
        )}
      >
        {active ? (
          <span aria-hidden>{active.emoji}</span>
        ) : (
          <UserRound className="h-3.5 w-3.5" />
        )}
        <span className="max-w-[120px] truncate sm:max-w-none">
          {active ? active.name : 'No persona'}
        </span>
        <ChevronDown className={cn('h-3.5 w-3.5 opacity-60 transition-transform', open && 'rotate-180')} />
      </button>

      {open && (
        <div
          role="listbox"
          className="absolute left-0 top-full z-50 mt-1.5 w-64 overflow-hidden rounded-xl border border-border bg-popover shadow-lg animate-in-up"
        >
          <button
            role="option"
            aria-selected={!chat.personaId}
            onClick={() => void select(null)}
            className={cn(
              'flex w-full items-center gap-2 px-3 py-2.5 text-left text-[13px] hover:bg-muted',
              !chat.personaId && 'bg-muted font-medium'
            )}
          >
            <UserRound className="h-3.5 w-3.5 text-muted-foreground" />
            No persona — base PocketLLM only
          </button>
          {personas.length > 0 && (
            <p className="border-y border-border bg-muted/40 px-3 py-1.5 text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
              Your personas
            </p>
          )}
          <div className="max-h-64 overflow-y-auto scrollbar-slim">
            {personas.map((p) => (
              <button
                key={p.id}
                role="option"
                aria-selected={chat.personaId === p.id}
                onClick={() => void select(p.id)}
                className={cn(
                  'flex w-full items-center gap-2 px-3 py-2 text-left text-[13px] hover:bg-muted',
                  chat.personaId === p.id && 'bg-muted font-medium'
                )}
              >
                <span aria-hidden>{p.emoji}</span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate">{p.name}</span>
                  <span className="block truncate text-[11px] text-muted-foreground">
                    {p.instructions}
                  </span>
                </span>
              </button>
            ))}
          </div>
          <button
            className="w-full border-t border-border px-3 py-2 text-left text-[12px] text-muted-foreground hover:bg-muted hover:text-foreground"
            onClick={() => {
              setOpen(false);
              window.location.hash = '/app/personas';
            }}
          >
            Manage personas →
          </button>
        </div>
      )}
    </div>
  );
}
