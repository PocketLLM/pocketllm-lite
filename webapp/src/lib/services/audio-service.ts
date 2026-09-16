/**
 * AudioService — recording (MediaRecorder), transcription (via the
 * app's /api/asr endpoint when allowed) and speech synthesis
 * (browser SpeechSynthesis, always local).
 */
import { bus } from '@/lib/core/events/event-bus';
import { transcriptRepo } from '@/lib/core/db/repositories';
import { gateway } from '@/lib/core/net/network-gateway';
import { logService } from './log-service';
import type { AudioTranscript } from '@/lib/types/domain';
import { uuid } from '@/lib/utils';

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

  /** Transcribes audio through the app's ASR endpoint. */
  async transcribe(blob: Blob, name: string, durationMs: number): Promise<AudioTranscript> {
    const base64 = await blobToBase64(blob);
    const res = await gateway.request('assist-asr', '/api/asr', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        audio_base64: base64,
        mime_type: blob.type || 'audio/webm',
      }),
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => '');
      throw new Error(`Transcription failed (${res.status}): ${detail.slice(0, 200)}`);
    }
    const json = (await res.json()) as { text?: string };
    const transcript: AudioTranscript = {
      id: uuid(),
      name,
      durationMs,
      text: json.text ?? '',
      source: name.includes('recording') ? 'recording' : 'upload',
      mimeType: blob.type || 'audio/webm',
      createdAt: Date.now(),
    };
    await transcriptRepo.put(transcript);
    bus.emit('transcripts:changed');
    return transcript;
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

function blobToBase64(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => {
      const result = String(reader.result ?? '');
      resolve(result.includes(',') ? result.split(',')[1] : result);
    };
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });
}

export const audioService = new AudioService();
