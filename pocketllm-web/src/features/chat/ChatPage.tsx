import {
  Archive,
  ArrowUp,
  BookOpenText,
  Copy,
  Download,
  GitBranch,
  Mic,
  MoreHorizontal,
  Paperclip,
  RefreshCw,
  Settings2,
  Share2,
  Sparkles,
  Square,
  Star,
  Trash2,
  Volume2,
  WandSparkles,
  X,
} from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { prepareAttachment } from "../../core/attachments";
import { approveToolAndContinue, generateWithPipeline, maybeExtractMemories, recordGenerationUsage } from "../../core/generation";
import { useLiveValue } from "../../core/live";
import { speak } from "../../core/audio";
import type { AttachmentRef, BrowserModel, Chat, Message, Provider, RuntimeCapabilities, ToolEvent } from "../../core/types";
import { db } from "../../db/db";
import { Markdown } from "../../components/Markdown";
import { Modal } from "../../components/Modal";
import { useToast } from "../../components/Toast";

const suggestions = [
  "Summarize a document",
  "Help me plan something",
  "Explain a hard concept",
  "Draft a better prompt",
];

function uid() {
  return crypto.randomUUID();
}

function roleLabel(message: Message) {
  if (message.role === "user") return "You";
  if (message.role === "tool") return "Tool";
  return "PocketLLM";
}

