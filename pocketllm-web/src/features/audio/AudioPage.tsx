import { Copy, FileAudio, Mic, Play, Square, Trash2, Upload, Volume2 } from "lucide-react";
import { useRef, useState } from "react";
import { startRecording, transcribeAudio, speak } from "../../core/audio";
import { useLiveValue } from "../../core/live";
import { db, setting } from "../../db/db";
import { useToast } from "../../components/Toast";

type RecordingHandle = Awaited<ReturnType<typeof startRecording>>;

export function AudioPage() {
  const transcripts = useLiveValue(() => db.audioTranscripts.orderBy("createdAt").reverse().toArray(), [], []);
  const toast = useToast();
  const inputRef = useRef<HTMLInputElement>(null);
  const recordingRef = useRef<RecordingHandle | null>(null);
  const [recording, setRecording] = useState(false);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState("");
  const [dictation, setDictation] = useState("");

  async function transcribe(file: File) {
    setBusy(true);
    try {
      await transcribeAudio(file, setStatus);
      toast.push("Transcript saved locally", "success");
    } catch (error) {
      toast.push(error instanceof Error ? error.message : "Transcription failed", "error");
    } finally {
      setBusy(false);
      setStatus("");
    }
  }

  async function toggleRecording() {
    if (recordingRef.current) {
      const handle = recordingRef.current;
      recordingRef.current = null;
      setRecording(false);
      try {
        const file = await handle.stop();
        await transcribe(file);
      } catch (error) {
        toast.push(error instanceof Error ? error.message : "Recording failed", "error");
      }
      return;
    }

    try {
      recordingRef.current = await startRecording();
      setRecording(true);
    } catch (error) {
      toast.push(error instanceof Error ? error.message : "Microphone unavailable", "error");
    }
  }

  async function dictate() {
    if (await setting("strictOffline", false)) {
      toast.push("Strict Offline blocks browser speech recognition because this browser has not proven it runs fully on-device.", "error");
      return;
    }
    const SpeechRecognitionCtor = (window as any).SpeechRecognition ?? (window as any).webkitSpeechRecognition;
    if (!SpeechRecognitionCtor) {
      toast.push("Browser speech recognition is unavailable.", "error");
      return;
    }
    const recognition = new SpeechRecognitionCtor();
    recognition.continuous = false;
    recognition.interimResults = true;
    recognition.onresult = (event: any) => {
      let text = "";
      for (let index = event.resultIndex; index < event.results.length; index += 1) text += event.results[index][0]?.transcript ?? "";
      setDictation(text.trim());
    };
    recognition.onerror = (event: any) => toast.push(event.error || "Speech recognition failed", "error");
    recognition.start();
  }

  return (
    <section className="page">
      <header className="page-header">
        <div><p className="eyebrow">Local speech</p><h1>Audio</h1><p>Whisper transcription runs through Transformers.js. Browser dictation is treated separately because some implementations use remote speech services.</p></div>
        <div className="header-tools">
          <button className="soft-button" onClick={() => void dictate()}><Mic size={15} /> Dictate</button>
          <button className={recording ? "danger-button" : "soft-button"} onClick={() => void toggleRecording()}>{recording ? <><Square size={15} /> Stop & transcribe</> : <><Mic size={15} /> Record</>}</button>
          <button className="primary-button" disabled={busy} onClick={() => inputRef.current?.click()}><Upload size={16} /> Upload audio</button>
          <input ref={inputRef} hidden type="file" accept="audio/*" onChange={(event) => {
            const file = event.target.files?.[0];
            if (file) void transcribe(file);
            event.target.value = "";
          }} />
        </div>
      </header>

      {dictation && (
        <div className="dictation-card">
          <span className="eyebrow">Browser dictation</span>
          <p>{dictation}</p>
          <button className="soft-button" onClick={() => void navigator.clipboard.writeText(dictation)}><Copy size={14} /> Copy</button>
        </div>
      )}

      {busy && <div className="progress-card"><div><strong>Transcribing</strong><span>{status || "Working locally"}</span></div><progress /></div>}

      <div className="audio-grid">
        {transcripts.length === 0 ? (
          <div className="empty-state list-card wide"><FileAudio size={28} /><h2>No transcripts yet</h2><p>Upload audio or record a clip. Whisper model downloads are cached by the browser after first use.</p></div>
        ) : transcripts.map((item) => (
          <article className="audio-card" key={item.id}>
            <div className="audio-head"><div><strong>{item.name}</strong><span>{item.model} · {new Date(item.createdAt).toLocaleString()}</span></div><FileAudio size={18} /></div>
            <p>{item.text}</p>
            <div className="card-actions">
              <button className="soft-button" onClick={() => void navigator.clipboard.writeText(item.text)}><Copy size={14} /> Copy</button>
              <button className="soft-button" onClick={() => speak(item.text)}><Volume2 size={14} /> Read aloud</button>
              <button className="icon-button danger" onClick={async () => { if (confirm("Delete this transcript?")) await db.audioTranscripts.delete(item.id); }}><Trash2 size={15} /></button>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}
