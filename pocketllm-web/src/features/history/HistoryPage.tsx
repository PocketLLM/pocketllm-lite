import { Archive, Download, Filter, MessageSquareText, Pin, Search, Star, Tags, Trash2, Undo2, X } from "lucide-react";
import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { db } from "../../db/db";
import { useLiveValue } from "../../core/live";
import type { BrowserModel, Chat, Message, Persona, Provider } from "../../core/types";

type DateFilter = "all" | "7d" | "30d" | "year";
type SpecialFilter = "all" | "starred" | "documents" | "pinned";

export function HistoryPage({ mode = "active" }: { mode?: "active" | "archived" }) {
  const items = useLiveValue(() => db.chats.orderBy("updatedAt").reverse().toArray(), [] as Chat[], []);
  const messages = useLiveValue(() => db.messages.toArray(), [] as Message[], []);
  const providers = useLiveValue(() => db.providers.toArray(), [] as Provider[], []);
  const models = useLiveValue(() => db.browserModels.toArray(), [] as BrowserModel[], []);
  const personas = useLiveValue(() => db.personas.toArray(), [] as Persona[], []);

  const [query, setQuery] = useState("");
  const [tag, setTag] = useState("");
  const [runtime, setRuntime] = useState("");
  const [persona, setPersona] = useState("");
  const [dateFilter, setDateFilter] = useState<DateFilter>("all");
  const [special, setSpecial] = useState<SpecialFilter>("all");
  const [selected, setSelected] = useState<string[]>([]);

  const tags = useMemo(() => [...new Set(items.flatMap((chat) => chat.tags ?? []))].sort(), [items]);
  const providerById = useMemo(() => new Map(providers.map((provider) => [provider.id, provider])), [providers]);
  const modelById = useMemo(() => new Map(models.map((model) => [model.id, model])), [models]);
  const personaById = useMemo(() => new Map(personas.map((item) => [item.id, item])), [personas]);
  const messagesByChat = useMemo(() => {
    const map = new Map<string, Message[]>();
    for (const message of messages) map.set(message.chatId, [...(map.get(message.chatId) ?? []), message]);
    return map;
  }, [messages]);
  const starredChatIds = useMemo(() => new Set(messages.filter((message) => message.starred).map((message) => message.chatId)), [messages]);

  const runtimeOptions = useMemo(() => {
    const values = new Map<string, string>();
    for (const chat of items) {
      if (chat.providerId) values.set(`provider:${chat.providerId}`, providerById.get(chat.providerId)?.name ?? "Deleted provider");
      if (chat.browserModelId) values.set(`model:${chat.browserModelId}`, modelById.get(chat.browserModelId)?.name ?? "Deleted browser model");
    }
    return [...values.entries()].sort((a, b) => a[1].localeCompare(b[1]));
  }, [items, providerById, modelById]);

  const filtered = useMemo(() => {
    const now = Date.now();
    const lowerQuery = query.trim().toLowerCase();
    return items.filter((chat) => {
      const archiveMatch = mode === "archived" ? chat.archived : !chat.archived;
      if (!archiveMatch) return false;

      if (lowerQuery) {
        const messageText = (messagesByChat.get(chat.id) ?? []).map((message) => message.content).join(" ");
        if (!`${chat.title} ${messageText}`.toLowerCase().includes(lowerQuery)) return false;
      }

      if (tag && !chat.tags?.includes(tag)) return false;
      if (runtime && runtime !== (chat.providerId ? `provider:${chat.providerId}` : chat.browserModelId ? `model:${chat.browserModelId}` : "")) return false;
      if (persona && chat.personaId !== persona) return false;

      if (dateFilter !== "all") {
        const age = now - chat.updatedAt;
        if (dateFilter === "7d" && age > 7 * 24 * 60 * 60 * 1000) return false;
        if (dateFilter === "30d" && age > 30 * 24 * 60 * 60 * 1000) return false;
        if (dateFilter === "year" && new Date(chat.updatedAt).getFullYear() !== new Date(now).getFullYear()) return false;
      }

      if (special === "starred" && !starredChatIds.has(chat.id)) return false;
      if (special === "documents" && !(chat.selectedDocumentIds?.length || chat.ragEnabled)) return false;
      if (special === "pinned" && !chat.pinned) return false;
      return true;
    });
  }, [items, mode, query, tag, runtime, persona, dateFilter, special, messagesByChat, starredChatIds]);

  async function patch(id: string, values: Partial<Chat>) {
    await db.chats.update(id, { ...values, updatedAt: Date.now() });
  }

  async function remove(ids: string[]) {
    if (!ids.length) return;
    if (!window.confirm(`Delete ${ids.length} conversation${ids.length === 1 ? "" : "s"} and every message inside? This cannot be undone.`)) return;
    await db.transaction("rw", db.chats, db.messages, async () => {
      for (const id of ids) {
        await db.messages.where("chatId").equals(id).delete();
        await db.chats.delete(id);
      }
    });
    setSelected((current) => current.filter((id) => !ids.includes(id)));
  }

  async function addTag(chat: Chat) {
    const next = window.prompt("Tag name");
    if (!next?.trim()) return;
    const value = next.trim().slice(0, 40);
    await patch(chat.id, { tags: [...new Set([...(chat.tags ?? []), value])] });
  }

  async function bulkTag() {
    if (!selected.length) return;
    const next = window.prompt("Tag selected conversations");
    if (!next?.trim()) return;
    const value = next.trim().slice(0, 40);
    await db.transaction("rw", db.chats, async () => {
      for (const id of selected) {
        const chat = await db.chats.get(id);
        if (chat) await db.chats.update(id, { tags: [...new Set([...(chat.tags ?? []), value])], updatedAt: Date.now() });
      }
    });
  }

  async function bulkArchive(archived: boolean) {
    await db.transaction("rw", db.chats, async () => {
      for (const id of selected) await db.chats.update(id, { archived, updatedAt: Date.now() });
    });
    setSelected([]);
  }

  async function exportSelected() {
    if (!selected.length) return;
    const chats = items.filter((chat) => selected.includes(chat.id));
    const payload = {
      format: "pocketllm-chat-export",
      version: 1,
      exportedAt: new Date().toISOString(),
      chats: chats.map((chat) => ({
        chat,
        messages: (messagesByChat.get(chat.id) ?? []).sort((a, b) => a.createdAt - b.createdAt),
      })),
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `pocketllm-chats-${new Date().toISOString().slice(0, 10)}.json`;
    link.click();
    URL.revokeObjectURL(url);
  }

  const allVisibleSelected = filtered.length > 0 && filtered.every((chat) => selected.includes(chat.id));

  return (
    <section className="page">
      <header className="page-header">
        <div>
          <p className="eyebrow">Your workspace</p>
          <h1>{mode === "archived" ? "Archived chats" : "Conversations"}</h1>
          <p>Search message content, filter deeply, or batch-manage local conversations.</p>
        </div>
        <div className="header-tools">
          <div className="search-box"><Search size={17} /><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search chats and messages" aria-label="Search chats and messages" /></div>
        </div>
      </header>

      <div className="history-filters" aria-label="Conversation filters">
        <Filter size={15} />
        <select value={tag} onChange={(e) => setTag(e.target.value)} aria-label="Filter by tag">
          <option value="">All tags</option>
          {tags.map((item) => <option key={item} value={item}>{item}</option>)}
        </select>
        <select value={runtime} onChange={(e) => setRuntime(e.target.value)} aria-label="Filter by runtime">
          <option value="">All runtimes</option>
          {runtimeOptions.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
        </select>
        <select value={persona} onChange={(e) => setPersona(e.target.value)} aria-label="Filter by persona">
          <option value="">All personas</option>
          {personas.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
        </select>
        <select value={dateFilter} onChange={(e) => setDateFilter(e.target.value as DateFilter)} aria-label="Filter by date">
          <option value="all">Any date</option>
          <option value="7d">Last 7 days</option>
          <option value="30d">Last 30 days</option>
          <option value="year">This year</option>
        </select>
        <select value={special} onChange={(e) => setSpecial(e.target.value as SpecialFilter)} aria-label="Special filter">
          <option value="all">Everything</option>
          <option value="pinned">Pinned</option>
          <option value="starred">Has stars</option>
          <option value="documents">Used documents</option>
        </select>
        {(tag || runtime || persona || dateFilter !== "all" || special !== "all" || query) && (
          <button className="text-action" onClick={() => { setQuery(""); setTag(""); setRuntime(""); setPersona(""); setDateFilter("all"); setSpecial("all"); }}><X size={13} /> Clear</button>
        )}
      </div>

      {filtered.length > 0 && (
        <div className="bulk-bar">
          <label><input type="checkbox" checked={allVisibleSelected} onChange={(event) => setSelected(event.target.checked ? [...new Set([...selected, ...filtered.map((chat) => chat.id)])] : selected.filter((id) => !filtered.some((chat) => chat.id === id)))} /> Select visible</label>
          <span>{selected.length ? `${selected.length} selected` : `${filtered.length} conversations`}</span>
          {selected.length > 0 && (
            <div className="bulk-actions">
              <button className="text-action" onClick={() => void bulkTag()}><Tags size={13} /> Tag</button>
              <button className="text-action" onClick={() => void bulkArchive(mode !== "archived")}>{mode === "archived" ? <Undo2 size={13} /> : <Archive size={13} />}{mode === "archived" ? "Restore" : "Archive"}</button>
              <button className="text-action" onClick={() => void exportSelected()}><Download size={13} /> Export</button>
              <button className="text-action danger-text" onClick={() => void remove(selected)}><Trash2 size={13} /> Delete</button>
            </div>
          )}
        </div>
      )}

      <div className="list-card">
        {filtered.length === 0 ? (
          <div className="empty-state"><MessageSquareText size={28} /><h2>{mode === "archived" ? "Nothing archived" : "No matching conversations"}</h2><p>Your chats remain on this browser unless you export or delete them.</p></div>
        ) : filtered.map((chat) => {
          const runtimeName = chat.providerId ? providerById.get(chat.providerId)?.name : chat.browserModelId ? modelById.get(chat.browserModelId)?.name : undefined;
          const personaName = chat.personaId ? personaById.get(chat.personaId)?.name : undefined;
          return (
            <div className="history-row" key={chat.id}>
              <label className="history-select" aria-label={`Select ${chat.title}`}><input type="checkbox" checked={selected.includes(chat.id)} onChange={(event) => setSelected((current) => event.target.checked ? [...current, chat.id] : current.filter((id) => id !== chat.id))} /></label>
              <Link to={`/chat/${chat.id}`} className="history-main">
                <strong>{chat.title}</strong>
                <span>
                  {new Date(chat.updatedAt).toLocaleString()}
                  {runtimeName ? ` · ${runtimeName}` : ""}
                  {personaName ? ` · ${personaName}` : ""}
                  {chat.tags?.length ? ` · ${chat.tags.join(", ")}` : ""}
                  {starredChatIds.has(chat.id) ? " · starred" : ""}
                </span>
              </Link>
              <div className="row-actions">
                <button className="icon-button" onClick={() => void patch(chat.id, { pinned: !chat.pinned })} aria-label={chat.pinned ? "Unpin chat" : "Pin chat"}><Pin size={17} fill={chat.pinned ? "currentColor" : "none"} /></button>
                <button className="icon-button" onClick={() => void addTag(chat)} aria-label="Tag chat"><Tags size={17} /></button>
                <button className="icon-button" onClick={() => void patch(chat.id, { archived: !chat.archived })} aria-label={chat.archived ? "Restore chat" : "Archive chat"}>{chat.archived ? <Undo2 size={17} /> : <Archive size={17} />}</button>
                <button className="icon-button danger" onClick={() => void remove([chat.id])} aria-label="Delete chat"><Trash2 size={17} /></button>
              </div>
            </div>
          );
        })}
      </div>
    </section>
  );
}

export function StarredPage() {
  const messages = useLiveValue(
    async () => (await db.messages.filter((message) => Boolean(message.starred)).toArray()).sort((a, b) => b.createdAt - a.createdAt),
    [] as Message[],
    [],
  );
  const chats = useLiveValue(() => db.chats.toArray(), [] as Chat[], []);
  const byId = useMemo(() => new Map(chats.map((chat) => [chat.id, chat])), [chats]);

  return (
    <section className="page">
      <header className="page-header"><div><p className="eyebrow">Saved references</p><h1>Starred messages</h1><p>Important fragments from across your local chats.</p></div></header>
      <div className="list-card">
        {messages.length === 0 ? <div className="empty-state"><Star size={27} /><h2>No starred messages</h2><p>Star a message from any conversation to keep it here.</p></div> :
          messages.map((message) => (
            <div className="starred-row" key={message.id}>
              <div>
                <Link to={`/chat/${message.chatId}`}><strong>{byId.get(message.chatId)?.title ?? "Deleted chat"}</strong></Link>
                <p>{message.content.slice(0, 360)}</p>
              </div>
              <button className="icon-button" onClick={() => void db.messages.update(message.id, { starred: false })} aria-label="Remove star"><Star size={17} fill="currentColor" /></button>
            </div>
          ))}
      </div>
    </section>
  );
}
