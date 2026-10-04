/**
 * AudioService — recording (MediaRecorder), on-device transcription
 * (Whisper in a Web Worker) and speech synthesis (browser
 * SpeechSynthesis, always local).
 */
import { bus } from '@/lib/core/events/event-bus';
import { transcriptRepo } from '@/lib/core/db/repositories';
import { gateway } from '@/lib/core/net/network-gateway';
import { logService } from './log-service';
import type { AudioTranscript } from '@/lib/types/domain';
import { uuid } from '@/lib/utils';
import type { WhisperRequest, WhisperResponse } from '@/workers/whisper.worker';

/** Progress reported while a transcription runs. */
export interface TranscribeProgress {
  stage: 'decoding' | 'model' | 'transcribing';
  /** 0–100. Only meaningful for the one-time model download. */
  percent: number;
}

const WHISPER_MODEL_URL = 'https://huggingface.co/Xenova/whisper-tiny/resolve/main/config.json';
const WHISPER_READY_KEY = 'pocketllm.whisper.ready';

/** True once the speech model has been downloaded into the browser cache. */
export function isWhisperCached(): boolean {
  try {
    return localStorage.getItem(WHISPER_READY_KEY) === '1';
  } catch {
    return false;
  }
}

function setWhisperCached(): void {
  try {
    localStorage.setItem(WHISPER_READY_KEY, '1');
  } catch {
    /* storage blocked — the model simply re-checks the cache next time */
  }
}

/** Decodes any browser-supported audio into 16 kHz mono samples. */
async function decodeTo16kMono(blob: Blob): Promise<{ samples: Float32Array; durationMs: number }> {
  const data = await blob.arrayBuffer();
  const ctx = new AudioContext();
  let decoded: AudioBuffer;
  try {
    decoded = await ctx.decodeAudioData(data);
  } catch {
    throw new Error('This audio format cannot be decoded by your browser. Try mp3, wav, m4a or webm.');
  } finally {
    void ctx.close();
  }
  const offline = new OfflineAudioContext(1, Math.max(1, Math.ceil(decoded.duration * 16000)), 16000);
  const source = offline.createBufferSource();
  source.buffer = decoded;
  source.connect(offline.destination);
  source.start();
  const rendered = await offline.startRendering();
  return { samples: rendered.getChannelData(0).slice(), durationMs: Math.round(decoded.duration * 1000) };
}

class AudioService {
  private recorder: MediaRecorder | null = null;
  private chunks: Blob[] = [];
  private stream: MediaStream | null = null;

  get isRecording(): boolean {
    return this.recorder?.state === 'recording';
  }

  /** Requests the microphone and starts recording. */
  async startRecording(): Promise<void> {
    this.stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    this.chunks = [];
    this.recorder = new MediaRecorder(this.stream);
    this.recorder.ondataavailable = (e) => {
      if (e.data.size > 0) this.chunks.push(e.data);
    };
    this.recorder.start(250);
  }

  /** Stops and returns the recorded blob. */
  async stopRecording(): Promise<Blob> {
    return new Promise((resolve) => {
      if (!this.recorder || this.recorder.state === 'inactive') {
        resolve(new Blob());
        return;
      }
      this.recorder.onstop = () => {
        const blob = new Blob(this.chunks, {
          type: this.recorder?.mimeType || 'audio/webm',
        });
        this.stream?.getTracks().forEach((t) => t.stop());
        this.recorder = null;
        this.stream = null;
        resolve(blob);
      };
      this.recorder.stop();
    });
  }

