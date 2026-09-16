'use client';

/**
 * HomeView — the app's welcome screen.
 *
 * Design cues from the reference set: time-of-day greeting, a centered
 * pill composer, suggestion chips, and recent-chat cards — executed
 * in PocketLLM's own minimal brand (sandy accent, neutral surfaces).
 */
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Plus,
  Mic,
  Paperclip,
  ArrowUp,
  Sparkles,
  BookOpen,
  Brain,
  FlaskConical,
  Clock,
  Square,
} from 'lucide-react';
import { useAppStore } from '@/lib/store/app-store';
import { chatService } from '@/lib/services/chat-service';
import { router } from '@/lib/core/router';
import { marketingDraft } from '@/lib/core/deep-link';
import { audioService } from '@/lib/services/audio-service';
import { cn, greetingForHour, formatRelativeTime } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';

const SUGGESTIONS = [
  { label: 'Learn something new', prompt: 'Explain how local-first AI works, and why it matters for privacy. Keep it practical.' },
  { label: 'Get advice', prompt: 'I need to focus better while studying. Give me 3 concrete techniques I can try today.' },
  { label: 'Practice a language', prompt: 'Let\u2019s practice conversational Spanish. Correct my mistakes as we go.' },
  { label: 'Make a plan', prompt: 'Help me plan a productive 7-day sprint to ship a small side project.' },
  { label: 'Write something', prompt: 'Draft a short, friendly product update email announcing a new privacy feature.' },
  { label: 'Use my documents', prompt: '' },
];

/** Module-level hand-off for the first message of a fresh chat. */
export const pendingSend = { message: '' };

