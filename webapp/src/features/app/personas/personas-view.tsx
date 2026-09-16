'use client';

/**
 * PersonasView — custom AI persona manager.
 *
 * Personas layer specialized instructions (plus optional temperature
 * and model overrides) into every generation where selected.
 */
import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Plus,
  Search,
  Pencil,
  Trash2,
  Sparkles,
  MessageSquarePlus,
  Copy,
} from 'lucide-react';
import { personaRepo } from '@/lib/core/db/repositories';
import { bus } from '@/lib/core/events/event-bus';
import { deepLink } from '@/lib/core/deep-link';
import { useDeepLink } from '@/lib/core/use-deep-link';
import { chatService } from '@/lib/services/chat-service';
import { router } from '@/lib/core/router';
import { useAppStore } from '@/lib/store/app-store';
import { PageHeader, EmptyState, MetaPill, Section } from '@/features/app/shared/ui';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Slider } from '@/components/ui/slider';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { cn, formatRelativeTime } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';
import type { Persona, RuntimeId } from '@/lib/types/domain';

const EMOJI_CHOICES = [
  '🧠', '🤖', '📝', '🔬', '🎨', '💼', '📚', '🎯', '⚖️', '🛠️',
  '🌍', '💡', '🧪', '📊', '✍️', '🎓', '🩺', '🧑‍⚖️', '🚀', '🌱',
];

interface EditorState {
  open: boolean;
  id?: string;
  name: string;
  emoji: string;
  instructions: string;
  temperature: number | null;
  useDefaultModel: boolean;
  runtimeId: RuntimeId;
  modelId: string;
}

const EMPTY_EDITOR: EditorState = {
  open: false,
  name: '',
  emoji: '🧠',
  instructions: '',
  temperature: null,
  useDefaultModel: true,
  runtimeId: 'assist',
  modelId: 'pocketllm-assist',
};