  /**
   * Transcribes audio on this device with Whisper (Transformers.js in a
   * Web Worker). Audio never leaves the browser. The ~40 MB speech model
   * is downloaded once from Hugging Face — that single download goes
   * through the NetworkGateway, so Strict Offline blocks it until the
   * model is cached; afterwards transcription works fully offline.
   */
  async transcribe(
    blob: Blob,
    name: string,
    durationMs: number,
    onProgress?: (p: TranscribeProgress) => void
  ): Promise<AudioTranscript> {
    const modelReady = isWhisperCached();
    if (!modelReady) {
      try {
        gateway.authorize('huggingface-download', WHISPER_MODEL_URL);
      } catch {
        throw new Error(
          'Strict Offline is on and the speech model is not downloaded yet. Turn Strict Offline off once to download it (~40 MB); after that transcription works offline.'
        );
      }
    }

    onProgress?.({ stage: 'decoding', percent: 0 });
    const { samples, durationMs: decodedMs } = await decodeTo16kMono(blob);
    const text = await this.runWhisper(samples, modelReady, onProgress);
    setWhisperCached();

    const transcript: AudioTranscript = {
      id: uuid(),
      name,
      durationMs: durationMs || decodedMs,
      text,
      source: name.includes('recording') ? 'recording' : 'upload',
      mimeType: blob.type || 'audio/webm',
      createdAt: Date.now(),
    };
    await transcriptRepo.put(transcript);
    bus.emit('transcripts:changed');
    return transcript;
  }

  private worker: Worker | null = null;
  private requestId = 0;

  private runWhisper(
    samples: Float32Array,
    cacheOnly: boolean,
    onProgress?: (p: TranscribeProgress) => void
  ): Promise<string> {
    if (!this.worker) {
      this.worker = new Worker(new URL('../../workers/whisper.worker.ts', import.meta.url), {
        type: 'module',
      });
    }
    const worker = this.worker;
    const id = ++this.requestId;
    return new Promise<string>((resolve, reject) => {
      const cleanup = () => {
        worker.removeEventListener('message', onMessage);
        worker.removeEventListener('error', onError);
      };
      const onMessage = (event: MessageEvent<WhisperResponse>) => {
        const msg = event.data;
        if (msg.id !== id) return;
        if (msg.type === 'progress') {
          onProgress?.({ stage: msg.stage, percent: msg.percent });
        } else if (msg.type === 'result') {
          cleanup();
          resolve(msg.text);
        } else {
          cleanup();
          reject(new Error(msg.message));
        }
      };
      const onError = (event: ErrorEvent) => {
        cleanup();
        // A crashed worker is unusable — drop it so the next call restarts.
        worker.terminate();
        this.worker = null;
        reject(new Error(event.message || 'The transcription worker crashed.'));
      };
      worker.addEventListener('message', onMessage);
      worker.addEventListener('error', onError);
      worker.postMessage({ type: 'transcribe', id, audio: samples, cacheOnly } satisfies WhisperRequest, [
        samples.buffer,
      ]);
    });
  }

  async listTranscripts(): Promise<AudioTranscript[]> {
    const all = await transcriptRepo.getAll();
    return all.sort((a, b) => b.createdAt - a.createdAt);
  }

  async deleteTranscript(id: string): Promise<void> {
    await transcriptRepo.delete(id);
    bus.emit('transcripts:changed');
  }

  /* ---------------------- speech synthesis (local) ---------------------- */

  private utterance: SpeechSynthesisUtterance | null = null;

  /** Reads text aloud using the browser's local speech engine. */
  speak(text: string, opts?: { onEnd?: () => void; rate?: number }): void {
    this.stopSpeaking();
    if (!('speechSynthesis' in window)) return;
    // Strip markdown for a cleaner reading experience.
    const clean = text
      .replace(/```[\s\S]*?```/g, ' (code block) ')
      .replace(/[*_#`>|]/g, '')
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      .slice(0, 5000);
    const u = new SpeechSynthesisUtterance(clean);
    u.rate = opts?.rate ?? 1;
    u.onend = () => {
      this.utterance = null;
      opts?.onEnd?.();
    };
    this.utterance = u;
    speechSynthesis.speak(u);
  }

  stopSpeaking(): void {
    if ('speechSynthesis' in window) speechSynthesis.cancel();
    this.utterance = null;
  }

  get isSpeaking(): boolean {
    return 'speechSynthesis' in window && speechSynthesis.speaking;
  }
}

export const audioService = new AudioService();
