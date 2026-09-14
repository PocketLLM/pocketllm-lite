import {
  Activity,
  Archive,
  BarChart3,
  BookOpenText,
  Bot,
  Brain,
  ChevronDown,
  ChevronRight,
  FlaskConical,
  History,
  Menu,
  MessageSquarePlus,
  Mic2,
  Network,
  NotebookPen,
  PanelLeftClose,
  Settings,
  Sparkles,
  Star,
  Tags,
  UserRoundCog,
  WandSparkles,
  Workflow,
} from "lucide-react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { useMemo, useState } from "react";

const mainItems = [
  { to: "/", label: "Chat", icon: Sparkles, end: true },
  { to: "/chats", label: "History", icon: History },
  { to: "/knowledge", label: "Knowledge", icon: BookOpenText },
  { to: "/models", label: "Models", icon: Bot },
];

const libraryItems = [
  { to: "/personas", label: "Personas", icon: UserRoundCog },
  { to: "/prompts", label: "Prompts", icon: WandSparkles },
  { to: "/skills", label: "Skills", icon: Workflow },
  { to: "/memories", label: "Memories", icon: Brain },
  { to: "/notes", label: "Notes", icon: NotebookPen },
  { to: "/audio", label: "Audio", icon: Mic2 },
];

const utilityItems = [
  { to: "/starred", label: "Starred", icon: Star },
  { to: "/tags", label: "Tags", icon: Tags },
  { to: "/chats/archived", label: "Archived", icon: Archive },
];

const labItems = [
  { to: "/lab/prompt", label: "Prompt Lab", icon: FlaskConical },
  { to: "/lab/compare", label: "Compare", icon: BarChart3 },
  { to: "/lab/benchmark", label: "Benchmark", icon: Activity },
];

export function AppShell() {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [libraryOpen, setLibraryOpen] = useState(true);
  const [labOpen, setLabOpen] = useState(false);
  const navigate = useNavigate();
  const location = useLocation();

  const title = useMemo(() => {
    const mapping: Array<[RegExp, string]> = [
      [/^\/$|^\/chat\//, "Chat"],
      [/^\/knowledge/, "Knowledge"],
      [/^\/models/, "Models"],
      [/^\/providers/, "Providers"],
      [/^\/settings/, "Settings"],
      [/^\/network/, "Network"],
      [/^\/lab/, "Lab"],
    ];
    return mapping.find(([pattern]) => pattern.test(location.pathname))?.[1] ?? "PocketLLM";
  }, [location.pathname]);

  return (
    <div className="app-shell">
      <header className="mobile-bar">
        <button className="icon-button" onClick={() => setMobileOpen(true)} aria-label="Open navigation"><Menu size={20} /></button>
        <div className="brand compact"><BrandMark /> <span>{title}</span></div>
        <button className="icon-button" onClick={() => navigate("/")} aria-label="New chat"><MessageSquarePlus size={20} /></button>
      </header>

      {mobileOpen && <button className="scrim" aria-label="Close navigation" onClick={() => setMobileOpen(false)} />}

      <aside className={`sidebar ${mobileOpen ? "is-open" : ""}`}>
        <div className="sidebar-top">
          <div className="brand"><BrandMark /> <span>PocketLLM</span></div>
          <button className="icon-button mobile-only" onClick={() => setMobileOpen(false)} aria-label="Close navigation"><PanelLeftClose size={19} /></button>
        </div>

        <button className="new-chat" onClick={() => { setMobileOpen(false); navigate("/"); }}>
          <MessageSquarePlus size={18} /><span>New chat</span>
        </button>

        <nav className="nav-list" aria-label="Primary">
          {mainItems.map((item) => <NavItem key={item.to} {...item} onClick={() => setMobileOpen(false)} />)}

          <NavSection label="Library" open={libraryOpen} setOpen={setLibraryOpen}>
            {libraryItems.map((item) => <NavItem key={item.to} {...item} onClick={() => setMobileOpen(false)} />)}
          </NavSection>

          <NavSection label="Lab" open={labOpen} setOpen={setLabOpen}>
            {labItems.map((item) => <NavItem key={item.to} {...item} onClick={() => setMobileOpen(false)} />)}
          </NavSection>

          <div className="nav-divider" />
          {utilityItems.map((item) => <NavItem key={item.to} {...item} onClick={() => setMobileOpen(false)} />)}
          <NavItem to="/providers" label="Providers" icon={Network} onClick={() => setMobileOpen(false)} />
          <NavItem to="/stats" label="Statistics" icon={BarChart3} onClick={() => setMobileOpen(false)} />
          <NavItem to="/settings" label="Settings" icon={Settings} onClick={() => setMobileOpen(false)} />
        </nav>

        <div className="sidebar-note">
          <span className="status-dot" /> Local-first workspace
          <small>Your chats stay in this browser unless you choose a remote provider.</small>
        </div>
      </aside>

      <main id="main" className="workspace">
        <Outlet />
      </main>
    </div>
  );
}

function NavItem({ to, label, icon: Icon, end, onClick }: { to: string; label: string; icon: React.ComponentType<{ size?: number }>; end?: boolean; onClick: () => void }) {
  return (
    <NavLink to={to} end={end} onClick={onClick} className={({ isActive }) => `nav-item ${isActive ? "active" : ""}`}>
      <Icon size={17} /><span>{label}</span>
    </NavLink>
  );
}

function NavSection({ label, open, setOpen, children }: { label: string; open: boolean; setOpen: (value: boolean) => void; children: React.ReactNode }) {
  return (
    <div className="nav-section">
      <button className="nav-section-button" onClick={() => setOpen(!open)} aria-expanded={open}>
        <span>{label}</span>{open ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
      </button>
      {open && <div className="nav-section-items">{children}</div>}
    </div>
  );
}

function BrandMark() {
  return <span className="brand-mark" aria-hidden="true">P</span>;
}
