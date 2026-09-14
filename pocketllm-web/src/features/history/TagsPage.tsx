import { Tags } from "lucide-react";
import { useMemo } from "react";
import { Link } from "react-router-dom";
import { useLiveValue } from "../../core/live";
import type { Chat } from "../../core/types";
import { db } from "../../db/db";

export function TagsPage() {
  const chats = useLiveValue(() => db.chats.orderBy("updatedAt").reverse().toArray(), [] as Chat[], []);
  const groups = useMemo(() => {
    const map = new Map<string, Chat[]>();
    for (const chat of chats) {
      for (const tag of chat.tags ?? []) {
        map.set(tag, [...(map.get(tag) ?? []), chat]);
      }
    }
    return [...map.entries()].sort(([a], [b]) => a.localeCompare(b));
  }, [chats]);

  async function rename(oldTag: string) {
    const next = window.prompt("Rename tag", oldTag)?.trim();
    if (!next || next === oldTag) return;
    await db.transaction("rw", db.chats, async () => {
      for (const chat of chats.filter((item) => item.tags?.includes(oldTag))) {
        await db.chats.update(chat.id, { tags: [...new Set((chat.tags ?? []).map((tag) => tag === oldTag ? next : tag))], updatedAt: Date.now() });
      }
    });
  }

  async function remove(tag: string) {
    if (!confirm(`Remove tag "${tag}" from all chats?`)) return;
    await db.transaction("rw", db.chats, async () => {
      for (const chat of chats.filter((item) => item.tags?.includes(tag))) {
        await db.chats.update(chat.id, { tags: (chat.tags ?? []).filter((item) => item !== tag), updatedAt: Date.now() });
      }
    });
  }

  return (
    <section className="page">
      <header className="page-header"><div><p className="eyebrow">Organisation</p><h1>Tags</h1><p>Labels stay local and can be renamed without touching chat content.</p></div></header>
      {groups.length === 0 ? <div className="empty-state list-card"><Tags size={28} /><h2>No tags yet</h2><p>Add tags from Conversation history.</p></div> :
        <div className="tag-groups">
          {groups.map(([tag, tagged]) => (
            <section className="tag-group" key={tag}>
              <div className="tag-group-head"><h2>{tag}</h2><div><button className="text-action" onClick={() => void rename(tag)}>Rename</button><button className="text-action danger-text" onClick={() => void remove(tag)}>Remove</button></div></div>
              {tagged.map((chat) => <Link className="tag-chat-link" key={chat.id} to={`/chat/${chat.id}`}><strong>{chat.title}</strong><span>{new Date(chat.updatedAt).toLocaleDateString()}</span></Link>)}
            </section>
          ))}
        </div>}
    </section>
  );
}
