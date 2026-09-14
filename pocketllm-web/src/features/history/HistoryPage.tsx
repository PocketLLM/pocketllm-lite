import { Archive, MessageSquareText, Pin, Search, Trash2 } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { db } from "../../db/db";
import type { Chat } from "../../core/types";

export function HistoryPage() {
  const [items, setItems] = useState<Chat[]>([]);
  const [query, setQuery] = useState("");

  async function refresh() {
    setItems((await db.chats.orderBy("updatedAt").reverse().toArray()).filter((chat) => !chat.archived));
  }

  useEffect(() => {
    void refresh();
  }, []);

  const filtered = useMemo(
    () => items.filter((chat) => chat.title.toLowerCase().includes(query.toLowerCase())),
    [items, query],
  );

  async function patch(id: string, values: Partial<Chat>) {
    await db.chats.update(id, { ...values, updatedAt: Date.now() });
    await refresh();
  }

  async function remove(id: string) {
    if (!window.confirm("Delete this conversation and all of its messages?")) return;
    await db.transaction("rw", db.chats, db.messages, async () => {
      await db.messages.where("chatId").equals(id).delete();
      await db.chats.delete(id);
    });
    await refresh();
  }

  return (
    <section className="page">
      <header className="page-header">
        <div><p className="eyebrow">Your workspace</p><h1>Conversations</h1></div>
        <div className="search-box"><Search size={17} /><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search chats" aria-label="Search chats" /></div>
      </header>

      <div className="list-card">
        {filtered.length === 0 ? (
          <div className="empty-state"><MessageSquareText size={28} /><h2>No conversations yet</h2><p>Your chats will stay here on this browser.</p></div>
        ) : filtered.map((chat) => (
          <div className="history-row" key={chat.id}>
            <Link to={`/chat/${chat.id}`} className="history-main">
              <strong>{chat.title}</strong>
              <span>{new Date(chat.updatedAt).toLocaleString()}</span>
            </Link>
            <div className="row-actions">
              <button className="icon-button" onClick={() => void patch(chat.id, { pinned: !chat.pinned })} aria-label={chat.pinned ? "Unpin chat" : "Pin chat"}><Pin size={17} fill={chat.pinned ? "currentColor" : "none"} /></button>
              <button className="icon-button" onClick={() => void patch(chat.id, { archived: true })} aria-label="Archive chat"><Archive size={17} /></button>
              <button className="icon-button danger" onClick={() => void remove(chat.id)} aria-label="Delete chat"><Trash2 size={17} /></button>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
