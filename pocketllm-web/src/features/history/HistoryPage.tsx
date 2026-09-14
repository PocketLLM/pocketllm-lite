import { Archive, MessageSquareText, Pin, Search, Star, Tags, Trash2, Undo2 } from "lucide-react";
import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { db } from "../../db/db";
import { useLiveValue } from "../../core/live";
import type { Chat, Message } from "../../core/types";

export function HistoryPage({ mode = "active" }: { mode?: "active" | "archived" }) {
  const items = useLiveValue(
    () => db.chats.orderBy("updatedAt").reverse().toArray(),
    [] as Chat[],
    [],
  );
  const [query, setQuery] = useState("");
  const [tag, setTag] = useState("");

  const tags = useMemo(() => [...new Set(items.flatMap((chat) => chat.tags ?? []))].sort(), [items]);
  const filtered = useMemo(() => items.filter((chat) => {
    const archiveMatch = mode === "archived" ? chat.archived : !chat.archived;
    const textMatch = chat.title.toLowerCase().includes(query.toLowerCase());
    const tagMatch = !tag || chat.tags?.includes(tag);
    return archiveMatch && textMatch && tagMatch;
  }), [items, mode, query, tag]);

  async function patch(id: string, values: Partial<Chat>) {
    await db.chats.update(id, { ...values, updatedAt: Date.now() });
  }

  async function remove(id: string) {
    if (!window.confirm("Delete this conversation and all messages in it? This cannot be undone.")) return;
    await db.transaction("rw", db.chats, db.messages, async () => {
      await db.messages.where("chatId").equals(id).delete();
      await db.chats.delete(id);
    });
  }

  async function addTag(chat: Chat) {
    const next = window.prompt("Tag name");
    if (!next?.trim()) return;
    const value = next.trim().slice(0, 40);
    await patch(chat.id, { tags: [...new Set([...(chat.tags ?? []), value])] });
  }

  return (
    <section className="page">
      <header className="page-header">
        <div>
          <p className="eyebrow">Your workspace</p>
          <h1>{mode === "archived" ? "Archived chats" : "Conversations"}</h1>
          <p>Search, pin, tag, branch and keep only what matters.</p>
        </div>
        <div className="header-tools">
          <div className="search-box"><Search size={17} /><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search chats" aria-label="Search chats" /></div>
          <select className="filter-select" value={tag} onChange={(e) => setTag(e.target.value)} aria-label="Filter by tag">
            <option value="">All tags</option>
            {tags.map((item) => <option key={item} value={item}>{item}</option>)}
          </select>
        </div>
      </header>

      <div className="list-card">
        {filtered.length === 0 ? (
          <div className="empty-state"><MessageSquareText size={28} /><h2>{mode === "archived" ? "Nothing archived" : "No conversations yet"}</h2><p>Your chats remain on this browser unless you export or delete them.</p></div>
        ) : filtered.map((chat) => (
          <div className="history-row" key={chat.id}>
            <Link to={`/chat/${chat.id}`} className="history-main">
              <strong>{chat.title}</strong>
              <span>{new Date(chat.updatedAt).toLocaleString()} {chat.tags?.length ? `· ${chat.tags.join(", ")}` : ""}</span>
            </Link>
            <div className="row-actions">
              <button className="icon-button" onClick={() => void patch(chat.id, { pinned: !chat.pinned })} aria-label={chat.pinned ? "Unpin chat" : "Pin chat"}><Pin size={17} fill={chat.pinned ? "currentColor" : "none"} /></button>
              <button className="icon-button" onClick={() => void addTag(chat)} aria-label="Tag chat"><Tags size={17} /></button>
              <button className="icon-button" onClick={() => void patch(chat.id, { archived: !chat.archived })} aria-label={chat.archived ? "Restore chat" : "Archive chat"}>{chat.archived ? <Undo2 size={17} /> : <Archive size={17} />}</button>
              <button className="icon-button danger" onClick={() => void remove(chat.id)} aria-label="Delete chat"><Trash2 size={17} /></button>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

export function StarredPage() {
  const messages = useLiveValue(
    () => db.messages.where("starred").equals(1).reverse().sortBy("createdAt"),
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
