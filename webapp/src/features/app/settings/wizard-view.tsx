'use client';

/**
 * WizardView — first-run setup. Three steps: welcome + privacy
 * promise, runtime choice (Assist / Ollama / OpenAI-compatible /
 * skip with honest connection tests), then persistence + finish.
 * Never a trap: Skip is available on every step.
 */
import { useState } from 'react';
import {
  ArrowLeft,
  ArrowRight,
  CheckCircle2,
  Clock,
  Loader2,
  Plug,
  Server,
  ShieldCheck,
  XCircle,
  Zap,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { providerRepo } from '@/lib/core/db/repositories';
import { bus } from '@/lib/core/events/event-bus';
import { router } from '@/lib/core/router';
import { capabilityProbe } from '@/lib/core/net/capabilities';
import { inferenceRouter } from '@/lib/services/inference/inference-router';
import { OllamaRuntime } from '@/lib/services/inference/ollama-runtime';
import { OpenAICompatibleRuntime } from '@/lib/services/inference/openai-runtime';
import type { ConnectionTestResult } from '@/lib/services/inference/runtime';
import { useAppStore } from '@/lib/store/app-store';
import { toast } from '@/hooks/use-toast';
import { cn, uuid } from '@/lib/utils';
import type { Provider, RuntimeId } from '@/lib/types/domain';

type WizardChoice = 'assist' | 'ollama' | 'openai' | 'skip';

const CHOICE_CARDS: Array<{
  id: WizardChoice;
  title: string;
  blurb: string;
  icon: React.ComponentType<{ className?: string }>;
}> = [
  {
    id: 'assist',
    title: 'PocketLLM Assist',
    blurb: 'Built-in, works everywhere, needs network.',
    icon: Zap,
  },
  {
    id: 'ollama',
    title: 'Ollama',
    blurb: 'Use models on your computer (localhost:11434).',
    icon: Server,
  },
  {
    id: 'openai',
    title: 'OpenAI-compatible',
    blurb: 'Connect an endpoint you control.',
    icon: Plug,
  },
  {
    id: 'skip',
    title: 'Configure later',
    blurb: 'Pick a runtime any time in Providers.',
    icon: Clock,
  },
];

const CHOICE_SUMMARY: Record<WizardChoice, string> = {
  assist: 'PocketLLM Assist — the built-in runtime. It needs the network; Strict Offline pauses it.',
  ollama: 'Ollama — your local server on this machine. Keep Ollama running when you chat.',
  openai: 'OpenAI-compatible — an endpoint you control. Its API key stays in memory for the session.',
  skip: 'Nothing chosen yet — the app falls back to its defaults until you pick a runtime in Providers.',
};

const WELCOME_BULLETS = [
  'Chats, memories, documents and models live in this browser — IndexedDB and OPFS, not a cloud database.',
  'No account, no signup, no email address.',
  'Strict Offline can block every internet request; the Network page shows what was allowed or blocked.',
  'Export an encrypted .pllm backup whenever you want.',
];

function ResultPanel({ result }: { result: ConnectionTestResult }) {
  return (
    <div
      role="status"
      className={cn(
        'rounded-xl border p-3',
        result.ok
          ? 'border-success/40 bg-success/10'
          : 'border-destructive/40 bg-destructive/10'
      )}
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

export function WizardView() {
  const patchSettings = useAppStore((s) => s.patchSettings);

  const [step, setStep] = useState(0);

  /* step 2 — runtime choice + connection config */
  const [choice, setChoice] = useState<WizardChoice>('assist');
  const [ollamaUrl, setOllamaUrl] = useState('http://127.0.0.1:11434');
  const [ollamaModel, setOllamaModel] = useState('');
  const [openaiName, setOpenaiName] = useState('My endpoint');
  const [openaiUrl, setOpenaiUrl] = useState('');
  const [openaiKey, setOpenaiKey] = useState('');
  const [openaiModel, setOpenaiModel] = useState('');
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<ConnectionTestResult | null>(null);

  /* step 3 — persistence + finish */
  const [persistence, setPersistence] = useState<'idle' | 'granted' | 'denied'>('idle');
  const [finishing, setFinishing] = useState(false);

  const pickChoice = (id: WizardChoice) => {
    setChoice(id);
    setTestResult(null);
  };

  const runTest = async () => {
    setTesting(true);
    setTestResult(null);
    try {
      // Point the shared runtime at the values typed here (they aren't
      // persisted yet), test, then restore the persisted configuration.
      if (choice === 'ollama') {
        (inferenceRouter.get('ollama') as OllamaRuntime).configure(
          ollamaUrl.trim() || 'http://127.0.0.1:11434',
          ollamaModel.trim()
        );
      } else if (choice === 'openai') {
        (inferenceRouter.get('openai') as OpenAICompatibleRuntime).configure(
          openaiUrl.trim(),
          openaiKey,
          openaiModel.trim()
        );
      }
      const result = await inferenceRouter.get(choice as RuntimeId).testConnection();
      setTestResult(result);
      await inferenceRouter.syncProviders();
    } catch (err) {
      setTestResult({
        ok: false,
        message: err instanceof Error ? err.message : String(err),
      });
    } finally {
      setTesting(false);
    }
  };

  const requestPersistence = async () => {
    try {
      const granted = await capabilityProbe.requestPersistence();
      setPersistence(granted ? 'granted' : 'denied');
    } catch {
      setPersistence('denied');
    }
  };

  const saveProvider = async () => {
    const now = Date.now();
    const type = choice as 'ollama' | 'openai-compatible';
    const existing = (await providerRepo.getAll()).find((p) => p.type === type);
    const provider: Provider = existing
      ? {
          ...existing,
          name: choice === 'ollama' ? existing.name || 'My Ollama' : openaiName.trim() || existing.name,
          baseUrl: (choice === 'ollama' ? ollamaUrl : openaiUrl).trim(),
          modelId: (choice === 'ollama' ? ollamaModel : openaiModel).trim(),
          updatedAt: now,
        }
      : {
          id: uuid(),
          type,
          name:
            choice === 'ollama'
              ? 'My Ollama'
              : openaiName.trim() || 'My endpoint',
          baseUrl: (choice === 'ollama' ? ollamaUrl : openaiUrl).trim(),
          modelId: (choice === 'ollama' ? ollamaModel : openaiModel).trim(),
          apiKey: choice === 'openai' ? openaiKey : undefined,
          apiKeyStorage: 'none',
          capabilities: { text: true, vision: false, embeddings: false, tools: false },
          createdAt: now,
          updatedAt: now,
        };
    await providerRepo.put(provider);
    bus.emit('providers:changed');
    await inferenceRouter.syncProviders();
  };

  const finish = async () => {
    setFinishing(true);
    if (choice === 'ollama' || choice === 'openai') {
      try {
        await saveProvider();
      } catch (err) {
        // Never trap the user in the wizard — surface the failure honestly.
        toast({
          title: 'Could not save the provider',
          description: `${err instanceof Error ? err.message : String(err)} You can add it again in Providers.`,
          variant: 'destructive',
        });
      }
    }
    const patch: Record<string, unknown> = { meta: { setupCompleted: true } };
    if (choice !== 'skip') patch.chat = { defaultRuntimeId: choice };
    patchSettings(patch);
    router.navigate('/app');
  };

  return (
    <div className="flex flex-1 items-center justify-center overflow-y-auto scrollbar-slim px-4 py-8">
      <div className="w-full max-w-lg">
        <div className="rounded-2xl border border-border bg-card p-6 shadow-sm sm:p-8">
          {/* ---------------------------- progress --------------------------- */}
          <div className="mb-6">
            <div className="flex items-center justify-center gap-2" aria-hidden>
              {[0, 1, 2].map((i) => (
                <span
                  key={i}
                  className={cn(
                    'h-1.5 rounded-full transition-colors',
                    i <= step ? 'w-8 bg-brand-strong' : 'w-8 bg-muted'
                  )}
                />
              ))}
            </div>
            <p className="mt-2 text-center text-xs text-muted-foreground">
              Step {step + 1} of 3
            </p>
          </div>

          {/* ----------------------------- step 1 ---------------------------- */}
          {step === 0 && (
            <div>
              <div className="flex flex-col items-center text-center">
                { }
                <img
                  src="/logo.png"
                  alt=""
                  className="h-14 w-14 rounded-2xl border border-border"
                />
                <h1 className="mt-4 font-display text-2xl font-semibold tracking-tight">
                  Welcome to PocketLLM
                </h1>
                <p className="mt-1.5 text-[15px] leading-relaxed text-muted-foreground">
                  Your chats stay on this device. No account. No cloud
                  database. No signup.
                </p>
              </div>
              <ul className="mt-6 space-y-2.5">
                {WELCOME_BULLETS.map((bullet) => (
                  <li key={bullet} className="flex items-start gap-2.5">
                    <ShieldCheck
                      className="mt-0.5 h-4 w-4 shrink-0 text-success"
                      aria-hidden
                    />
                    <span className="text-[13px] leading-relaxed">{bullet}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* ----------------------------- step 2 ---------------------------- */}
          {step === 1 && (
            <div>
              <h1 className="font-display text-xl font-semibold tracking-tight">
                Choose how AI should run
              </h1>
              <p className="mt-1 text-[13px] leading-relaxed text-muted-foreground">
                You can change this any time — nothing is permanent.
              </p>

              <div
                role="radiogroup"
                aria-label="Runtime choice"
                className="mt-4 grid gap-2.5 sm:grid-cols-2"
              >
                {CHOICE_CARDS.map((card) => {
                  const active = choice === card.id;
                  return (
                    <button
                      key={card.id}
                      type="button"
                      role="radio"
                      aria-checked={active}
                      onClick={() => pickChoice(card.id)}
                      className={cn(
                        'flex flex-col items-start gap-1.5 rounded-xl border p-3.5 text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
                        active
                          ? 'border-brand-strong bg-brand/10'
                          : 'border-border hover:bg-muted/50'
                      )}
                    >
                      <span className="flex items-center gap-2 text-sm font-medium">
                        <card.icon
                          className={cn(
                            'h-4 w-4',
                            active ? 'text-brand-strong' : 'text-muted-foreground'
                          )}
                          aria-hidden
                        />
                        {card.title}
                      </span>
                      <span className="text-xs leading-relaxed text-muted-foreground">
                        {card.blurb}
                      </span>
                    </button>
                  );
                })}
              </div>

              {choice === 'ollama' && (
                <div className="mt-4 space-y-3 rounded-xl border border-border bg-background/50 p-4">
                  <p className="text-xs leading-relaxed text-muted-foreground">
                    Install Ollama on your computer and run{' '}
                    <code className="rounded bg-muted px-1 py-0.5 font-mono text-[11px]">
                      ollama serve
                    </code>
                    , then test it here.
                  </p>
                  <div>
                    <Label htmlFor="wizard-ollama-url" className="text-[13px] font-medium">
                      Base URL
                    </Label>
                    <Input
                      id="wizard-ollama-url"
                      value={ollamaUrl}
                      onChange={(e) => {
                        setOllamaUrl(e.target.value);
                        setTestResult(null);
                      }}
                      placeholder="http://127.0.0.1:11434"
                      className="mt-1.5 font-mono text-xs"
                    />
                  </div>
                  <div>
                    <Label htmlFor="wizard-ollama-model" className="text-[13px] font-medium">
                      Model <span className="font-normal text-muted-foreground">(optional)</span>
                    </Label>
                    <Input
                      id="wizard-ollama-model"
                      value={ollamaModel}
                      onChange={(e) => {
                        setOllamaModel(e.target.value);
                        setTestResult(null);
                      }}
                      placeholder="e.g. llama3.2"
                      className="mt-1.5 font-mono text-xs"
                    />
                  </div>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => void runTest()}
                    disabled={testing}
                  >
                    {testing ? (
                      <Loader2 className="animate-spin" aria-hidden />
                    ) : null}
                    Test connection
                  </Button>
                  {testResult && <ResultPanel result={testResult} />}
                </div>
              )}

              {choice === 'openai' && (
                <div className="mt-4 space-y-3 rounded-xl border border-border bg-background/50 p-4">
                  <p className="text-xs leading-relaxed text-muted-foreground">
                    LM Studio, vLLM, llama.cpp server — or any OpenAI-style API
                    you trust. The key is kept in memory for this session only.
                  </p>
                  <div className="grid gap-3 sm:grid-cols-2">
                    <div>
                      <Label htmlFor="wizard-openai-name" className="text-[13px] font-medium">
                        Name
                      </Label>
                      <Input
                        id="wizard-openai-name"
                        value={openaiName}
                        onChange={(e) => setOpenaiName(e.target.value)}
                        className="mt-1.5"
                      />
                    </div>
                    <div>
                      <Label htmlFor="wizard-openai-model" className="text-[13px] font-medium">
                        Model ID
                      </Label>
                      <Input
                        id="wizard-openai-model"
                        value={openaiModel}
                        onChange={(e) => {
                          setOpenaiModel(e.target.value);
                          setTestResult(null);
                        }}
                        placeholder="e.g. qwen2.5-7b-instruct"
                        className="mt-1.5 font-mono text-xs"
                      />
                    </div>
                  </div>
                  <div>
                    <Label htmlFor="wizard-openai-url" className="text-[13px] font-medium">
                      Base URL
                    </Label>
                    <Input
                      id="wizard-openai-url"
                      value={openaiUrl}
                      onChange={(e) => {
                        setOpenaiUrl(e.target.value);
                        setTestResult(null);
                      }}
                      placeholder="http://localhost:1234/v1"
                      className="mt-1.5 font-mono text-xs"
                    />
                  </div>
                  <div>
                    <Label htmlFor="wizard-openai-key" className="text-[13px] font-medium">
                      API key
                    </Label>
                    <Input
                      id="wizard-openai-key"
                      type="password"
                      value={openaiKey}
                      onChange={(e) => {
                        setOpenaiKey(e.target.value);
                        setTestResult(null);
                      }}
                      autoComplete="off"
                      className="mt-1.5"
                    />
                  </div>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => void runTest()}
                    disabled={testing || !openaiUrl.trim()}
                  >
                    {testing ? (
                      <Loader2 className="animate-spin" aria-hidden />
                    ) : null}
                    Test connection
                  </Button>
                  {testResult && <ResultPanel result={testResult} />}
                </div>
              )}

              {choice === 'skip' && (
                <p className="mt-4 rounded-xl border border-border bg-background/50 p-4 text-xs leading-relaxed text-muted-foreground">
                  The app starts with PocketLLM Assist as its default runtime.
                  You can switch runtimes per chat and add providers any time on
                  the Providers page.
                </p>
              )}
            </div>
          )}

          {/* ----------------------------- step 3 ---------------------------- */}
          {step === 2 && (
            <div>
              <h1 className="font-display text-xl font-semibold tracking-tight">
                Ready when you are
              </h1>
              <p className="mt-1 text-[13px] leading-relaxed text-muted-foreground">
                One last thing — ask the browser not to evict your data.
              </p>

              <div className="mt-4 rounded-xl border border-border bg-background/50 p-4">
                <h2 className="text-[13px] font-semibold">Your choice</h2>
                <p className="mt-1 text-[13px] leading-relaxed text-muted-foreground">
                  {CHOICE_SUMMARY[choice]}
                </p>
                {choice === 'ollama' && (
                  <p className="mt-1.5 font-mono text-xs text-muted-foreground">
                    {ollamaUrl.trim() || 'http://127.0.0.1:11434'}
                    {ollamaModel.trim() ? ` · ${ollamaModel.trim()}` : ''}
                  </p>
                )}
                {choice === 'openai' && (
                  <p className="mt-1.5 font-mono text-xs text-muted-foreground">
                    {openaiUrl.trim() || '(no URL entered)'}
                    {openaiModel.trim() ? ` · ${openaiModel.trim()}` : ''}
                  </p>
                )}
              </div>

              <div className="mt-3 rounded-xl border border-border bg-background/50 p-4">
                <h2 className="text-[13px] font-semibold">Persistent storage</h2>
                <p className="mt-1 text-[13px] leading-relaxed text-muted-foreground">
                  Without it, browsers may delete stored data under disk
                  pressure. With it, PocketLLM&apos;s local data is marked
                  durable.
                </p>
                <div className="mt-3 flex flex-wrap items-center gap-3">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => void requestPersistence()}
                    disabled={persistence === 'granted'}
                  >
                    Request persistent storage
                  </Button>
                  {persistence === 'granted' && (
                    <span className="inline-flex items-center gap-1.5 text-xs font-medium text-success">
                      <CheckCircle2 className="h-3.5 w-3.5" aria-hidden />
                      Granted — data won&apos;t be evicted lightly
                    </span>
                  )}
                  {persistence === 'denied' && (
                    <span className="inline-flex items-center gap-1.5 text-xs text-warning">
                      <XCircle className="h-3.5 w-3.5" aria-hidden />
                      Not granted — export backups if this data matters
                    </span>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* ------------------------------ footer --------------------------- */}
          <div className="mt-6 flex items-center justify-between gap-3 border-t border-border pt-4">
            <div>
              {step > 0 && (
                <Button variant="ghost" onClick={() => setStep((s) => s - 1)}>
                  <ArrowLeft aria-hidden />
                  Back
                </Button>
              )}
              {step === 0 && (
                <Button
                  variant="ghost"
                  onClick={() => {
                    pickChoice('skip');
                    setStep(2);
                  }}
                >
                  Skip setup
                </Button>
              )}
            </div>
            {step < 2 ? (
              <Button onClick={() => setStep((s) => s + 1)}>
                {step === 0 ? 'Get started' : 'Continue'}
                <ArrowRight aria-hidden />
              </Button>
            ) : (
              <Button onClick={() => void finish()} disabled={finishing}>
                {finishing ? (
                  <Loader2 className="animate-spin" aria-hidden />
                ) : null}
                Open the app
              </Button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
