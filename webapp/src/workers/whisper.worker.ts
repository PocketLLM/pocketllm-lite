/**
 * Whisper worker — on-device speech-to-text.
 *
 * Runs Whisper (tiny, multilingual) through Transformers.js + ONNX
 * Runtime Web in a dedicated worker so transcription never blocks the
 * UI. Audio arrives as 16 kHz mono Float32 samples; nothing is uploaded
 * anywhere. The model files are downloaded once from Hugging Face and
 * then served from the browser cache.
 */
import { env, pipeline } from '@huggingface/transformers';

/** Request / response protocol shared with `audio-service.ts`. */
export type WhisperRequest = {
  type: 'transcribe';
  id: number;
  audio: Float32Array;
  /** True → never touch the network; use the browser cache only. */
  cacheOnly: boolean;
  language?: string;
};

export type WhisperResponse =
  | { type: 'progress'; id: number; stage: 'model' | 'transcribing'; percent: number }
  | { type: 'result'; id: number; text: string }
  | { type: 'error'; id: number; message: string };

export const WHISPER_MODEL = 'Xenova/whisper-tiny';

env.allowLocalModels = false;
env.useBrowserCache = true;
// Serve the ONNX wasm from this origin (copied by scripts/copy-ort.mjs).
if (env.backends.onnx.wasm) {
  env.backends.onnx.wasm.wasmPaths = {
    mjs: '/ort/ort-wasm-simd-threaded.mjs',
    wasm: '/ort/ort-wasm-simd-threaded.wasm',
  };
}

type Transcriber = (
  audio: Float32Array,
  options: Record<string, unknown>
) => Promise<{ text: string } | Array<{ text: string }>>;

let transcriber: Promise<Transcriber> | null = null;

function post(msg: WhisperResponse): void {
  (self as unknown as Worker).postMessage(msg);
}

function loadModel(id: number, cacheOnly: boolean): Promise<Transcriber> {
  if (!transcriber) {
    const files = new Map<string, number>();
    transcriber = (
      pipeline('automatic-speech-recognition', WHISPER_MODEL, {
        local_files_only: cacheOnly,
        progress_callback: (p: { status?: string; file?: string; progress?: number }) => {
          if (p.status === 'progress' && p.file) {
            files.set(p.file, p.progress ?? 0);
            const total = [...files.values()].reduce((a, b) => a + b, 0) / files.size;
            post({ type: 'progress', id, stage: 'model', percent: Math.round(total) });
          }
        },
      }) as unknown as Promise<Transcriber>
    ).catch((err) => {
      transcriber = null; // allow a retry after a failed download
      throw err;
    });
  }
  return transcriber;
}

self.onmessage = async (event: MessageEvent<WhisperRequest>) => {
  const { id, audio, cacheOnly, language } = event.data;
  try {
    const run = await loadModel(id, cacheOnly);
    post({ type: 'progress', id, stage: 'transcribing', percent: 0 });
    const out = await run(audio, {
      chunk_length_s: 30,
      stride_length_s: 5,
      return_timestamps: false,
      ...(language ? { language, task: 'transcribe' } : {}),
    });
    const text = (Array.isArray(out) ? out.map((o) => o.text).join(' ') : out.text).trim();
    post({ type: 'result', id, text });
  } catch (err) {
    post({
      type: 'error',
      id,
      message: err instanceof Error ? err.message : 'Transcription failed',
    });
  }
};
