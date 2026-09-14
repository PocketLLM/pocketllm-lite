import { Accessibility, ArchiveRestore, BookOpenText, Brush, Download, Github, Languages, LockKeyhole, Mic2, Save, ShieldCheck, Upload } from "lucide-react";
import { useRef, useState } from "react";
import { Link } from "react-router-dom";
import { downloadBackup, exportEncryptedBackup, restoreEncryptedBackup } from "../../core/backup";
import { useLiveValue } from "../../core/live";
import { db, saveSetting } from "../../db/db";
import { useToast } from "../../components/Toast";

export function SettingsPage() {
  const toast = useToast();
  const settings = useLiveValue(() => db.settings.toArray(), [], []);
  const map = new Map(settings.map((item) => [item.key, item.value]));
  const importRef = useRef<HTMLInputElement>(null);
  const [backupPassword, setBackupPassword] = useState("");
  const [backupBusy, setBackupBusy] = useState(false);
  const [tavilyKey, setTavilyKey] = useState(sessionStorage.getItem("tavily-key") ?? "");

  const bool = (key: string, fallback = false) => typeof map.get(key) === "boolean" ? Boolean(map.get(key)) : fallback;
  const string = (key: string, fallback = "") => typeof map.get(key) === "string" ? String(map.get(key)) : fallback;

  async function exportBackup() {
    if (backupPassword.length < 8) return toast.push("Use a backup password with at least 8 characters.", "error");
    setBackupBusy(true);
    try {
      downloadBackup(await exportEncryptedBackup(backupPassword));
      toast.push("Encrypted .pllm backup created", "success");
    } catch (error) {
      toast.push(error instanceof Error ? error.message : "Backup failed", "error");
    } finally {
      setBackupBusy(false);
    }
  }

  async function importBackup(file: File) {
    if (backupPassword.length < 8) return toast.push("Enter the backup password first.", "error");
    setBackupBusy(true);
    try {
      const result = await restoreEncryptedBackup(await file.text(), backupPassword);
      toast.push(`Restored ${result.chats} chats, ${result.memories} memories and ${result.documents} documents`, "success");
    } catch (error) {
      toast.push(error instanceof Error ? error.message : "Restore failed", "error");
    } finally {
      setBackupBusy(false);
      if (importRef.current) importRef.current.value = "";
    }
  }

  return (
    <section className="page settings-page">
      <header className="page-header"><div><p className="eyebrow">PocketLLM</p><h1>Settings</h1><p>Local state, explicit network boundaries, and portable encrypted backups.</p></div></header>
      <div className="settings-sections">
        <SettingsSection icon={<Brush size={18} />} title="Appearance" subtitle="Theme and density belong to this browser.">
          <div className="setting-row"><div><strong>Appearance</strong><small>System follows your OS preference.</small></div><select value={string("appearance", "system")} onChange={(e) => void saveSetting("appearance", e.target.value)}><option value="system">System</option><option value="light">Light</option><option value="dark">Dark</option></select></div>
          <div className="setting-row"><div><strong>Font scale</strong><small>Applied to the entire web workspace.</small></div><select value={string("fontScale", "100")} onChange={(e) => void saveSetting("fontScale", e.target.value)}><option value="90">90%</option><option value="100">100%</option><option value="110">110%</option><option value="125">125%</option><option value="150">150%</option><option value="200">200%</option></select></div>
        </SettingsSection>

        <SettingsSection icon={<Languages size={18} />} title="Language" subtitle="The localization contract includes the same six language families as mobile.">
          <div className="setting-row"><div><strong>Interface language</strong><small>Some newly-added expert surfaces may still fall back to English while translations catch up.</small></div><select value={string("language", "en")} onChange={(e) => void saveSetting("language", e.target.value)}><option value="en">English</option><option value="es">Español</option><option value="zh">中文</option><option value="ja">日本語</option><option value="ko">한국어</option><option value="hi">हिन्दी</option></select></div>
        </SettingsSection>

        <SettingsSection icon={<ShieldCheck size={18} />} title="Privacy & network" subtitle="Strict Offline is enforced by the central network gateway for PocketLLM-owned requests.">
          <Toggle label="Strict Offline" description="Allow browser-local work and loopback. Block LAN and Internet requests." checked={bool("strictOffline")} onChange={(value) => void saveSetting("strictOffline", value)} />
          <Toggle label="Online model browsing" description="Allow Hugging Face model discovery and downloads when Strict Offline is off." checked={bool("onlineModelBrowsing", true)} onChange={(value) => void saveSetting("onlineModelBrowsing", value)} />
          <Toggle label="GitHub skill installation" description="Allow explicit raw GitHub skill downloads." checked={bool("githubSkillsEnabled")} onChange={(value) => void saveSetting("githubSkillsEnabled", value)} />
          <Toggle label="Tavily web search" description="Allow the optional Tavily tool after per-call confirmation." checked={bool("tavilyEnabled")} onChange={(value) => void saveSetting("tavilyEnabled", value)} />
          <label className="inline-secret">Tavily key <input type="password" value={tavilyKey} onChange={(e) => setTavilyKey(e.target.value)} placeholder="Session only" /><button className="soft-button" onClick={() => { if (tavilyKey) sessionStorage.setItem("tavily-key", tavilyKey); else sessionStorage.removeItem("tavily-key"); toast.push("Session key updated", "success"); }}><Save size={14} /> Save session</button></label>
          <Link className="setting-link" to="/network"><LockKeyhole size={15} /> Open Network Centre</Link>
        </SettingsSection>

        <SettingsSection icon={<BookOpenText size={18} />} title="Knowledge & memory" subtitle="Choose browser-local utility models independently from your chat model.">
          <Toggle label="Automatic memory extraction" description="Heuristic extraction is opt-in; sensitive patterns are rejected." checked={bool("autoMemoryExtraction")} onChange={(value) => void saveSetting("autoMemoryExtraction", value)} />
          <div className="setting-row"><div><strong>RAG retrieval</strong><small>Hybrid combines BM25 + semantic similarity + MMR.</small></div><select value={string("ragRetrievalMode", "hybrid")} onChange={(e) => void saveSetting("ragRetrievalMode", e.target.value)}><option value="keyword">Keyword</option><option value="semantic">Semantic</option><option value="hybrid">Hybrid</option></select></div>
          <label className="setting-input"><span><strong>Embedding model</strong><small>Transformers.js model ID</small></span><input value={string("ragEmbeddingModel", "Xenova/all-MiniLM-L6-v2")} onChange={(e) => void saveSetting("ragEmbeddingModel", e.target.value)} /></label>
        </SettingsSection>

        <SettingsSection icon={<Mic2 size={18} />} title="Audio" subtitle="Whisper transcription is separate from browser SpeechRecognition.">
          <label className="setting-input"><span><strong>Whisper model</strong><small>Downloaded and cached by Transformers.js on first use.</small></span><input value={string("whisperModel", "Xenova/whisper-tiny.en")} onChange={(e) => void saveSetting("whisperModel", e.target.value)} /></label>
        </SettingsSection>

        <SettingsSection icon={<ArchiveRestore size={18} />} title="Encrypted backup" subtitle="Compatible cryptographic envelope with mobile .pllm backups: PBKDF2-HMAC-SHA256, 600k iterations, AES-256-GCM.">
          <label className="setting-input"><span><strong>Backup password</strong><small>Never stored by PocketLLM.</small></span><input type="password" value={backupPassword} onChange={(e) => setBackupPassword(e.target.value)} autoComplete="new-password" placeholder="At least 8 characters" /></label>
          <div className="backup-actions">
            <button className="primary-button" disabled={backupBusy} onClick={() => void exportBackup()}><Download size={15} /> Export .pllm</button>
            <button className="soft-button" disabled={backupBusy} onClick={() => importRef.current?.click()}><Upload size={15} /> Restore .pllm</button>
            <input ref={importRef} hidden type="file" accept=".pllm,application/json" onChange={(e) => { const file = e.target.files?.[0]; if (file) void importBackup(file); }} />
          </div>
        </SettingsSection>

        <SettingsSection icon={<Accessibility size={18} />} title="Data, accessibility & about" subtitle="The web app is account-free and stores app state on this origin.">
          <Link className="setting-link" to="/settings/storage">Open Data & Storage</Link>
          <Link className="setting-link" to="/errors">Open safe error log</Link>
          <a className="setting-link" href="https://github.com/PocketLLM/pocketllm-lite" target="_blank" rel="noreferrer"><Github size={15} /> PocketLLM on GitHub</a>
          <div className="about-copy"><strong>PocketLLM Web</strong><p>Local-first browser workspace. A standard webpage cannot expose an inbound OpenAI-compatible TCP server, guarantee reminders after every browser is fully closed, or provide Android/iOS hardware-backed key storage. Those limits are shown rather than faked.</p></div>
        </SettingsSection>
      </div>
    </section>
  );
}

function SettingsSection({ icon, title, subtitle, children }: { icon: React.ReactNode; title: string; subtitle: string; children: React.ReactNode }) {
  return <section className="settings-card full-settings-card"><div className="settings-title">{icon}<div><h2>{title}</h2><p>{subtitle}</p></div></div><div className="settings-content">{children}</div></section>;
}

function Toggle({ label, description, checked, onChange }: { label: string; description: string; checked: boolean; onChange: (value: boolean) => void }) {
  return <button className={`setting-toggle ${checked ? "enabled" : ""}`} onClick={() => onChange(!checked)} aria-pressed={checked}><span><strong>{label}</strong><small>{description}</small></span><span className="switch"><span /></span></button>;
}
