import { ArrowUp, Paperclip, Square, WandSparkles } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { db } from "../../db/db";
import { runtimeFor } from "../../core/runtime";
import type { Chat, GenerationState, Message, Provider } from "../../core/types";

const suggestions = [
  "Summarize a document",
  "Help me plan something",
  "Explain a hard concept",
  "Draft a better prompt",
];

function uid() {
  return crypto.randomUUID();
}

export function ChatPage() {
  const { chatId } = useParams();
  const navigate = useNavigate();
  const [chat, setChat] = useState<Chat | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [providers, setProviders] = useState<Provider[]>([]);
  const [draft, setDraft] = useState("");
  const [state, setState] = useState<GenerationState>("idle");
  const [error, setError] = useState("");
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function hydrate() {
      const allProviders = await db.providers.toArray();
      if (!cancelled) setProviders(allProviders);

      if (!chatId) {
        if (!cancelled) {
          setChat(null);
          setMessages([]);
          setDraft("");
        }
        return;
      }

      const loaded = await db.chats.get(chatId);
      const loadedMessages = await db.messages.where("chatId").equals(chatId).sortBy("createdAt");
      if (!cancelled) {
        setChat(loaded ?? null);
        setMessages(loadedMessages);
        setDraft(loaded?.draft ?? "");
      }
    }
    void hydrate();
    return () => {
      cancelled = true;
    };
  }, [chatId]);

  useEffect(() => {
    if (!chat) return;
    const timer = window.setTimeout(() => {
      void db.chats.update(chat.id, { draft, updatedAt: Date.now() });
    }, 350);
    return () => window.clearTimeout(timer);
  }, [draft, chat]);

  const selectedProvider = useMemo(() => {
    if (!providers.length) return undefined;
    return providers.find((provider) => provider.id === chat?.providerId) ?? providers[0];
  }, [providers, chat?.providerId]);

  async function ensureChat(): Promise<Chat> {
    if (chat) return chat;
    const now = Date.now();
    const created: Chat = {
      id: uid(),
      title: "New conversation",
      createdAt: now,
      updatedAt: now,
      archived: false,
      pinned: false,
      providerId: providers[0]?.id,
      draft: "",
    };
    await db.chats.add(created);
    setChat(created);
    navigate(`/chat/${created.id}`, { replace: true });
    return created;
  }

  async function send(text = draft) {
    const content = text.trim();
    if (!content || state === "streaming") return;
    setError("");

    if (!selectedProvider) {
      setError("Add an Ollama or OpenAI-compatible provider in Settings before sending.");
      return;
    }

    const active = await ensureChat();
    const now = Date.now();
    const userMessage: Message = {
      id: uid(),
      chatId: active.id,
      role: "user",
      content,
      createdAt: now,
    };
    const assistant: Message = {
      id: uid(),
      chatId: active.id,
      role: "assistant",
      content: "",
      createdAt: now + 1,
      model: selectedProvider.model,
      runtime: selectedProvider.kind,
    };

    await db.transaction("rw", db.chats, db.messages, async () => {
      await db.messages.bulkAdd([userMessage, assistant]);
      await db.chats.update(active.id, {
        title: messages.length ? active.title : content.slice(0, 54),
        draft: "",
        updatedAt: Date.now(),
        providerId: selectedProvider.id,
      });
    });

    const nextMessages = [...messages, userMessage, assistant];
    setMessages(nextMessages);
    setDraft("");
    setState("preparing");

    const controller = new AbortController();
    abortRef.current = controller;
    let built = "";

    try {
      setState("streaming");
      const apiKey = sessionStorage.getItem(`provider-key:${selectedProvider.id}`) ?? undefined;
      await runtimeFor(selectedProvider).generate({
        provider: selectedProvider,
        apiKey,
        signal: controller.signal,
        messages: nextMessages
          .filter((message) => message.id !== assistant.id && message.role !== "tool")
          .map((message) => ({
            role: message.role === "system" ? "system" : message.role === "assistant" ? "assistant" : "user",
            content: message.content,
          })),
        onToken(token) {
          built += token;
          setMessages((current) =>
            current.map((message) => (message.id === assistant.id ? { ...message, content: built } : message)),
          );
        },
      });
      await db.messages.update(assistant.id, { content: built });
      setState("completed");
    } catch (cause) {
      if (controller.signal.aborted) {
        await db.messages.update(assistant.id, { content: built || "Generation stopped." });
        setState("cancelled");
      } else {
        const message = cause instanceof Error ? cause.message : "Generation failed.";
        await db.messages.update(assistant.id, { content: built || `Error: ${message}` });
        setError(message);
        setState("error");
      }
    } finally {
      abortRef.current = null;
      window.setTimeout(() => setState("idle"), 250);
    }
  }

  async function toggleStar(message: Message) {
    const starred = !message.starred;
    await db.messages.update(message.id, { starred });
    setMessages((current) => current.map((item) => (item.id === message.id ? { ...item, starred } : item)));
  }

  const empty = messages.length === 0;

  return (
    <section className={`chat-page ${empty ? "empty" : ""}`}>
      <div className="chat-topbar">
        <div>
          <span className="eyebrow">{selectedProvider ? selectedProvider.name : "No provider selected"}</span>
          <h1>{chat?.title ?? "New conversation"}</h1>
        </div>
        {selectedProvider && <span className="model-pill">{selectedProvider.model || "Choose model"}</span>}
      </div>

      {empty ? (
        <div className="welcome">
          <div className="orb" aria-hidden="true"><span /></div>
          <p className="eyebrow">Private by default</p>
          <h2>What’s on your mind?</h2>
          <p className="welcome-copy">One calm workspace for your local models, documents, prompts and conversations.</p>
        </div>
      ) : (
        <div className="message-list" aria-live="polite">
          {messages.map((message) => (
            <article key={message.id} className={`message ${message.role}`}>
              <div className="message-meta">
                <span>{message.role === "user" ? "You" : "PocketLLM"}</span>
                <button className="text-action" onClick={() => void toggleStar(message)}>
                  {message.starred ? "Starred" : "Star"}
                </button>
              </div>
              <div className="message-content">{message.content || (state === "streaming" ? "Thinking…" : "")}</div>
            </article>
          ))}
        </div>
      )}

      <div className="composer-dock">
        {error && <div className="inline-error" role="alert">{error}</div>}
        <form
          className="composer"
          onSubmit={(event) => {
            event.preventDefault();
            void send();
          }}
        >
          <textarea
            value={draft}
            onChange={(event) => setDraft(event.target.value)}
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
              <button type="button" className="icon-button" aria-label="Attach file" disabled>
                <Paperclip size={18} />
              </button>
              <button type="button" className="soft-button" disabled>
                <WandSparkles size={16} /> Enhance
              </button>
            </div>
            {state === "streaming" ? (
              <button type="button" className="send-button" onClick={() => abortRef.current?.abort()} aria-label="Stop generation">
                <Square size={17} fill="currentColor" />
              </button>
            ) : (
              <button type="submit" className="send-button" disabled={!draft.trim()} aria-label="Send message">
                <ArrowUp size={19} />
              </button>
            )}
          </div>
        </form>

        {empty && (
          <div className="suggestions">
            {suggestions.map((suggestion) => (
              <button key={suggestion} onClick={() => setDraft(suggestion)}>{suggestion}</button>
            ))}
          </div>
        )}
      </div>
    </section>
  );
}
