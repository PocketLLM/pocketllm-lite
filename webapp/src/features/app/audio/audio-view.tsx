'use client';

/**
 * AudioView — recording, transcription and speech synthesis.
 *
 * - Recording: MediaRecorder → transcribe via the app's ASR endpoint.
 * - Uploads: audio files → same transcription path.
 * - Speech synthesis: browser SpeechSynthesis (local, offline).
 * - Every transcript is persisted locally and reusable.
 */
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Mic,
  Square,
  Upload,
  Copy,
  Trash2,
  Volume2,
  Loader2,
  AudioLines,
  Clock,
} from 'lucide-react';
import { audioService } from '@/lib/services/audio-service';
import { settingsService } from '@/lib/services/settings-service';
import { PageHeader, Section, EmptyState, StatusDot, MetaPill } from '@/features/app/shared/ui';
import { Button } from '@/components/ui/button';
import { cn, formatDuration, formatRelativeTime } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';
import type { AudioTranscript } from '@/lib/types/domain';

export function AudioView() {
  const [recording, setRecording] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [busy, setBusy] = useState<'record' | 'upload' | null>(null);
  const [transcripts, setTranscripts] = useState<AudioTranscript[]>([]);
  const [expanded, setExpanded] = useState<string | null>(null);

  // TTS state
  const [ttsText, setTtsText] = useState('');
  const [ttsVoice, setTtsVoice] = useState('');
  const [ttsRate, setTtsRate] = useState(1);
  const [voices, setVoices] = useState<SpeechSynthesisVoice[]>([]);
  const [speaking, setSpeaking] = useState(false);

  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const startedAt = useRef(0);

  const loadTranscripts = useCallback(async () => {
    setTranscripts(await audioService.listTranscripts());
  }, []);

  useEffect(() => {
    void loadTranscripts();
  }, [loadTranscripts]);

  // Load available voices (browser-local).
  useEffect(() => {
    if (!('speechSynthesis' in window)) return;
    const load = () => {
      const list = speechSynthesis.getVoices();
      setVoices(list);
      setTtsVoice((v) => v || list.find((x) => x.default)?.name || list[0]?.name || '');
    };
    load();
    speechSynthesis.addEventListener('voiceschanged', load);
    return () => speechSynthesis.removeEventListener('voiceschanged', load);
  }, []);

  const startRecording = async () => {
    try {
      await audioService.startRecording();
      startedAt.current = Date.now();
      setElapsed(0);
      setRecording(true);
      timerRef.current = setInterval(
        () => setElapsed(Math.floor((Date.now() - startedAt.current) / 1000)),
        500
      );
    } catch {
      toast({
        title: 'Microphone unavailable',
        description: 'Grant microphone permission to record.',
        variant: 'destructive',
      });
    }
  };

  const stopRecording = async () => {
    if (timerRef.current) clearInterval(timerRef.current);
    setRecording(false);
    const durationMs = Date.now() - startedAt.current;
    setBusy('record');
    try {
      const blob = await audioService.stopRecording();
      if (blob.size === 0) {
        toast({ title: 'Nothing recorded' });
        return;
      }
      const transcript = await audioService.transcribe(blob, 'recording.webm', durationMs);
      await loadTranscripts();
      setExpanded(transcript.id);
      toast({ title: 'Transcribed', description: 'The recording is now searchable text.' });
    } catch (err) {
      const blocked = settingsService.get().privacy.strictOffline;
      toast({
        title: 'Transcription failed',
        description: blocked
          ? 'Strict Offline blocks the transcription endpoint.'
          : err instanceof Error
            ? err.message
            : 'Try again.',
        variant: 'destructive',
      });
    } finally {
      setBusy(null);
    }
  };

  const uploadAndTranscribe = async (file: File) => {
    if (!file.type.startsWith('audio/') && !file.type.startsWith('video/')) {
      toast({ title: 'Not an audio file', description: 'Upload audio (mp3, wav, webm, m4a…).', variant: 'destructive' });
      return;
    }
    if (file.size > 25 * 1024 * 1024) {
      toast({ title: 'File too large', description: 'Keep audio under 25 MB.', variant: 'destructive' });
      return;
    }
    setBusy('upload');
    try {
      // Estimate duration is unknown for uploads — 0 until playback.
      const transcript = await audioService.transcribe(file, file.name, 0);
      await loadTranscripts();
      setExpanded(transcript.id);
      toast({ title: 'Transcribed', description: file.name });
    } catch (err) {
      toast({
        title: 'Transcription failed',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    } finally {
      setBusy(null);
    }
  };

  const speak = () => {
    if (!ttsText.trim()) return;
    setSpeaking(true);
    audioService.speak(ttsText, {
      rate: ttsRate,
      onEnd: () => setSpeaking(false),
    });
  };

  const copy = async (text: string) => {
    await navigator.clipboard.writeText(text);
    toast({ title: 'Copied to clipboard' });
  };

  const remove = async (id: string) => {
    await audioService.deleteTranscript(id);
    await loadTranscripts();
  };

  return (
    <div className="flex-1 overflow-y-auto scrollbar-slim">
      <div className="mx-auto w-full max-w-4xl px-4 py-6 pb-24 sm:px-6">
        <PageHeader
          title="Audio"
          description="Record or upload audio for local transcription, and speak text with the browser's offline voice engine."
        />

        {/* Record + upload */}
        <div className="mb-6 grid gap-4 md:grid-cols-2">
          <Section title="Record" description="Records with your microphone, then transcribes.">
            <div className="flex flex-col items-center gap-3 py-4">
              {recording ? (
                <>
                  <button
                    onClick={() => void stopRecording()}
                    className="relative flex h-20 w-20 items-center justify-center rounded-full bg-destructive text-white shadow-lg transition-transform hover:scale-105"
                    aria-label="Stop recording"
                  >
                    <span className="absolute inset-0 animate-ping rounded-full bg-destructive/40" aria-hidden />
                    <Square className="h-7 w-7 fill-current" />
                  </button>
                  <p className="font-mono text-lg tabular-nums" role="timer" aria-live="off">
                    {String(Math.floor(elapsed / 60)).padStart(2, '0')}:{String(elapsed % 60).padStart(2, '0')}
                  </p>
                  <StatusDot tone="error">Recording…</StatusDot>
                </>
              ) : busy === 'record' ? (
                <div className="flex flex-col items-center gap-2 py-6 text-muted-foreground">
                  <Loader2 className="h-6 w-6 animate-spin" />
                  <p className="text-sm">Transcribing…</p>
                </div>
              ) : (
                <button
                  onClick={() => void startRecording()}
                  className="flex h-20 w-20 items-center justify-center rounded-full border-2 border-border bg-card text-foreground shadow-sm transition-all hover:border-brand-strong hover:shadow-md"
                  aria-label="Start recording"
                >
                  <Mic className="h-7 w-7" />
                </button>
              )}
            </div>
          </Section>

          <Section title="Upload audio" description="Transcribe an existing audio file (max 25 MB).">
            <label className="flex cursor-pointer flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed border-border py-8 text-muted-foreground transition-colors hover:border-brand-strong hover:text-foreground">
              {busy === 'upload' ? (
                <>
                  <Loader2 className="h-6 w-6 animate-spin" />
                  <span className="text-sm">Transcribing…</span>
                </>
              ) : (
                <>
                  <Upload className="h-6 w-6" />
                  <span className="text-sm">Choose an audio file</span>
                  <span className="text-[11px] text-muted-foreground/60">mp3 · wav · webm · m4a</span>
                </>
              )}
              <input
                type="file"
                accept="audio/*"
                className="hidden"
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) void uploadAndTranscribe(f);
                  e.target.value = '';
                }}
                aria-label="Upload audio file"
              />
            </label>
          </Section>
        </div>

        {/* Speech synthesis */}
        <Section
          title="Speak text"
          description="Uses the browser's built-in speech engine — fully offline."
          className="mb-6"
        >
          <textarea
            value={ttsText}
            onChange={(e) => setTtsText(e.target.value)}
            placeholder="Type text to read aloud…"
            aria-label="Text to speak"
            className="mb-3 min-h-[80px] w-full resize-y rounded-lg border border-border bg-background p-3 text-sm outline-none focus:border-brand-strong"
          />
          <div className="flex flex-wrap items-end gap-3">
            <div className="min-w-40 flex-1 space-y-1.5">
              <label htmlFor="tts-voice" className="text-[12px] font-medium">Voice</label>
              <select
                id="tts-voice"
                value={ttsVoice}
                onChange={(e) => setTtsVoice(e.target.value)}
                className="w-full rounded-lg border border-border bg-background p-2 text-[13px]"
              >
                {voices.length === 0 && <option value="">No voices available</option>}
                {voices.map((v) => (
                  <option key={v.name} value={v.name}>
                    {v.name} ({v.lang}){v.localService ? ' · local' : ' · network'}
                  </option>
                ))}
              </select>
            </div>
            <div className="w-40 space-y-1.5">
              <label htmlFor="tts-rate" className="text-[12px] font-medium">
                Speed: {ttsRate.toFixed(1)}×
              </label>
              <input
                id="tts-rate"
                type="range"
                min="0.5"
                max="2"
                step="0.1"
                value={ttsRate}
                onChange={(e) => setTtsRate(Number(e.target.value))}
                className="w-full accent-[var(--brand-strong)]"
              />
            </div>
            {speaking ? (
              <Button variant="destructive" onClick={() => { audioService.stopSpeaking(); setSpeaking(false); }}>
                <Square className="h-4 w-4" /> Stop
              </Button>
            ) : (
              <Button onClick={speak} disabled={!ttsText.trim() || voices.length === 0}>
                <Volume2 className="h-4 w-4" /> Speak
              </Button>
            )}
          </div>
          <p className="mt-3 text-[11px] text-muted-foreground">
            Voices marked “local” run entirely on-device. Some browsers ship server-backed voices —
            those are labelled and need the network.
          </p>
        </Section>

        {/* Transcripts */}
        <Section title="Transcripts" description="Saved locally — click to expand the full text.">
          {transcripts.length === 0 ? (
            <EmptyState
              icon={AudioLines}
              title="No transcripts yet"
              description="Record or upload audio and the text will be stored here."
            />
          ) : (
            <ul className="space-y-2">
              {transcripts.map((t) => {
                const isOpen = expanded === t.id;
                return (
                  <li key={t.id} className={cn('rounded-xl border p-3 text-[13px]', isOpen ? 'border-brand-strong bg-card' : 'border-border bg-card')}>
                    <div className="flex flex-wrap items-center gap-2">
                      <AudioLines className="h-4 w-4 shrink-0 text-muted-foreground" />
                      <span className="min-w-0 flex-1 truncate font-medium">{t.name}</span>
                      <MetaPill>
                        <Clock className="h-3 w-3" />
                        {t.durationMs ? formatDuration(t.durationMs) : '—'}
                      </MetaPill>
                      <MetaPill tone="outline">{t.source}</MetaPill>
                      <span className="text-[11px] text-muted-foreground/70">{formatRelativeTime(t.createdAt)}</span>
                    </div>
                    {isOpen ? (
                      <div className="mt-2">
                        <p className="whitespace-pre-wrap rounded-lg bg-muted/50 p-3 leading-relaxed">{t.text}</p>
                        <div className="mt-2 flex gap-2">
                          <Button size="sm" variant="outline" onClick={() => void copy(t.text)}>
                            <Copy className="h-3.5 w-3.5" /> Copy
                          </Button>
                          <Button size="sm" variant="outline" onClick={() => audioService.speak(t.text)}>
                            <Volume2 className="h-3.5 w-3.5" /> Read aloud
                          </Button>
                          <Button size="sm" variant="destructive" onClick={() => void remove(t.id)}>
                            <Trash2 className="h-3.5 w-3.5" /> Delete
                          </Button>
                        </div>
                      </div>
                    ) : (
                      <button
                        className="mt-1 line-clamp-1 w-full text-left text-muted-foreground hover:text-foreground"
                        onClick={() => setExpanded(t.id)}
                        aria-label={`Expand transcript: ${t.name}`}
                      >
                        {t.text.slice(0, 120) || '(empty)'}
                      </button>
                    )}
                  </li>
                );
              })}
            </ul>
          )}
        </Section>
      </div>
    </div>
  );
}
