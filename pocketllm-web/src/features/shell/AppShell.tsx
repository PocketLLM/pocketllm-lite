import {
  BookOpenText,
  Bot,
  History,
  Menu,
  MessageSquarePlus,
  PanelLeftClose,
  Settings,
  Sparkles,
} from "lucide-react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { useState } from "react";

const navItems = [
  { to: "/", label: "Chat", icon: Sparkles, end: true },
  { to: "/chats", label: "History", icon: History },
  { to: "/knowledge", label: "Knowledge", icon: BookOpenText },
  { to: "/models", label: "Models", icon: Bot },
  { to: "/settings", label: "Settings", icon: Settings },
];

export function AppShell() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const navigate = useNavigate();

  return (
    <div className="app-shell">
      <header className="mobile-bar">
        <button className="icon-button" onClick={() => setMobileOpen(true)} aria-label="Open navigation">
          <Menu size={20} />
        </button>
        <div className="brand compact"><BrandMark /> PocketLLM</div>
        <button className="icon-button" onClick={() => navigate("/")} aria-label="New chat">
          <MessageSquarePlus size={20} />
        </button>
      </header>

      {mobileOpen && <button className="scrim" aria-label="Close navigation" onClick={() => setMobileOpen(false)} />}

      <aside className={`sidebar ${mobileOpen ? "is-open" : ""}`}>
        <div className="sidebar-top">
          <div className="brand"><BrandMark /> <span>PocketLLM</span></div>
          <button className="icon-button mobile-only" onClick={() => setMobileOpen(false)} aria-label="Close navigation">
            <PanelLeftClose size={19} />
          </button>
        </div>

        <button
          className="new-chat"
          onClick={() => {
            setMobileOpen(false);
            navigate("/");
          }}
        >
          <MessageSquarePlus size={18} />
          New chat
        </button>

        <nav className="nav-list" aria-label="Primary">
          {navItems.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              onClick={() => setMobileOpen(false)}
              className={({ isActive }) => `nav-item ${isActive ? "active" : ""}`}
            >
              <Icon size={18} />
              <span>{label}</span>
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-note">
          <span className="status-dot" />
          Local-first workspace
          <small>Your chats stay in this browser unless you choose a remote provider.</small>
        </div>
      </aside>

      <main id="main" className="workspace">
        <Outlet />
      </main>
    </div>
  );
}

function BrandMark() {
  return <span className="brand-mark" aria-hidden="true">P</span>;
}