export function PersonasView() {
  const { models } = useAppStore();
  const [personas, setPersonas] = useState<Persona[]>([]);
  const [search, setSearch] = useState('');
  const [editor, setEditor] = useState<EditorState>(EMPTY_EDITOR);
  const [deleteTarget, setDeleteTarget] = useState<Persona | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    const all = await personaRepo.getAll();
    const sorted = all.sort((a, b) => b.updatedAt - a.updatedAt);
    setPersonas(sorted);
    setLoading(false);
    // Deep link from the command palette: open this persona's editor.
    const request = deepLink.take('persona');
    const target = request ? sorted.find((p) => p.id === request.id) : undefined;
    if (target) {
      setEditor({
        open: true,
        id: target.id,
        name: target.name,
        emoji: target.emoji || '🧠',
        instructions: target.instructions,
        temperature: target.temperature ?? null,
        useDefaultModel: !target.modelId,
        runtimeId: target.runtimeId ?? 'assist',
        modelId: target.modelId ?? 'pocketllm-assist',
      });
    }
  }, []);

  useEffect(() => {
    void load();
    return bus.on('personas:changed', () => void load());
  }, [load]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return personas;
    return personas.filter(
      (p) => p.name.toLowerCase().includes(q) || p.instructions.toLowerCase().includes(q)
    );
  }, [personas, search]);

  const openNew = () => setEditor({ ...EMPTY_EDITOR, open: true });

  const openEdit = (p: Persona) =>
    setEditor({
      open: true,
      id: p.id,
      name: p.name,
      emoji: p.emoji || '🧠',
      instructions: p.instructions,
      temperature: p.temperature ?? null,
      useDefaultModel: !p.modelId,
      runtimeId: p.runtimeId ?? 'assist',
      modelId: p.modelId ?? 'pocketllm-assist',
    });

  // Live deep links: palette selections while this view is already open.
  useDeepLink<Persona>(
    'persona',
    (id) => personas.find((p) => p.id === id),
    (p) => openEdit(p)
  );

  const save = async () => {
    if (!editor.name.trim() || !editor.instructions.trim()) {
      toast({
        title: 'Missing fields',
        description: 'A persona needs a name and instructions.',
        variant: 'destructive',
      });
      return;
    }
    const now = Date.now();
    const existing = editor.id ? await personaRepo.get(editor.id) : undefined;
    const persona: Persona = {
      id: editor.id ?? crypto.randomUUID(),
      name: editor.name.trim().slice(0, 80),
      emoji: editor.emoji,
      instructions: editor.instructions.trim().slice(0, 4000),
      temperature: editor.temperature ?? undefined,
      modelId: editor.useDefaultModel ? undefined : editor.modelId,
      runtimeId: editor.useDefaultModel ? undefined : editor.runtimeId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    };
    await personaRepo.put(persona);
    bus.emit('personas:changed');
    setEditor(EMPTY_EDITOR);
    toast({
      title: existing ? 'Persona updated' : 'Persona created',
      description: `${persona.emoji} ${persona.name} is ready to use in chats.`,
    });
  };

  const remove = async () => {
    if (!deleteTarget) return;
    await personaRepo.delete(deleteTarget.id);
    bus.emit('personas:changed');
    setDeleteTarget(null);
    toast({ title: 'Persona deleted', description: 'Existing chats keep their history.' });
  };

  const startChat = async (p: Persona) => {
    const chat = await chatService.createChat({
      personaId: p.id,
      title: `${p.emoji} ${p.name}`,
      ...(p.modelId && p.runtimeId ? { modelId: p.modelId, runtimeId: p.runtimeId } : {}),
    });
    router.navigate(`/app/chat/${chat.id}`);
  };

  const duplicate = async (p: Persona) => {
    const now = Date.now();
    await personaRepo.put({
      ...p,
      id: crypto.randomUUID(),
      name: `${p.name} (copy)`,
      createdAt: now,
      updatedAt: now,
    });
    bus.emit('personas:changed');
    toast({ title: 'Persona duplicated' });
  };

  const runtimeModels = models.filter((m) => m.runtimeId === editor.runtimeId);

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-4xl px-4 py-6 pb-24 sm:px-6">
        <PageHeader
          title="Personas"
          description="Custom assistants with their own instructions, temperature and model overrides."
          actions={
            <Button onClick={openNew}>
              <Plus className="h-4 w-4" /> New persona
            </Button>
          }
        />

        {/* Search */}
        <div className="relative mb-4">
          <Search className="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-muted-foreground" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search personas"
            aria-label="Search personas"
            className="w-full rounded-lg border border-border bg-card py-2 pl-8 pr-3 text-[13px] outline-none focus:border-brand-strong sm:w-80"
          />
        </div>

        {/* Grid */}
        {loading ? (
          <div className="grid gap-3 sm:grid-cols-2">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="h-36 animate-pulse rounded-xl bg-muted" />
            ))}
          </div>
        ) : filtered.length === 0 ? (
          <EmptyState
            icon={Sparkles}
            title={search ? 'No matching personas' : 'No personas yet'}
            description={
              search
                ? 'Try a different search.'
                : 'Personas layer custom instructions into every chat where they are selected — a terse code reviewer, a patient tutor, anything you define.'
            }
            action={
              !search && (
                <Button onClick={openNew}>
                  <Plus className="h-4 w-4" /> Create your first persona
                </Button>
              )
            }
          />
        ) : (
          <ul className="grid gap-3 sm:grid-cols-2">
            {filtered.map((p) => (
              <li
                key={p.id}
                className="group flex flex-col rounded-xl border border-border bg-card p-4 transition-all hover:border-brand-strong hover:shadow-md"
              >
                <div className="flex items-start gap-3">
                  <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-muted text-xl" aria-hidden>
                    {p.emoji}
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <h3 className="truncate text-[15px] font-semibold">{p.name}</h3>
                      {p.temperature != null && (
                        <MetaPill>temp {p.temperature.toFixed(1)}</MetaPill>
                      )}
                    </div>
                    <p className="mt-1 line-clamp-2 text-[13px] text-muted-foreground">
                      {p.instructions}
                    </p>
                  </div>
                </div>
                <div className="mt-3 flex items-center gap-1 border-t border-border pt-3 opacity-0 transition-opacity focus-within:opacity-100 group-hover:opacity-100">
                  <span className="mr-auto text-[11px] text-muted-foreground/60">
                    {p.modelId ? `Model: ${p.modelId}` : 'Default model'} · updated {formatRelativeTime(p.updatedAt)}
                  </span>
                  <IconAction label="Start chat with this persona" onClick={() => void startChat(p)}>
                    <MessageSquarePlus className="h-4 w-4" />
                  </IconAction>
                  <IconAction label="Duplicate persona" onClick={() => void duplicate(p)}>
                    <Copy className="h-4 w-4" />
                  </IconAction>
                  <IconAction label="Edit persona" onClick={() => openEdit(p)}>
                    <Pencil className="h-4 w-4" />
                  </IconAction>
                  <IconAction label="Delete persona" danger onClick={() => setDeleteTarget(p)}>
                    <Trash2 className="h-4 w-4" />
                  </IconAction>
                </div>
              </li>
            ))}
          </ul>
        )}

        <Section className="mt-6" title="How personas compose">
          <p className="text-[13px] leading-relaxed text-muted-foreground">
            Every generation composes its system prompt in a fixed order:
            <span className="mx-1 rounded bg-muted px-1.5 py-0.5 font-mono text-[11px] text-foreground">
              base policy → persona → skills → memory → documents
            </span>
            A persona can also override the temperature and model for the chats that use it. Inspect
            the live composition in the Prompt Lab.
          </p>
        </Section>
      </div>

      {/* Editor dialog */}
      <Dialog open={editor.open} onOpenChange={(open) => !open && setEditor(EMPTY_EDITOR)}>
        <DialogContent className="max-h-[90dvh] overflow-y-auto scrollbar-slim sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>{editor.id ? 'Edit persona' : 'New persona'}</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div className="grid grid-cols-[1fr_auto] gap-3">
              <div className="space-y-1.5">
                <Label htmlFor="persona-name">Name</Label>
                <Input
                  id="persona-name"
                  value={editor.name}
                  onChange={(e) => setEditor((s) => ({ ...s, name: e.target.value }))}
                  placeholder="e.g. Terse code reviewer"
                  maxLength={80}
                />
              </div>
              <div className="space-y-1.5">
                <Label>Avatar</Label>
                <div className="flex h-9 w-14 items-center justify-center rounded-lg border bg-muted text-lg" aria-live="polite">
                  {editor.emoji}
                </div>
              </div>
            </div>
            <div>
              <Label className="mb-1.5 block">Pick an avatar</Label>
              <div className="flex flex-wrap gap-1.5" role="radiogroup" aria-label="Avatar emoji">
                {EMOJI_CHOICES.map((e) => (
                  <button
                    key={e}
                    role="radio"
                    aria-checked={editor.emoji === e}
                    onClick={() => setEditor((s) => ({ ...s, emoji: e }))}
                    className={cn(
                      'h-9 w-9 rounded-lg border text-lg transition-colors',
                      editor.emoji === e
                        ? 'border-brand-strong bg-brand/30'
                        : 'border-border bg-background hover:bg-muted'
                    )}
                  >
                    {e}
                  </button>
                ))}
              </div>
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="persona-instructions">Instructions</Label>
              <textarea
                id="persona-instructions"
                value={editor.instructions}
                onChange={(e) => setEditor((s) => ({ ...s, instructions: e.target.value }))}
                placeholder="Describe how this assistant should behave, its tone and constraints…"
                className="min-h-[110px] w-full resize-y rounded-lg border border-border bg-background p-3 text-sm outline-none focus:border-brand-strong"
                maxLength={4000}
              />
            </div>
            <div>
              <div className="mb-2 flex items-center justify-between">
                <Label>Temperature override</Label>
                <span className="font-mono text-xs text-muted-foreground">
                  {editor.temperature == null ? 'default' : editor.temperature.toFixed(2)}
                </span>
              </div>
              <Slider
                value={[editor.temperature ?? 0.7]}
                min={0}
                max={2}
                step={0.05}
                onValueChange={([v]) => setEditor((s) => ({ ...s, temperature: v }))}
                aria-label="Temperature override"
              />
              <div className="mt-1.5 flex items-center justify-between text-[11px]">
                <span className="text-muted-foreground">0 = precise · 2 = creative</span>
                <button
                  className="text-muted-foreground underline hover:text-foreground"
                  onClick={() => setEditor((s) => ({ ...s, temperature: null }))}
                >
                  use default
                </button>
              </div>
            </div>
            <div className="rounded-xl border border-border p-3">
              <label className="flex cursor-pointer items-center gap-2 text-[13px]">
                <input
                  type="checkbox"
                  checked={editor.useDefaultModel}
                  onChange={(e) => setEditor((s) => ({ ...s, useDefaultModel: e.target.checked }))}
                  className="h-4 w-4 accent-[var(--brand-strong)]"
                />
                Use the chat&apos;s default model (recommended)
              </label>
              {!editor.useDefaultModel && (
                <div className="mt-3 grid grid-cols-2 gap-3">
                  <div className="space-y-1.5">
                    <Label htmlFor="persona-runtime">Runtime</Label>
                    <select
                      id="persona-runtime"
                      value={editor.runtimeId}
                      onChange={(e) => {
                        const rt = e.target.value as RuntimeId;
                        const first = models.find((m) => m.runtimeId === rt);
                        setEditor((s) => ({ ...s, runtimeId: rt, modelId: first?.id ?? s.modelId }));
                      }}
                      className="w-full rounded-lg border border-border bg-background p-2 text-[13px]"
                    >
                      <option value="assist">PocketLLM Assist</option>
                      <option value="ollama">Ollama</option>
                      <option value="openai">OpenAI-compatible</option>
                      <option value="mock">Offline Sandbox</option>
                    </select>
                  </div>
                  <div className="space-y-1.5">
                    <Label htmlFor="persona-model">Model</Label>
                    <select
                      id="persona-model"
                      value={editor.modelId}
                      onChange={(e) => setEditor((s) => ({ ...s, modelId: e.target.value }))}
                      className="w-full rounded-lg border border-border bg-background p-2 text-[13px]"
                    >
                      {runtimeModels.map((m) => (
                        <option key={m.id} value={m.id}>{m.label}</option>
                      ))}
                    </select>
                  </div>
                </div>
              )}
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditor(EMPTY_EDITOR)}>Cancel</Button>
            <Button onClick={() => void save()}>
              {editor.id ? 'Save changes' : 'Create persona'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete confirm */}
      <AlertDialog open={!!deleteTarget} onOpenChange={(open) => !open && setDeleteTarget(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete “{deleteTarget?.name}”?</AlertDialogTitle>
            <AlertDialogDescription>
              This removes the persona definition. Existing chats keep their history but stop
              applying these instructions on new messages.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-white hover:bg-destructive/90"
              onClick={() => void remove()}
            >
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

function IconAction({
  label,
  onClick,
  children,
  danger,
}: {
  label: string;
  onClick: () => void;
  children: React.ReactNode;
  danger?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      title={label}
      aria-label={label}
      className={cn(
        'rounded-lg p-1.5 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground',
        danger && 'hover:text-destructive'
      )}
    >
      {children}
    </button>
  );
}