export function HomeView() {
  const { chats, settings } = useAppStore();
  const [value, setValue] = useState('');
  const [recording, setRecording] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const name = settings.general.displayName?.trim();
  const greeting = `${greetingForHour()}${name ? `, ${name}` : ''}`;

  const send = useCallback(async (text: string) => {
    const trimmed = text.trim();
    if (!trimmed) return;
    const chat = await chatService.createChat();
    pendingSend.message = trimmed;
    router.navigate(`/app/chat/${chat.id}`);
  }, []);

  const startRecording = async () => {
    try {
      await audioService.startRecording();
      setRecording(true);
    } catch {
      toast({
        title: 'Microphone unavailable',
        description: 'Grant microphone permission to dictate.',
        variant: 'destructive',
      });
    }
  };

  const stopRecording = async () => {
    setRecording(false);
    try {
      const blob = await audioService.stopRecording();
      if (blob.size === 0) return;
      toast({ title: 'Transcribing…', description: 'Converting your recording to text.' });
      const transcript = await audioService.transcribe(blob, 'recording.webm', 0);
      if (transcript.text) {
        setValue((v) => (v ? `${v} ${transcript.text}` : transcript.text));
      }
    } catch (err) {
      toast({
        title: 'Transcription failed',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    }
  };

  // Autosize the composer textarea.
  useEffect(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = 'auto';
    el.style.height = `${Math.min(el.scrollHeight, 200)}px`;
  }, [value]);

  // Marketing command-bar hand-off: the website's "try it" bar
  // deposits a prompt and navigates to #/app — land it in the home
  // composer so the demo funnels into the real product. Never
  // auto-sends; the user reviews the draft first.
  useEffect(() => {
    if (marketingDraft.text === '') return;
    const text = marketingDraft.text;
    marketingDraft.text = '';
    setValue(text);
    requestAnimationFrame(() => {
      const ta = textareaRef.current;
      if (!ta) return;
      ta.focus();
      const end = ta.value.length;
      ta.setSelectionRange(end, end);
    });
    toast({
      title: 'Prompt ready',
      description: 'Carried over from the website — edit it or hit send.',
    });
  }, []);

  const recent = chats.filter((c) => !c.archived).slice(0, 6);

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto flex w-full max-w-3xl flex-col px-4 pb-24 pt-10 sm:px-6 md:pt-16">
        {/* Greeting */}
        <div className="animate-in-up text-center">
          <h1 className="font-display text-3xl font-semibold tracking-tight sm:text-4xl">
            {greeting}
          </h1>
          <p className="mt-2 text-[15px] text-muted-foreground">What&apos;s on your mind?</p>
        </div>

        {/* Composer card */}
        <div className="animate-in-up mt-8" style={{ animationDelay: '60ms' }}>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              void send(value);
            }}
            className="mx-auto w-full max-w-2xl"
          >
            <div className="group rounded-2xl border border-border bg-card p-2 shadow-sm transition-shadow focus-within:border-brand-strong focus-within:shadow-md">
              <textarea
                ref={textareaRef}
                value={value}
                onChange={(e) => setValue(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && !e.shiftKey && settings.general.sendOnEnter) {
                    e.preventDefault();
                    void send(value);
                  }
                }}
                placeholder="Message PocketLLM…"
                aria-label="Message PocketLLM"
                rows={1}
                className="max-h-[200px] w-full resize-none bg-transparent px-3 py-2.5 text-[15px] outline-none placeholder:text-muted-foreground/70"
              />
              <div className="flex items-center gap-1 px-1 pt-1">
                <button
                  type="button"
                  className="rounded-full p-2 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                  aria-label="Attach a prompt template (coming from the Prompts library)"
                  title="Prompts library"
                  onClick={() => router.navigate('/app/prompts')}
                >
                  <Plus className="h-4 w-4" />
                </button>
                <button
                  type="button"
                  className="rounded-full p-2 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                  aria-label="Import a document into Knowledge"
                  title="Import to Knowledge"
                  onClick={() => router.navigate('/app/knowledge')}
                >
                  <Paperclip className="h-4 w-4" />
                </button>
                <span className="ml-auto text-[11px] text-muted-foreground/60">
                  {settings.privacy.strictOffline ? 'Strict Offline · sandbox runtime only' : 'Assist runtime'}
                </span>
                {recording ? (
                  <button
                    type="button"
                    onClick={stopRecording}
                    className="ml-1 flex h-9 w-9 items-center justify-center rounded-full bg-destructive text-white"
                    aria-label="Stop recording"
                  >
                    <Square className="h-3.5 w-3.5 fill-current" />
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={startRecording}
                    className="ml-1 rounded-full p-2 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                    aria-label="Dictate a message"
                    title="Dictate"
                  >
                    <Mic className="h-4 w-4" />
                  </button>
                )}
                <button
                  type="submit"
                  disabled={!value.trim()}
                  className="ml-1 flex h-9 w-9 items-center justify-center rounded-full bg-primary text-primary-foreground transition-all hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-30"
                  aria-label="Send message"
                >
                  <ArrowUp className="h-4 w-4" />
                </button>
              </div>
            </div>
          </form>

          {/* Suggestion chips */}
          <div className="mt-4 flex flex-wrap justify-center gap-2" role="list" aria-label="Suggested prompts">
            {SUGGESTIONS.map((s) => (
              <button
                key={s.label}
                role="listitem"
                onClick={() =>
                  s.prompt ? void send(s.prompt) : router.navigate('/app/knowledge')
                }
                className="rounded-full border border-border bg-card px-3.5 py-1.5 text-[13px] text-muted-foreground transition-all hover:border-brand-strong hover:text-foreground hover:shadow-sm"
              >
                {s.label}
              </button>
            ))}
          </div>
        </div>

        {/* Recent chats */}
        {recent.length > 0 && (
          <section className="animate-in-up mt-12" style={{ animationDelay: '120ms' }} aria-labelledby="recent-chats">
            <div className="mb-3 flex items-center justify-between">
              <h2 id="recent-chats" className="text-sm font-semibold text-muted-foreground">
                Continue where you left off
              </h2>
              <button
                className="text-xs text-muted-foreground hover:text-foreground"
                onClick={() => router.navigate('/app/chats')}
              >
                View all
              </button>
            </div>
            <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {recent.map((chat) => (
                <li key={chat.id}>
                  <button
                    onClick={() => router.navigate(`/app/chat/${chat.id}`)}
                    className="flex h-full w-full flex-col rounded-xl border border-border bg-card p-4 text-left transition-all hover:-translate-y-0.5 hover:border-brand-strong hover:shadow-md"
                  >
                    <span className="line-clamp-2 text-sm font-medium">{chat.title}</span>
                    <span className="mt-auto flex items-center gap-1.5 pt-3 text-[11px] text-muted-foreground">
                      <Clock className="h-3 w-3" />
                      {formatRelativeTime(chat.lastMessageAt)}
                      <span aria-hidden>·</span>
                      {chat.messageCount} messages
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          </section>
        )}

        {/* Feature quick-links */}
        <section className="animate-in-up mt-10 grid gap-3 sm:grid-cols-3" style={{ animationDelay: '180ms' }} aria-label="Feature shortcuts">
          <FeatureCard
            icon={BookOpen}
            title="Knowledge"
            description="Import PDFs, markdown and CSV — search them in chat."
            onClick={() => router.navigate('/app/knowledge')}
          />
          <FeatureCard
            icon={Brain}
            title="Memory"
            description="What PocketLLM remembers about you, fully editable."
            onClick={() => router.navigate('/app/memories')}
          />
          <FeatureCard
            icon={FlaskConical}
            title="Prompt Lab"
            description="Tune parameters and compare runtimes side by side."
            onClick={() => router.navigate('/app/lab/prompt')}
          />
        </section>
      </div>
    </div>
  );
}

function FeatureCard({
  icon: Icon,
  title,
  description,
  onClick,
}: {
  icon: React.ComponentType<{ className?: string }>;
  title: string;
  description: string;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className="flex items-start gap-3 rounded-xl border border-border bg-card p-4 text-left transition-all hover:-translate-y-0.5 hover:border-brand-strong hover:shadow-md"
    >
      <span className={cn('mt-0.5 rounded-lg bg-brand p-2 text-brand-foreground')}>
        <Icon className="h-4 w-4" />
      </span>
      <span>
        <span className="block text-sm font-medium">{title}</span>
        <span className="mt-0.5 block text-xs leading-relaxed text-muted-foreground">
          {description}
        </span>
      </span>
    </button>
  );
}

// Keep Sparkles import used (placeholder for future "enhance" quick action).
void Sparkles;
