'use client';

/**
 * ProvidersView — connect runtimes you control.
 *
 * Two provider families: Ollama (local server) and OpenAI-compatible
 * endpoints. Every action is explicit: PocketLLM never shares anything
 * without the user pressing a button. Connection tests surface the
 * layered diagnostics from the runtime verbatim.
 */
import { useCallback, useEffect, useState } from 'react';
import {
  CheckCircle2,
  Loader2,
  Pencil,
  Plug,
  Plus,
  RefreshCw,
  Server,
  ShieldCheck,
  Trash2,
  TriangleAlert,
  XCircle,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
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
import { PageHeader, Section, StatusDot } from '@/features/app/shared/ui';
import { providerRepo } from '@/lib/core/db/repositories';
import { bus } from '@/lib/core/events/event-bus';
import { router } from '@/lib/core/router';
import { useAppStore } from '@/lib/store/app-store';
import { inferenceRouter } from '@/lib/services/inference/inference-router';
import { OllamaRuntime } from '@/lib/services/inference/ollama-runtime';
import { OpenAICompatibleRuntime } from '@/lib/services/inference/openai-runtime';
import type { ConnectionTestResult } from '@/lib/services/inference/runtime';
import { formatRelativeTime, uuid } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';
import type { Provider, ProviderCapabilities } from '@/lib/types/domain';

/* ------------------------------- helpers ------------------------------ */

function StatusBadge({ status }: { status?: Provider['lastStatus'] }) {
  if (!status || status === 'untested')
    return <StatusDot tone="neutral">untested</StatusDot>;
  if (status === 'connected')
    return <StatusDot tone="success">connected</StatusDot>;
  return <StatusDot tone="error">unreachable</StatusDot>;
}

function ResultPanel({ result }: { result: ConnectionTestResult }) {
  return (
    <div
      role="status"
      className={result.ok ? 'rounded-xl border border-success/40 bg-success/10 p-3' : 'rounded-xl border border-destructive/40 bg-destructive/10 p-3'}
    >
      <p className="flex items-start gap-2 text-[13px] font-medium">
        {result.ok ? (
          <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-success" aria-hidden />
        ) : (
          <XCircle className="mt-0.5 h-4 w-4 shrink-0 text-destructive" aria-hidden />
        )}
        {result.message}
      </p>
      {result.detail && (
        <p className="mt-1.5 pl-6 text-xs leading-relaxed text-muted-foreground">
          {result.detail}
        </p>
      )}
    </div>
  );
}

function ProviderRowActions({
  provider,
  testing,
  onTest,
  onEdit,
  onDelete,
}: {
  provider: Provider;
  testing: boolean;
  onTest: () => void;
  onEdit: () => void;
  onDelete: () => void;
}) {
  return (
    <div className="flex shrink-0 items-center gap-1">
      <Button
        variant="outline"
        size="sm"
        onClick={onTest}
        disabled={testing}
        aria-label={`Test connection to ${provider.name}`}
      >
        {testing ? (
          <Loader2 className="animate-spin" aria-hidden />
        ) : (
          <RefreshCw aria-hidden />
        )}
        Test
      </Button>
      <Button
        variant="ghost"
        size="icon"
        onClick={onEdit}
        aria-label={`Edit ${provider.name}`}
      >
        <Pencil aria-hidden />
      </Button>
      <Button
        variant="ghost"
        size="icon"
        className="text-muted-foreground hover:text-destructive"
        onClick={onDelete}
        aria-label={`Delete ${provider.name}`}
      >
        <Trash2 aria-hidden />
      </Button>
    </div>
  );
}

/* ------------------------------ main view ----------------------------- */

export function ProvidersView() {
  const strictOffline = useAppStore((s) => s.settings.privacy.strictOffline);

  const [providers, setProviders] = useState<Provider[] | null>(null);
  const [testingId, setTestingId] = useState<string | null>(null);
  const [results, setResults] = useState<Record<string, ConnectionTestResult>>({});
  const [deleting, setDeleting] = useState<Provider | null>(null);

  const refresh = useCallback(async () => {
    try {
      const all = await providerRepo.getAll();
      setProviders(all.sort((a, b) => a.createdAt - b.createdAt));
    } catch (err) {
      console.error('[providers] load failed', err);
      setProviders([]);
    }
  }, []);

  useEffect(() => {
    void refresh();
    const un = bus.on('providers:changed', () => void refresh());
    return () => un();
  }, [refresh]);

  /* --------------------------- test & delete -------------------------- */

  const testProvider = useCallback(async (p: Provider) => {
    setTestingId(p.id);
    try {
      if (p.type === 'ollama') {
        // The router syncs the first provider of a type; for a per-provider
        // test we point the runtime at this provider explicitly.
        (inferenceRouter.get('ollama') as OllamaRuntime).configure(
          p.baseUrl,
          p.modelId
        );
      } else {
        (inferenceRouter.get('openai') as OpenAICompatibleRuntime).configure(
          p.baseUrl,
          p.apiKey ?? '',
          p.modelId
        );
      }
      const runtime = inferenceRouter.get(p.type === 'ollama' ? 'ollama' : 'openai');
      const result = await runtime.testConnection();
      setResults((r) => ({ ...r, [p.id]: result }));
      await providerRepo.put({
        ...p,
        lastTestedAt: Date.now(),
        lastStatus: result.ok ? 'connected' : 'unreachable',
        updatedAt: Date.now(),
      });
      bus.emit('providers:changed');
      await inferenceRouter.syncProviders(); // restore shared runtime config
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setResults((r) => ({
        ...r,
        [p.id]: { ok: false, message },
      }));
    } finally {
      setTestingId(null);
    }
  }, []);

  const confirmDelete = useCallback(async () => {
    if (!deleting) return;
    const target = deleting;
    setDeleting(null);
    try {
      await providerRepo.delete(target.id);
      bus.emit('providers:changed');
      await inferenceRouter.syncProviders();
      toast({
        title: 'Provider removed',
        description: `${target.name} is no longer connected.`,
      });
    } catch (err) {
      toast({
        title: 'Delete failed',
        description: err instanceof Error ? err.message : String(err),
        variant: 'destructive',
      });
    }
  }, [deleting]);

  const ollamaProviders = providers?.filter((p) => p.type === 'ollama') ?? [];
  const openaiProviders = providers?.filter((p) => p.type === 'openai-compatible') ?? [];

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-4xl px-4 pb-24 pt-6 sm:px-6">
        <PageHeader
          title="Providers"
          description="Connect runtimes you control. Nothing is shared without your action."
        />

        {strictOffline && (
          <Section className="mb-6">
            <div className="flex gap-3">
              <TriangleAlert
                className="mt-0.5 h-5 w-5 shrink-0 text-warning"
                aria-hidden
              />
              <div>
                <h2 className="text-[15px] font-semibold">
                  Strict Offline is enabled
                </h2>
                <p className="mt-1 text-[13px] leading-relaxed text-muted-foreground">
                  Network policy currently blocks internet endpoints, so
                  OpenAI-compatible providers can&apos;t be tested or used.
                  Loopback connections to Ollama on this machine remain allowed
                  while loopback access is on. Adjust this in Settings →
                  Privacy.
                </p>
              </div>
            </div>
          </Section>
        )}

        <OllamaSection
          providers={ollamaProviders}
          loading={providers === null}
          results={results}
          testingId={testingId}
          onTest={(p) => void testProvider(p)}
          onDelete={setDeleting}
          onSaved={() => void refresh()}
        />

        <OpenAISection
          providers={openaiProviders}
          loading={providers === null}
          results={results}
          testingId={testingId}
          onTest={(p) => void testProvider(p)}
          onDelete={setDeleting}
          onSaved={() => void refresh()}
        />

        <Section>
          <div className="flex gap-3">
            <ShieldCheck
              className="mt-0.5 h-5 w-5 shrink-0 text-muted-foreground"
              aria-hidden
            />
            <p className="text-[13px] leading-relaxed text-muted-foreground">
              API keys are kept for this session in memory only — the browser
              has no secure keychain. Everything else (names, URLs, model
              choices) is stored locally in this browser. Delete a provider any
              time; PocketLLM keeps working without any.
            </p>
          </div>
        </Section>
      </div>

      <AlertDialog
        open={deleting !== null}
        onOpenChange={(open) => !open && setDeleting(null)}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete {deleting?.name}?</AlertDialogTitle>
            <AlertDialogDescription>
              This removes the provider record from this browser. No data is
              sent anywhere, and the server it pointed to is untouched.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Keep it</AlertDialogCancel>
            <AlertDialogAction
              className="bg-destructive text-white hover:bg-destructive/90"
              onClick={() => void confirmDelete()}
            >
              Delete provider
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

/* ---------------------------- ollama section --------------------------- */

function OllamaSection({
  providers,
  loading,
  results,
  testingId,
  onTest,
  onDelete,
  onSaved,
}: {
  providers: Provider[];
  loading: boolean;
  results: Record<string, ConnectionTestResult>;
  testingId: string | null;
  onTest: (p: Provider) => void;
  onDelete: (p: Provider) => void;
  onSaved: () => void;
}) {
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Provider | null>(null);
  const [name, setName] = useState('');
  const [baseUrl, setBaseUrl] = useState('');
  const [modelId, setModelId] = useState('');
  const [saving, setSaving] = useState(false);

  const openAdd = () => {
    setEditing(null);
    setName('My Ollama');
    setBaseUrl('http://127.0.0.1:11434');
    setModelId('');
    setOpen(true);
  };

  const openEdit = (p: Provider) => {
    setEditing(p);
    setName(p.name);
    setBaseUrl(p.baseUrl);
    setModelId(p.modelId);
    setOpen(true);
  };

  const save = async () => {
    setSaving(true);
    try {
      const now = Date.now();
      const provider: Provider = editing
        ? {
            ...editing,
            name: name.trim() || 'My Ollama',
            baseUrl: baseUrl.trim() || 'http://127.0.0.1:11434',
            modelId: modelId.trim(),
            updatedAt: now,
          }
        : {
            id: uuid(),
            type: 'ollama',
            name: name.trim() || 'My Ollama',
            baseUrl: baseUrl.trim() || 'http://127.0.0.1:11434',
            modelId: modelId.trim(),
            apiKeyStorage: 'none',
            capabilities: { text: true, vision: false, embeddings: false, tools: false },
            createdAt: now,
            updatedAt: now,
          };
      await providerRepo.put(provider);
      bus.emit('providers:changed');
      await inferenceRouter.syncProviders();
      onSaved();
      setOpen(false);
      toast({ title: 'Provider saved', description: provider.name });
    } catch (err) {
      toast({
        title: 'Could not save provider',
        description: err instanceof Error ? err.message : String(err),
        variant: 'destructive',
      });
    } finally {
      setSaving(false);
    }
  };

  return (
    <Section
      className="mb-6"
      title="Ollama"
      description="Use models already installed on your machine through a local Ollama server. Nothing leaves your device."
    >
      <div className="mb-4 flex items-center justify-end">
        <Button size="sm" variant="outline" onClick={openAdd}>
          <Plus aria-hidden />
          Add Ollama
        </Button>
      </div>

      {loading ? (
        <p className="py-6 text-center text-sm text-muted-foreground">
          Loading providers…
        </p>
      ) : providers.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border px-6 py-10 text-center">
          <Server className="mx-auto h-6 w-6 text-muted-foreground" aria-hidden />
          <h3 className="mt-3 text-[15px] font-medium">No Ollama provider yet</h3>
          <p className="mx-auto mt-1 max-w-sm text-sm text-muted-foreground">
            Install Ollama on your computer, run{' '}
            <code className="rounded bg-muted px-1 py-0.5 font-mono text-xs">
              ollama serve
            </code>
            , then add it here.
          </p>
        </div>
      ) : (
        <ul className="space-y-3">
          {providers.map((p) => (
            <li
              key={p.id}
              className="rounded-xl border border-border bg-background/50 p-4"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <Server className="h-4 w-4 shrink-0 text-muted-foreground" aria-hidden />
                    <h3 className="text-sm font-semibold">{p.name}</h3>
                    <StatusBadge status={p.lastStatus} />
                  </div>
                  <p className="mt-1 truncate font-mono text-xs text-muted-foreground">
                    {p.baseUrl}
                  </p>
                  <p className="mt-0.5 text-xs text-muted-foreground">
                    {p.modelId ? (
                      <>model: <span className="font-mono">{p.modelId}</span></>
                    ) : (
                      'no model selected yet'
                    )}
                  </p>
                  <p className="mt-0.5 text-xs text-muted-foreground">
                    {p.lastTestedAt
                      ? `last tested ${formatRelativeTime(p.lastTestedAt)}`
                      : 'never tested'}
                  </p>
                </div>
                <ProviderRowActions
                  provider={p}
                  testing={testingId === p.id}
                  onTest={() => onTest(p)}
                  onEdit={() => openEdit(p)}
                  onDelete={() => onDelete(p)}
                />
              </div>
              {results[p.id] && <div className="mt-3"><ResultPanel result={results[p.id]} /></div>}
            </li>
          ))}
        </ul>
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="w-[calc(100%-2rem)] sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>
              {editing ? 'Edit Ollama provider' : 'Add Ollama provider'}
            </DialogTitle>
            <DialogDescription>
              Point PocketLLM at an Ollama server you control. The default
              works when Ollama runs on the same machine.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="ollama-name">Name</Label>
              <Input
                id="ollama-name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="My Ollama"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="ollama-url">Base URL</Label>
              <Input
                id="ollama-url"
                value={baseUrl}
                onChange={(e) => setBaseUrl(e.target.value)}
                placeholder="http://127.0.0.1:11434"
                inputMode="url"
                autoComplete="off"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="ollama-model">Model ID</Label>
              <Input
                id="ollama-model"
                value={modelId}
                onChange={(e) => setModelId(e.target.value)}
                placeholder="e.g. llama3.2"
                autoComplete="off"
              />
              <p className="text-xs text-muted-foreground">
                Run{' '}
                <code className="rounded bg-muted px-1 py-0.5 font-mono">
                  ollama pull llama3.2
                </code>{' '}
                to install models. Use &quot;Test&quot; to diagnose
                connectivity.
              </p>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => void save()} disabled={saving}>
              {saving && <Loader2 className="animate-spin" aria-hidden />}
              Save provider
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Section>
  );
}

/* ------------------------- openai-compatible -------------------------- */

function OpenAISection({
  providers,
  loading,
  results,
  testingId,
  onTest,
  onDelete,
  onSaved,
}: {
  providers: Provider[];
  loading: boolean;
  results: Record<string, ConnectionTestResult>;
  testingId: string | null;
  onTest: (p: Provider) => void;
  onDelete: (p: Provider) => void;
  onSaved: () => void;
}) {
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<Provider | null>(null);
  const [name, setName] = useState('');
  const [baseUrl, setBaseUrl] = useState('');
  const [apiKey, setApiKey] = useState('');
  const [modelId, setModelId] = useState('');
  const [caps, setCaps] = useState<ProviderCapabilities>({
    text: true,
    vision: false,
    embeddings: false,
    tools: false,
  });
  const [saving, setSaving] = useState(false);
  const [fetching, setFetching] = useState(false);
  const [fetched, setFetched] = useState<string[] | null>(null);

  const openAdd = () => {
    setEditing(null);
    setName('My OpenAI-compatible endpoint');
    setBaseUrl('');
    setApiKey('');
    setModelId('');
    setCaps({ text: true, vision: false, embeddings: false, tools: false });
    setFetched(null);
    setOpen(true);
  };

  const openEdit = (p: Provider) => {
    setEditing(p);
    setName(p.name);
    setBaseUrl(p.baseUrl);
    setApiKey(p.apiKey ?? '');
    setModelId(p.modelId);
    setCaps({ ...p.capabilities });
    setFetched(null);
    setOpen(true);
  };

  const buildProvider = (): Provider => {
    const now = Date.now();
    if (editing) {
      return {
        ...editing,
        name: name.trim() || 'OpenAI-compatible endpoint',
        baseUrl: baseUrl.trim().replace(/\/+$/, ''),
        apiKey: apiKey.trim() || undefined,
        apiKeyStorage: apiKey.trim() ? 'session' : 'none',
        modelId: modelId.trim(),
        capabilities: caps,
        updatedAt: now,
      };
    }
    return {
      id: uuid(),
      type: 'openai-compatible',
      name: name.trim() || 'OpenAI-compatible endpoint',
      baseUrl: baseUrl.trim().replace(/\/+$/, ''),
      apiKey: apiKey.trim() || undefined,
      apiKeyStorage: apiKey.trim() ? 'session' : 'none',
      modelId: modelId.trim(),
      capabilities: caps,
      createdAt: now,
      updatedAt: now,
    };
  };

  const save = async () => {
    if (!baseUrl.trim()) {
      toast({
        title: 'Base URL required',
        description: 'Enter the endpoint URL, e.g. http://127.0.0.1:1234.',
        variant: 'destructive',
      });
      return;
    }
    setSaving(true);
    try {
      const provider = buildProvider();
      await providerRepo.put(provider);
      bus.emit('providers:changed');
      await inferenceRouter.syncProviders();
      onSaved();
      setOpen(false);
      toast({ title: 'Provider saved', description: provider.name });
    } catch (err) {
      toast({
        title: 'Could not save provider',
        description: err instanceof Error ? err.message : String(err),
        variant: 'destructive',
      });
    } finally {
      setSaving(false);
    }
  };

  /** Saves the current form first (the runtime reads persisted config),
   *  then fetches the model list from the endpoint. */
  const fetchModels = async () => {
    if (!baseUrl.trim()) {
      toast({
        title: 'Base URL required',
        description: 'Enter and save a base URL before fetching models.',
        variant: 'destructive',
      });
      return;
    }
    setFetching(true);
    setFetched(null);
    try {
      const provider = buildProvider();
      await providerRepo.put(provider);
      setEditing(provider); // keep the same id for the eventual Save
      await inferenceRouter.syncProviders();
      const models = await inferenceRouter.get('openai').listModels();
      const ids = models.map((m) => m.id);
      setFetched(ids);
      if (ids.length === 0) {
        toast({
          title: 'No models returned',
          description:
            'Check the base URL, API key, and that the server is reachable — then retry.',
          variant: 'destructive',
        });
      } else {
        toast({ title: `Fetched ${ids.length} models` });
      }
    } catch (err) {
      toast({
        title: 'Fetch failed',
        description: err instanceof Error ? err.message : String(err),
        variant: 'destructive',
      });
    } finally {
      setFetching(false);
    }
  };

  return (
    <Section
      className="mb-6"
      title="OpenAI-compatible"
      description="LM Studio, vLLM, llama.cpp server or any OpenAI-style API you control."
    >
      <div className="mb-4 flex items-center justify-end">
        <Button size="sm" variant="outline" onClick={openAdd}>
          <Plus aria-hidden />
          Add endpoint
        </Button>
      </div>

      {loading ? (
        <p className="py-6 text-center text-sm text-muted-foreground">
          Loading providers…
        </p>
      ) : providers.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border px-6 py-10 text-center">
          <Plug className="mx-auto h-6 w-6 text-muted-foreground" aria-hidden />
          <h3 className="mt-3 text-[15px] font-medium">No endpoint yet</h3>
          <p className="mx-auto mt-1 max-w-sm text-sm text-muted-foreground">
            Add any OpenAI-compatible server you run or trust. Keys stay in
            memory for this session only.
          </p>
        </div>
      ) : (
        <ul className="space-y-3">
          {providers.map((p) => (
            <li
              key={p.id}
              className="rounded-xl border border-border bg-background/50 p-4"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <Plug className="h-4 w-4 shrink-0 text-muted-foreground" aria-hidden />
                    <h3 className="text-sm font-semibold">{p.name}</h3>
                    <StatusBadge status={p.lastStatus} />
                  </div>
                  <p className="mt-1 truncate font-mono text-xs text-muted-foreground">
                    {p.baseUrl}
                  </p>
                  <p className="mt-0.5 text-xs text-muted-foreground">
                    {p.modelId ? (
                      <>model: <span className="font-mono">{p.modelId}</span></>
                    ) : (
                      'no model selected yet'
                    )}
                  </p>
                  <p className="mt-0.5 text-xs text-muted-foreground">
                    {p.lastTestedAt
                      ? `last tested ${formatRelativeTime(p.lastTestedAt)}`
                      : 'never tested'}
                    {p.apiKey
                      ? ' · key held in memory for this session'
                      : ' · no API key'}
                  </p>
                </div>
                <ProviderRowActions
                  provider={p}
                  testing={testingId === p.id}
                  onTest={() => onTest(p)}
                  onEdit={() => openEdit(p)}
                  onDelete={() => onDelete(p)}
                />
              </div>
              {results[p.id] && <div className="mt-3"><ResultPanel result={results[p.id]} /></div>}
            </li>
          ))}
        </ul>
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="w-[calc(100%-2rem)] sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>
              {editing ? 'Edit endpoint' : 'Add OpenAI-compatible endpoint'}
            </DialogTitle>
            <DialogDescription>
              Configure an endpoint you control. Test the connection after
              saving.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="openai-name">Name</Label>
              <Input
                id="openai-name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="My OpenAI-compatible endpoint"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="openai-url">Base URL</Label>
              <Input
                id="openai-url"
                value={baseUrl}
                onChange={(e) => setBaseUrl(e.target.value)}
                placeholder="e.g. http://127.0.0.1:1234"
                inputMode="url"
                autoComplete="off"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="openai-key">API key (optional)</Label>
              <Input
                id="openai-key"
                type="password"
                value={apiKey}
                onChange={(e) => setApiKey(e.target.value)}
                placeholder="sk-…"
                autoComplete="new-password"
              />
              <p className="text-xs text-muted-foreground">
                Kept for this session in memory only — the browser has no
                secure keychain. Never paste production keys you can&apos;t
                rotate.
              </p>
            </div>
            <div className="space-y-2">
              <Label htmlFor="openai-model">Model ID</Label>
              <div className="flex gap-2">
                <Input
                  id="openai-model"
                  value={modelId}
                  onChange={(e) => setModelId(e.target.value)}
                  placeholder="type it, or fetch the list"
                  autoComplete="off"
                />
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => void fetchModels()}
                  disabled={fetching}
                  aria-label="Fetch model list from the endpoint"
                >
                  {fetching ? (
                    <Loader2 className="animate-spin" aria-hidden />
                  ) : (
                    <RefreshCw aria-hidden />
                  )}
                  Fetch models
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                Fetching saves this form first, then asks the endpoint for its
                model list.
              </p>
              {fetched && fetched.length > 0 && (
                <div
                  className="flex max-h-32 flex-wrap gap-1.5 overflow-y-auto scrollbar-slim pt-1"
                  aria-label="Fetched models"
                >
                  {fetched.map((id) => (
                    <button
                      key={id}
                      type="button"
                      onClick={() => setModelId(id)}
                      className={
                        modelId === id
                          ? 'rounded-full bg-brand px-2.5 py-1 font-mono text-[11px] text-brand-foreground'
                          : 'rounded-full bg-muted px-2.5 py-1 font-mono text-[11px] text-muted-foreground hover:text-foreground'
                      }
                      aria-pressed={modelId === id}
                    >
                      {id}
                    </button>
                  ))}
                </div>
              )}
            </div>
            <fieldset className="space-y-2">
              <legend className="text-sm font-medium">
                Capabilities
              </legend>
              <p className="text-xs text-muted-foreground">
                Only mark capabilities you have verified yourself.
              </p>
              <div className="grid grid-cols-2 gap-2">
                {(
                  [
                    ['text', 'Text'],
                    ['vision', 'Vision'],
                    ['embeddings', 'Embeddings'],
                    ['tools', 'Tools'],
                  ] as const
                ).map(([key, label]) => (
                  <label
                    key={key}
                    className="flex cursor-pointer items-center gap-2 rounded-lg border border-border px-3 py-2 text-sm outline-none focus-within:ring-2 focus-within:ring-ring"
                  >
                    <Checkbox
                      checked={caps[key]}
                      onCheckedChange={(v) =>
                        setCaps((c) => ({ ...c, [key]: v === true }))
                      }
                      aria-label={`${label} capability`}
                    />
                    {label}
                  </label>
                ))}
              </div>
            </fieldset>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => void save()} disabled={saving}>
              {saving && <Loader2 className="animate-spin" aria-hidden />}
              Save provider
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Section>
  );
}