export function ChatPage() {
  const { chatId } = useParams();
  const navigate = useNavigate();
  const toast = useToast();
  const providers = useLiveValue(() => db.providers.toArray(), [] as Provider[], []);
  const browserModels = useLiveValue(
    () => db.browserModels.filter((model) => model.installed || model.runtime === "chrome-ai").toArray(),
    [] as BrowserModel[],
    [],
  );
  const personas = useLiveValue(() => db.personas.orderBy("name").toArray(), [], []);
  const prompts = useLiveValue(() => db.prompts.orderBy("title").toArray(), [], []);
  const documents = useLiveValue(() => db.documents.orderBy("updatedAt").reverse().toArray(), [], []);
  const liveChat = useLiveValue<Chat | undefined>(
    async () => chatId ? await db.chats.get(chatId) : undefined,
    undefined,
    [chatId],
  );
  const liveMessages = useLiveValue(
    () => chatId ? db.messages.where("chatId").equals(chatId).sortBy("createdAt") : Promise.resolve([] as Message[]),
    [] as Message[],
    [chatId],
  );

  const [draft, setDraft] = useState("");
  const [attachments, setAttachments] = useState<AttachmentRef[]>([]);
  const [generationState, setGenerationState] = useState("idle");
  const [streamingId, setStreamingId] = useState<string>();
  const [streamingText, setStreamingText] = useState("");
  const [error, setError] = useState("");
  const [runtimeChoice, setRuntimeChoice] = useState("");
  const [inspectorOpen, setInspectorOpen] = useState(true);
  const [editMessage, setEditMessage] = useState<Message | null>(null);
  const [editText, setEditText] = useState("");
  const [sourceMessage, setSourceMessage] = useState<Message | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    setDraft(liveChat?.draft ?? "");
  }, [liveChat?.id]);

  useEffect(() => {
    if (liveChat?.browserModelId) setRuntimeChoice(`model:${liveChat.browserModelId}`);
    else if (liveChat?.providerId) setRuntimeChoice(`provider:${liveChat.providerId}`);
    else if (!runtimeChoice) {
      const model = browserModels.find((item) => item.installed);
      if (model) setRuntimeChoice(`model:${model.id}`);
      else if (providers[0]) setRuntimeChoice(`provider:${providers[0].id}`);
    }
  }, [liveChat?.id, liveChat?.browserModelId, liveChat?.providerId, providers.length, browserModels.length]);

  useEffect(() => {
    if (!liveChat) return;
    const timer = window.setTimeout(() => {
      void db.chats.update(liveChat.id, { draft, updatedAt: Date.now() });
    }, 350);
    return () => window.clearTimeout(timer);
  }, [draft, liveChat?.id]);

  const currentRuntime = useMemo(() => {
    if (runtimeChoice.startsWith("provider:")) {
      const provider = providers.find((item) => item.id === runtimeChoice.slice(9));
      return provider ? { label: provider.name, model: provider.model, capabilities: provider.capabilities } : undefined;
    }
    if (runtimeChoice.startsWith("model:")) {
      const model = browserModels.find((item) => item.id === runtimeChoice.slice(6));
      return model ? { label: model.name, model: model.name, capabilities: model.capabilities } : undefined;
    }
    return undefined;
  }, [runtimeChoice, providers, browserModels]);

  function choicePatch(choice: string) {
    if (choice.startsWith("provider:")) return { providerId: choice.slice(9), browserModelId: undefined };
    if (choice.startsWith("model:")) return { providerId: undefined, browserModelId: choice.slice(6) };
    return { providerId: undefined, browserModelId: undefined };
  }

  async function updateChat(values: Partial<Chat>) {
    if (!liveChat) return;
    await db.chats.update(liveChat.id, { ...values, updatedAt: Date.now() });
  }

  async function changeRuntime(choice: string) {
    setRuntimeChoice(choice);
    if (liveChat) await updateChat(choicePatch(choice));
  }

  async function ensureChat(): Promise<Chat> {
    if (liveChat) return liveChat;
    if (!runtimeChoice) throw new Error("Choose a model or provider first.");
    const now = Date.now();
    const chat: Chat = {
      id: uid(),
      title: "New conversation",
      createdAt: now,
      updatedAt: now,
      archived: false,
      pinned: false,
      draft: "",
      ragEnabled: false,
      toolsEnabled: false,
      memoryEnabled: true,
      selectedDocumentIds: [],
      temperature: 0.7,
      topP: 0.9,
      topK: 40,
      maxTokens: 800,
      ...choicePatch(runtimeChoice),
    };
    await db.chats.add(chat);
    navigate(`/chat/${chat.id}`, { replace: true });
    return chat;
  }

  async function addFiles(files: File[]) {
    for (const file of files) {
      try {
        const attachment = await prepareAttachment(file);
        setAttachments((current) => [...current, attachment]);
      } catch (cause) {
        toast.push(cause instanceof Error ? cause.message : `Could not attach ${file.name}`, "error");
      }
    }
  }

  async function runGeneration(chat: Chat, history: Message[], assistant: Message) {
    const controller = new AbortController();
    abortRef.current = controller;
    setStreamingId(assistant.id);
    setStreamingText("");
    setError("");

    try {
      const result = await generateWithPipeline(
        chat,
        history,
        {
          onState: setGenerationState,
          onToken: (text) => setStreamingText(text),
        },
        controller.signal,
      );
      const runtime = chat.browserModelId
        ? (await db.browserModels.get(chat.browserModelId))?.runtime
        : (await db.providers.get(chat.providerId ?? ""))?.kind;
      const model = chat.browserModelId
        ? (await db.browserModels.get(chat.browserModelId))?.name
        : (await db.providers.get(chat.providerId ?? ""))?.model;
      await db.messages.update(assistant.id, {
        content: result.content,
        citations: result.citations,
        toolEvents: result.toolEvents,
        generation: result.metrics,
        runtime,
        model,
        updatedAt: Date.now(),
      });
      await db.chats.update(chat.id, { updatedAt: Date.now() });
      if (model) await recordGenerationUsage(chat, model, runtime);
      setGenerationState(result.pendingTool ? "waitingForToolConfirmation" : "completed");
    } catch (cause) {
      if (controller.signal.aborted) {
        const partial = streamingText || "Generation stopped.";
        await db.messages.update(assistant.id, { content: partial, updatedAt: Date.now() });
        setGenerationState("cancelled");
      } else {
        const message = cause instanceof Error ? cause.message : "Generation failed.";
        await db.messages.update(assistant.id, { content: streamingText || `Error: ${message}`, updatedAt: Date.now() });
        setError(message);
        setGenerationState("error");
      }
    } finally {
      abortRef.current = null;
      setStreamingId(undefined);
      setStreamingText("");
      window.setTimeout(() => setGenerationState("idle"), 600);
    }
  }

  async function send(contentOverride?: string) {
    const content = (contentOverride ?? draft).trim();
    if (!content || abortRef.current) return;
    if (!runtimeChoice) {
      setError("Choose a model or provider in the top bar first.");
      return;
    }
    const active = await ensureChat();
    const capabilities = currentRuntime?.capabilities;
    if (attachments.some((item) => item.imageDataUrl) && !capabilities?.vision) {
      setError("The selected runtime is not declared vision-capable. Remove the image or choose a runtime where you explicitly enabled Vision.");
      return;
    }

    const now = Date.now();
    const previous = chatId ? await db.messages.where("chatId").equals(active.id).sortBy("createdAt") : [];
    const user: Message = {
      id: uid(),
      chatId: active.id,
      parentMessageId: previous.at(-1)?.id,
      role: "user",
      content,
      createdAt: now,
      attachments,
    };
    const assistant: Message = {
      id: uid(),
      chatId: active.id,
      parentMessageId: user.id,
      role: "assistant",
      content: "",
      createdAt: now + 1,
    };

    await db.transaction("rw", db.chats, db.messages, async () => {
      await db.messages.bulkAdd([user, assistant]);
      await db.chats.update(active.id, {
        title: previous.length ? active.title : content.slice(0, 58),
        draft: "",
        updatedAt: Date.now(),
        ...choicePatch(runtimeChoice),
      });
    });
    setDraft("");
    setAttachments([]);
    if (!active.noMemory && active.memoryEnabled !== false) void maybeExtractMemories(user);
    await runGeneration({ ...active, ...choicePatch(runtimeChoice) }, [...previous, user], assistant);
  }

  async function branchAt(message: Message, replacement?: string) {
    if (!liveChat) return;
    const source = await db.messages.where("chatId").equals(liveChat.id).sortBy("createdAt");
    const index = source.findIndex((item) => item.id === message.id);
    if (index < 0) return;
    const keep = source.slice(0, index + 1);
    const now = Date.now();
    const newChat: Chat = {
      ...liveChat,
      id: uid(),
      title: `Branch · ${liveChat.title}`,
      createdAt: now,
      updatedAt: now,
      pinned: false,
      archived: false,
      draft: "",
    };
    const idMap = new Map<string, string>();
    const copies = keep.map((item) => {
      const id = uid();
      idMap.set(item.id, id);
      return {
        ...item,
        id,
        chatId: newChat.id,
        parentMessageId: item.parentMessageId ? idMap.get(item.parentMessageId) : undefined,
        branchRootId: item.branchRootId ?? liveChat.id,
        content: item.id === message.id && replacement !== undefined ? replacement : item.content,
        createdAt: item.createdAt,
        updatedAt: Date.now(),
      };
    });
    await db.transaction("rw", db.chats, db.messages, async () => {
      await db.chats.add(newChat);
      if (copies.length) await db.messages.bulkAdd(copies);
    });
    navigate(`/chat/${newChat.id}`);
    return { chat: newChat, messages: copies };
  }

  async function regenerate(message: Message) {
    if (message.role !== "assistant") return;
    const source = await db.messages.where("chatId").equals(message.chatId).sortBy("createdAt");
    const index = source.findIndex((item) => item.id === message.id);
    const previousUser = source.slice(0, index).reverse().find((item) => item.role === "user");
    if (!previousUser) return;
    const branched = await branchAt(previousUser);
    if (!branched) return;
    const assistant: Message = {
      id: uid(),
      chatId: branched.chat.id,
      parentMessageId: branched.messages.at(-1)?.id,
      role: "assistant",
      content: "",
      createdAt: Date.now(),
    };
    await db.messages.add(assistant);
    await runGeneration(branched.chat, branched.messages, assistant);
  }

  async function approveTool(message: Message, event: ToolEvent) {
    if (!liveChat || event.state !== "pending") return;
    const all = await db.messages.where("chatId").equals(liveChat.id).sortBy("createdAt");
    const history = all.filter((item) => item.createdAt < message.createdAt);
    const controller = new AbortController();
    abortRef.current = controller;
    const assistant: Message = {
      id: uid(),
      chatId: liveChat.id,
      parentMessageId: message.id,
      role: "assistant",
      content: "",
      createdAt: Date.now(),
    };
    await db.messages.add(assistant);
    setStreamingId(assistant.id);
    try {
      const result = await approveToolAndContinue(
        liveChat,
        history,
        { event, assistantContent: message.content },
        {
          onState: setGenerationState,
          onToken: setStreamingText,
        },
        controller.signal,
      );
      const updatedEvents = (message.toolEvents ?? []).map((item) => item.id === event.id ? result.toolEvent : item);
      await db.messages.update(message.id, { toolEvents: updatedEvents, updatedAt: Date.now() });
      await db.messages.update(assistant.id, { content: result.content, citations: result.citations, updatedAt: Date.now() });
    } catch (cause) {
      const failed = { ...event, state: "failed" as const, error: cause instanceof Error ? cause.message : String(cause), updatedAt: Date.now() };
      await db.messages.update(message.id, { toolEvents: (message.toolEvents ?? []).map((item) => item.id === event.id ? failed : item) });
      await db.messages.delete(assistant.id);
      toast.push(failed.error ?? "Tool failed", "error");
    } finally {
      abortRef.current = null;
      setStreamingId(undefined);
      setStreamingText("");
      setGenerationState("idle");
    }
  }

  async function denyTool(message: Message, event: ToolEvent) {
    const denied = { ...event, state: "denied" as const, updatedAt: Date.now() };
    await db.messages.update(message.id, {
      toolEvents: (message.toolEvents ?? []).map((item) => item.id === event.id ? denied : item),
      updatedAt: Date.now(),
    });
  }

  async function deleteMessage(message: Message) {
    if (!confirm("Delete this message from this branch?")) return;
    await db.messages.delete(message.id);
  }

  function openEdit(message: Message) {
    setEditMessage(message);
    setEditText(message.content);
  }

  async function saveEditBranch() {
    if (!editMessage || !editText.trim()) return;
    await branchAt(editMessage, editText.trim());
    setEditMessage(null);
  }

  function downloadText(name: string, text: string, type = "text/plain") {
    const blob = new Blob([text], { type });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = name;
    link.click();
    URL.revokeObjectURL(url);
  }

  async function shareMessage(message: Message) {
    const title = liveChat?.title ?? "PocketLLM message";
    if (navigator.share) {
      try {
        await navigator.share({ title, text: message.content });
        return;
      } catch (cause) {
        if (cause instanceof DOMException && cause.name === "AbortError") return;
      }
    }
    await navigator.clipboard.writeText(message.content);
    toast.push("Message copied because native sharing is unavailable.", "success");
  }

  function exportMessage(message: Message) {
    const role = roleLabel(message);
    const filename = `pocketllm-${message.id.slice(0, 8)}.md`;
    downloadText(filename, `# ${role}\n\n${message.content}\n`, "text/markdown");
  }

  function exportChat() {
    if (!liveChat || !liveMessages.length) return;
    const markdown = [
      `# ${liveChat.title}`,
      `Exported: ${new Date().toISOString()}`,
      "",
      ...liveMessages.map((message) => `## ${roleLabel(message)}\n\n${message.content}\n`),
    ].join("\n");
    const safe = liveChat.title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 60) || "conversation";
    downloadText(`${safe}.md`, markdown, "text/markdown");
  }

  const displayMessages = liveMessages.map((message) =>
    message.id === streamingId ? { ...message, content: streamingText } : message,
  );
  const empty = displayMessages.length === 0;

  return (
    <section className="chat-page">
      <header className="chat-topbar">
        <div className="chat-title-block">
          <span className="eyebrow">{currentRuntime?.label ?? "Choose a runtime"}</span>
          <h1>{liveChat?.title ?? "New conversation"}</h1>
        </div>
        <div className="chat-top-actions">
          <select
            className="compact-select"
            value={runtimeChoice}
            onChange={(event) => void changeRuntime(event.target.value)}
            aria-label="AI runtime"
          >
            <option value="">Choose model</option>
            {browserModels.map((model) => <option key={model.id} value={`model:${model.id}`}>{model.name} · Browser</option>)}
            {providers.map((provider) => <option key={provider.id} value={`provider:${provider.id}`}>{provider.name} · {provider.model || "model?"}</option>)}
          </select>
          {liveChat && liveMessages.length > 0 && <button className="icon-button" onClick={exportChat} aria-label="Export conversation"><Download size={18} /></button>}
          <button className={`icon-button ${inspectorOpen ? "active" : ""}`} onClick={() => setInspectorOpen((value) => !value)} aria-label="Toggle context panel">
            <Settings2 size={18} />
          </button>
        </div>
      </header>

      <div className={`chat-layout ${inspectorOpen ? "with-inspector" : ""}`}>
        <div className="chat-main">
          {empty ? (
            <div className="welcome">
              <div className="orb" aria-hidden="true"><span /></div>
              <p className="eyebrow">Private by default</p>
              <h2>What’s on your mind?</h2>
              <p className="welcome-copy">One calm workspace for your local models, documents, memories and tools.</p>
            </div>
          ) : (
            <div className="message-list" aria-live="polite" aria-relevant="additions text">
              {displayMessages.map((message) => (
                <article key={message.id} className={`message ${message.role}`}>
                  <div className="message-meta">
                    <span>{roleLabel(message)}</span>
                    <div className="message-actions">
                      <button className="text-action" onClick={() => void navigator.clipboard.writeText(message.content)}><Copy size={13} /> Copy</button>
                      <button className="text-action" onClick={() => void shareMessage(message)}><Share2 size={13} /> Share</button>
                      <button className="text-action" onClick={() => exportMessage(message)}><Download size={13} /> Export</button>
                      {message.role === "assistant" && <button className="text-action" onClick={() => void regenerate(message)}><RefreshCw size={13} /> Regenerate</button>}
                      {message.role === "user" && <button className="text-action" onClick={() => openEdit(message)}><WandSparkles size={13} /> Edit</button>}
                      <button className="text-action" onClick={() => void branchAt(message)}><GitBranch size={13} /> Branch</button>
                      <button className="text-action" onClick={async () => {
                        const starred = !message.starred;
                        await db.messages.update(message.id, { starred });
                      }}><Star size={13} fill={message.starred ? "currentColor" : "none"} /> {message.starred ? "Starred" : "Star"}</button>
                      {message.role === "assistant" && <button className="text-action" onClick={() => speak(message.content)}><Volume2 size={13} /> Listen</button>}
                      <button className="text-action danger-text" onClick={() => void deleteMessage(message)}><Trash2 size={13} /> Delete</button>
                    </div>
                  </div>

                  {message.attachments?.length ? (
                    <div className="message-attachments">
                      {message.attachments.map((attachment) => (
                        <div key={attachment.id} className="attachment-card">
                          {attachment.imageDataUrl ? <img src={attachment.imageDataUrl} alt={attachment.name} /> : <Paperclip size={15} />}
                          <span>{attachment.name}</span>
                        </div>
                      ))}
                    </div>
                  ) : null}

                  <Markdown content={message.content || (message.id === streamingId ? "Thinking…" : "")} />

                  {message.toolEvents?.map((event) => (
                    <div key={event.id} className={`tool-card ${event.state}`}>
                      <div className="tool-card-head"><strong>{event.name}</strong><span>{event.state}</span></div>
                      <pre>{JSON.stringify(event.arguments, null, 2)}</pre>
                      {event.result && <div className="tool-result">{event.result}</div>}
                      {event.error && <div className="inline-error">{event.error}</div>}
                      {event.state === "pending" && (
                        <div className="tool-actions">
                          <button className="soft-button" onClick={() => void denyTool(message, event)}>Deny</button>
                          <button className="primary-button small" onClick={() => void approveTool(message, event)}>Allow once</button>
                        </div>
                      )}
                    </div>
                  ))}

                  {message.citations?.length ? (
                    <div className="citation-row">
                      {message.citations.map((citation, index) => (
                        <button key={citation.id} onClick={() => setSourceMessage({ ...message, citations: [citation] })}>
                          {index + 1} · {citation.documentName}{citation.page ? ` p.${citation.page}` : ""}
                        </button>
                      ))}
                    </div>
                  ) : null}
                </article>
              ))}
            </div>
          )}

          <div className="composer-dock">
            {error && <div className="inline-error" role="alert">{error}</div>}
            {attachments.length > 0 && (
              <div className="attachment-strip">
                {attachments.map((attachment) => (
                  <span className="attachment-chip" key={attachment.id}>
                    {attachment.name}
                    <button onClick={() => setAttachments((current) => current.filter((item) => item.id !== attachment.id))} aria-label={`Remove ${attachment.name}`}><X size={13} /></button>
                  </span>
                ))}
              </div>
            )}
            <form
              className="composer"
              onSubmit={(event) => {
                event.preventDefault();
                void send();
              }}
              onDragOver={(event) => event.preventDefault()}
              onDrop={(event) => {
                event.preventDefault();
                void addFiles(Array.from(event.dataTransfer.files));
              }}
            >
              <textarea
                value={draft}
                onChange={(event) => setDraft(event.target.value)}
                onPaste={(event) => {
                  const files = Array.from(event.clipboardData.files);
                  if (files.length) void addFiles(files);
                }}
                onKeyDown={(event) => {
                  if (event.key === "Enter" && !event.shiftKey) {
                    event.preventDefault();
                    void send();
                  }
                }}
                placeholder="Message PocketLLM"
                rows={1}
                aria-label="Message PocketLLM"
              />
              <div className="composer-row">
                <div className="composer-tools">
                  <input ref={fileInputRef} hidden type="file" multiple onChange={(event) => void addFiles(Array.from(event.target.files ?? []))} />
                  <button type="button" className="icon-button" aria-label="Attach file" onClick={() => fileInputRef.current?.click()}><Paperclip size={18} /></button>
                  <button type="button" className="soft-button" onClick={() => setDraft((text) => text ? `Improve this prompt while preserving intent:\n\n${text}` : text)} disabled={!draft.trim()}>
                    <Sparkles size={15} /> Enhance
                  </button>
                </div>
                {abortRef.current ? (
                  <button type="button" className="send-button" onClick={() => abortRef.current?.abort()} aria-label="Stop generation"><Square size={17} fill="currentColor" /></button>
                ) : (
                  <button type="submit" className="send-button" disabled={!draft.trim()} aria-label="Send message"><ArrowUp size={19} /></button>
                )}
              </div>
            </form>
            {empty && (
              <div className="suggestions">
                {suggestions.map((suggestion) => <button key={suggestion} onClick={() => setDraft(suggestion)}>{suggestion}</button>)}
              </div>
            )}
            <div className="composer-status">{generationState !== "idle" ? generationState.replace(/([A-Z])/g, " $1").toLowerCase() : "Local history autosaves in this browser"}</div>
          </div>
        </div>

        {inspectorOpen && (
          <aside className="chat-inspector" aria-label="Chat context">
            <section>
              <span className="inspector-label">Persona</span>
              <select value={liveChat?.personaId ?? ""} onChange={(event) => void updateChat({ personaId: event.target.value || undefined })}>
                <option value="">Default</option>
                {personas.map((persona) => <option key={persona.id} value={persona.id}>{persona.avatarIcon} {persona.name}</option>)}
              </select>
            </section>
            <section>
              <span className="inspector-label">System prompt</span>
              <select value={liveChat?.promptId ?? ""} onChange={(event) => void updateChat({ promptId: event.target.value || undefined })}>
                <option value="">None</option>
                {prompts.map((prompt) => <option key={prompt.id} value={prompt.id}>{prompt.title}</option>)}
              </select>
            </section>
            <section className="inspector-toggles">
              <label><input type="checkbox" checked={Boolean(liveChat?.ragEnabled)} onChange={(event) => void updateChat({ ragEnabled: event.target.checked })} /> <span><BookOpenText size={15} /> Documents</span></label>
              <label><input type="checkbox" checked={liveChat?.memoryEnabled !== false} onChange={(event) => void updateChat({ memoryEnabled: event.target.checked })} /> <span><Sparkles size={15} /> Use memory</span></label>
              <label><input type="checkbox" checked={Boolean(liveChat?.noMemory)} onChange={(event) => void updateChat({ noMemory: event.target.checked })} /> <span><Sparkles size={15} /> Don't save memory from this chat</span></label>
              <label><input type="checkbox" checked={Boolean(liveChat?.toolsEnabled)} onChange={(event) => void updateChat({ toolsEnabled: event.target.checked })} /> <span><MoreHorizontal size={15} /> Tools</span></label>
            </section>
            {liveChat?.ragEnabled && (
              <section>
                <span className="inspector-label">Knowledge sources</span>
                <div className="document-checks">
                  {documents.length === 0 ? <p>No indexed documents yet.</p> : documents.map((document) => {
                    const selected = liveChat.selectedDocumentIds ?? [];
                    return (
                      <label key={document.id}>
                        <input
                          type="checkbox"
                          checked={selected.includes(document.id)}
                          onChange={(event) => {
                            const next = event.target.checked ? [...selected, document.id] : selected.filter((id) => id !== document.id);
                            void updateChat({ selectedDocumentIds: next });
                          }}
                        />
                        <span>{document.name}</span>
                      </label>
                    );
                  })}
                  <small>No selection means search all indexed documents.</small>
                </div>
              </section>
            )}
            <section>
              <span className="inspector-label">Generation</span>
              <label className="mini-field">Temperature <input type="number" min="0" max="2" step="0.1" value={liveChat?.temperature ?? 0.7} onChange={(e) => void updateChat({ temperature: Number(e.target.value) })} /></label>
              <label className="mini-field">Max output <input type="number" min="64" max="8192" step="64" value={liveChat?.maxTokens ?? 800} onChange={(e) => void updateChat({ maxTokens: Number(e.target.value) })} /></label>
            </section>
            <section className="runtime-note">
              <strong>{currentRuntime?.model ?? "No model selected"}</strong>
              <p>{capabilityLine(currentRuntime?.capabilities)}</p>
            </section>
          </aside>
        )}
      </div>

      <Modal open={Boolean(editMessage)} title="Edit into a new branch" onClose={() => setEditMessage(null)}>
        <p className="modal-copy">Editing earlier history creates a branch. The original conversation remains untouched.</p>
        <textarea className="large-textarea" rows={8} value={editText} onChange={(event) => setEditText(event.target.value)} />
        <div className="modal-actions">
          <button className="soft-button" onClick={() => setEditMessage(null)}>Cancel</button>
          <button className="primary-button" onClick={() => void saveEditBranch()}>Create branch</button>
        </div>
      </Modal>

      <Modal open={Boolean(sourceMessage)} title="Source" onClose={() => setSourceMessage(null)}>
        {sourceMessage?.citations?.[0] && (
          <div className="source-card">
            <strong>{sourceMessage.citations[0].documentName}</strong>
            {sourceMessage.citations[0].page && <span>Page {sourceMessage.citations[0].page}</span>}
            <p>{sourceMessage.citations[0].excerpt}</p>
            <small>Retrieval score {sourceMessage.citations[0].score.toFixed(3)}</small>
          </div>
        )}
      </Modal>
    </section>
  );
}

function capabilityLine(capabilities?: RuntimeCapabilities) {
  if (!capabilities) return "Choose a runtime to begin.";
  const enabled = [
    capabilities.text && "Text",
    capabilities.vision && "Vision",
    capabilities.tools && "Tools",
    capabilities.embeddings && "Embeddings",
    capabilities.audio && "Audio",
  ].filter(Boolean);
  return enabled.length ? enabled.join(" · ") : "Capabilities unknown";
}
