import { db, logActivity, setting } from "../db/db";
import type { AudioTranscript } from "./types";

let transcriberPromise: Promise<any> | null = null;
let transcriberModel = "";

async function getTranscriber() {
  const model = await setting("whisperModel", "Xenova/whisper-tiny.en");
  if (!transcriberPromise || transcriberModel !== model) {
    transcriberModel = model;
    transcriberPromise = (async () => {
      const { pipeline, env } = await import("@huggingface/transformers");
      const strictOffline = await setting("strictOffline", false);
      env.allowRemoteModels = !strictOffline;
      const device = (navigator as Navigator & { gpu?: unknown }).gpu ? "webgpu" : "wasm";
      try {
        return await pipeline("automatic-speech-recognition", model, { device });
      } catch (error) {
        if (device === "webgpu") return pipeline("automatic-speech-recognition", model, { device: "wasm" });
        throw error;
      }
    })();
  }
  return transcriberPromise;
}

export async function transcribeAudio(file: File, onProgress?: (message: string) => void) {
  const model = await setting("whisperModel", "Xenova/whisper-tiny.en");
  onProgress?.("Loading Whisper");
  const transcriber = await getTranscriber();
  const url = URL.createObjectURL(file);
  try {
    onProgress?.("Transcribing locally");
    const output = await transcriber(url);
    const text = typeof output?.text === "string" ? output.text.trim() : "";
    if (!text) throw new Error("Whisper returned an empty transcript.");
    const transcript: AudioTranscript = {
      id: crypto.randomUUID(),
      name: file.name,
      text,
      model,
      createdAt: Date.now(),
    };
    await db.audioTranscripts.add(transcript);
    await logActivity("audio", "Audio transcribed", file.name);
    return transcript;
  } finally {
    URL.revokeObjectURL(url);
  }
}

export function speak(text: string) {
  if (!("speechSynthesis" in window)) throw new Error("Speech synthesis is unavailable in this browser.");
  speechSynthesis.cancel();
  const utterance = new SpeechSynthesisUtterance(text);
  speechSynthesis.speak(utterance);
  return () => speechSynthesis.cancel();
}

export async function startRecording() {
  if (!navigator.mediaDevices?.getUserMedia) throw new Error("Microphone recording is unavailable.");
  const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
  const recorder = new MediaRecorder(stream);
  const chunks: BlobPart[] = [];
  recorder.addEventListener("dataavailable", (event) => {
    if (event.data.size) chunks.push(event.data);
  });
  recorder.start();
  return {
    recorder,
    async stop() {
      const blob = await new Promise<Blob>((resolve) => {
        recorder.addEventListener("stop", () => resolve(new Blob(chunks, { type: recorder.mimeType || "audio/webm" })), { once: true });
        recorder.stop();
      });
      stream.getTracks().forEach((track) => track.stop());
      return new File([blob], `recording-${new Date().toISOString().replace(/[:.]/g, "-")}.webm`, { type: blob.type });
    },
  };
}
