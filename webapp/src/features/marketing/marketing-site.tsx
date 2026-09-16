'use client';

/**
 * MarketingSite — React port of the repository's redesigned website
 * (2026): `index.html` + `pocketllm-website/` (styles, scripts,
 * assets, internal pages), pulled from GitHub main at commit 1863b49
 * and adapted to the single-route SPA:
 *
 *   • `#/` … home   • `#/releases` … downloads   • `#/changelog`
 *   • `#/docs`      • `#/privacy` / `#/terms` (legal)
 *
 * The static original's `site.js` behaviours are re-implemented as
 * effects: header scroll state, mobile nav toggle, reveal-on-scroll
 * (IntersectionObserver, reduced-motion aware), latest-release fetch
 * with the embedded fallback, and the dynamic year.
 *
 * Integration with the web app (the product's own §18 requirement):
 *   • "Web App" entry points in the nav, downloads panel and footer
 *     navigate to `#/app`.
 *   • The homepage command bar carries its prompt into the app: on
 *     Enter the text is deposited in `marketingDraft` and the app
 *     home composer picks it up — the marketing demo funnels into
 *     the real product.
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import { Cpu, FileSearch, Server, Smartphone } from 'lucide-react';
import { PRIVACY_HTML, TERMS_HTML } from './legal-content';
import { universalAPK, type ReleaseInfo } from './releases-data';
import {
  ChangelogPage,
  DocsPage,
  getReleases,
  LegalPage,
  ReleasesPage,
} from './marketing-pages';
import { router } from '@/lib/core/router';
import { marketingDraft } from '@/lib/core/deep-link';

/** Marketing sub-pages addressable via hash routes. */
type MktPage = 'home' | 'releases' | 'changelog' | 'docs' | 'privacy' | 'terms';

const GITHUB_REPO = 'https://github.com/PocketLLM/pocketllm-lite';

/** Hash → page (anything unknown falls back to home). */
function hashToPage(hash: string): MktPage {
  if (hash === '#/releases') return 'releases';
  if (hash === '#/changelog') return 'changelog';
  if (hash === '#/docs') return 'docs';
  if (hash === '#/privacy') return 'privacy';
  if (hash === '#/terms') return 'terms';
  return 'home';
}

/** Per-page <title> (matches the static pages' own titles). */
const PAGE_TITLES: Record<MktPage, string> = {
  home: 'PocketLLM Lite — Your AI, on your terms',
  releases: 'Downloads & Releases — PocketLLM Lite',
  changelog: 'Changelog — PocketLLM Lite',
  docs: 'Docs — PocketLLM Lite',
  privacy: 'Privacy Policy — PocketLLM Lite',
  terms: 'Terms of Service — PocketLLM Lite',
};

/** GitHub mark (same inline SVG the static nav uses). */
function GithubMark() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 .7a11.3 11.3 0 0 0-3.6 22c.6.1.8-.3.8-.6v-2.2c-3.3.7-4-1.4-4-1.4-.6-1.4-1.4-1.8-1.4-1.8-1.1-.8.1-.8.1-.8 1.2.1 1.9 1.3 1.9 1.3 1.1 1.9 2.9 1.3 3.6 1 .1-.8.4-1.3.8-1.6-2.7-.3-5.5-1.3-5.5-5.9 0-1.3.5-2.4 1.2-3.2-.1-.3-.5-1.5.1-3.1 0 0 1-.3 3.3 1.2A11.6 11.6 0 0 1 12 6.3c1 0 2 .1 3 .4 2.3-1.5 3.3-1.2 3.3-1.2.6 1.6.2 2.8.1 3.1.8.9 1.2 1.9 1.2 3.2 0 4.6-2.8 5.6-5.5 5.9.4.4.8 1.1.8 2.2v3.2c0 .4.2.7.8.6A11.3 11.3 0 0 0 12 .7Z" />
    </svg>
  );
}

export function MarketingSite() {
  const [page, setPage] = useState<MktPage>('home');
  const [navOpen, setNavOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [latest, setLatest] = useState<ReleaseInfo | null>(null);
  const [command, setCommand] = useState('');
  const rootRef = useRef<HTMLDivElement | null>(null);
  const mainRef = useRef<HTMLElement | null>(null);
  const commandInputRef = useRef<HTMLInputElement | null>(null);

  /* ------------------ hash routing ------------------ */
  useEffect(() => {
    const apply = () => setPage(hashToPage(window.location.hash));
    apply();
    window.addEventListener('hashchange', apply);
    return () => window.removeEventListener('hashchange', apply);
  }, []);

  /* ------------------ per-page title + scroll reset ------------------ */
  useEffect(() => {
    document.title = PAGE_TITLES[page];
    window.scrollTo({ top: 0 });
    setNavOpen(false);
  }, [page]);

  /* ------------------ header scroll state (site.js initNav) ------------------ */
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 18);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  /* ------------------ latest release (site.js initHomeRelease) ------------------ */
  useEffect(() => {
    let cancelled = false;
    void getReleases().then((releases) => {
      if (!cancelled && releases.length) setLatest(releases[0]);
    });
    return () => {
      cancelled = true;
    };
  }, []);

  /* ------------------ reveal on scroll (site.js initReveal) ------------------ */
  // Re-run when the page or the release data (which gates card markup)
  // changes. Items already visible keep their class.
  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    const items = Array.from(
      root.querySelectorAll<HTMLElement>('.reveal:not(.is-visible)')
    );
    if (!items.length) return;
    if (
      window.matchMedia('(prefers-reduced-motion: reduce)').matches ||
      !('IntersectionObserver' in window)
    ) {
      items.forEach((el) => el.classList.add('is-visible'));
      return;
    }
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-visible');
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: '0px 0px -30px' }
    );
    items.forEach((el) => observer.observe(el));
    return () => observer.disconnect();
  }, [page, latest]);

  /* ------------------ navigation helpers ------------------ */
  /** In-page anchor: never touches the URL hash (the router owns it). */
  const scrollToAnchor = useCallback(
    (e: React.MouseEvent<HTMLAnchorElement>, anchor: string) => {
      e.preventDefault();
      setNavOpen(false);
      if (page !== 'home') {
        router.navigate('/');
        // Two frames: React commit + browser layout, then scroll.
        requestAnimationFrame(() =>
          requestAnimationFrame(() =>
            document
              .getElementById(anchor)
              ?.scrollIntoView({ behavior: 'smooth', block: 'start' })
          )
        );
      } else {
        document
          .getElementById(anchor)
          ?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    },
    [page]
  );

  /** Command bar → web app hand-off (the site demos the real product). */
  const launchInApp = useCallback(() => {
    const text = command.trim();
    if (!text) {
      commandInputRef.current?.focus();
      return;
    }
    marketingDraft.text = text.slice(0, 2000);
    router.navigate('/app');
  }, [command]);

  /** Chip click → fill the command bar and focus it (site.js setCommand). */
  const setCommandText = useCallback((text: string) => {
    setCommand(text);
    commandInputRef.current?.focus();
  }, []);

  const skipToMain = (e: React.MouseEvent<HTMLAnchorElement>) => {
    e.preventDefault();
    mainRef.current?.focus();
  };

  const apkUrl = latest ? universalAPK(latest)?.browser_download_url : undefined;
  const year = new Date().getFullYear();

  return (
    <div className="mkt" ref={rootRef}>
      <a className="skip-link" href="#main" onClick={skipToMain}>
        Skip to content
      </a>

      {/* ---------------- header ---------------- */}
      <header className={`site-header${scrolled ? ' is-scrolled' : ''}`} data-header>
        <div className="shell nav-wrap">
          <a
            className="brand"
            href="#/"
            aria-label="PocketLLM Lite home"
            onClick={(e) => {
              e.preventDefault();
              if (page !== 'home') router.navigate('/');
              else window.scrollTo({ top: 0 });
            }}
          >
            <img className="brand-logo" src="/pocketllm-website/assets/logo.png" alt="" />
            <span>PocketLLM Lite</span>
          </a>
          <button
            className="nav-toggle"
            type="button"
            aria-label="Open navigation"
            aria-expanded={navOpen}
            onClick={() => setNavOpen((open) => !open)}
          >
            <span></span>
            <span></span>
            <span></span>
          </button>
          <nav className={`nav-links${navOpen ? ' is-open' : ''}`} data-nav>
            <a href="#features" onClick={(e) => scrollToAnchor(e, 'features')}>
              Features
            </a>
            <a href="#how-it-runs" onClick={(e) => scrollToAnchor(e, 'how-it-runs')}>
              Runtimes
            </a>
            <a href="#/releases">Downloads</a>
            <a href="#/changelog">Changelog</a>
            <a href="#/docs">Docs</a>
            <a className="nav-app-link" href="#/app" title="Open the local-first web app">
              Web App
            </a>
            <a
              className="nav-github"
              href={GITHUB_REPO}
              target="_blank"
              rel="noreferrer"
              aria-label="PocketLLM Lite on GitHub"
            >
              <GithubMark />
            </a>
            {apkUrl ? (
              <a
                className="button button-pink button-small"
                href={apkUrl}
                data-latest-download
              >
                Download
              </a>
            ) : (
              <a className="button button-pink button-small" href="#/releases">
                Download
              </a>
            )}
          </nav>
        </div>
      </header>

      {/* ---------------- main ---------------- */}
      <main id="main" ref={mainRef} tabIndex={-1}>
        {page === 'home' && (
          <HomePage
            latest={latest}
            apkUrl={apkUrl}
            command={command}
            setCommand={setCommand}
            commandInputRef={commandInputRef}
            launchInApp={launchInApp}
            setCommandText={setCommandText}
            scrollToAnchor={scrollToAnchor}
          />
        )}
        {page === 'releases' && <ReleasesPage />}
        {page === 'changelog' && <ChangelogPage />}
        {page === 'docs' && <DocsPage />}
        {page === 'privacy' && (
          <section className="legal-page">
            <LegalPage html={PRIVACY_HTML} />
          </section>
        )}
        {page === 'terms' && (
          <section className="legal-page">
            <LegalPage html={TERMS_HTML} />
          </section>
        )}
      </main>

      {/* ---------------- footer ---------------- */}
      <footer className="site-footer">
        <div className="footer-sky" aria-hidden="true"></div>
        <div className="shell footer-grid">
          <div className="footer-brand">
            <a className="brand brand-light" href="#/" onClick={(e) => { e.preventDefault(); if (page !== 'home') router.navigate('/'); }}>
              <img className="brand-logo" src="/pocketllm-website/assets/logo.png" alt="" />
              <span>PocketLLM Lite</span>
            </a>
            <p>Local-first AI with visible boundaries.</p>
          </div>
          <div>
            <h3>Product</h3>
            <a href="#features" onClick={(e) => scrollToAnchor(e, 'features')}>Features</a>
            <a href="#/releases">Downloads</a>
            <a href="#/changelog">Changelog</a>
            <a href="#/app">Web App</a>
          </div>
          <div>
            <h3>Project</h3>
            <a href="#/docs">Docs</a>
            <a href={GITHUB_REPO} target="_blank" rel="noreferrer">GitHub</a>
            <a href={`${GITHUB_REPO}/issues`} target="_blank" rel="noreferrer">Issues</a>
          </div>
          <div>
            <h3>Legal</h3>
            <a href="#/privacy">Privacy</a>
            <a href="#/terms">Terms</a>
            <a href={`${GITHUB_REPO}/blob/main/LICENSE`} target="_blank" rel="noreferrer">MIT License</a>
          </div>
        </div>
        <div className="shell footer-bottom">
          <span>© {year} PocketLLM Lite.</span>
          <span>Open source, for everyone.</span>
        </div>
      </footer>
    </div>
  );
}

/* ================================================================== */
/* Home page — 1:1 port of index.html's <main>                         */
/* ================================================================== */

interface HomePageProps {
  latest: ReleaseInfo | null;
  apkUrl: string | undefined;
  command: string;
  setCommand: (value: string) => void;
  commandInputRef: React.RefObject<HTMLInputElement | null>;
  launchInApp: () => void;
  setCommandText: (text: string) => void;
  scrollToAnchor: (e: React.MouseEvent<HTMLAnchorElement>, anchor: string) => void;
}

function HomePage({
  latest,
  apkUrl,
  command,
  setCommand,
  commandInputRef,
  launchInApp,
  setCommandText,
  scrollToAnchor,
}: HomePageProps) {
  const versionText = latest
    ? `${latest.tag_name} · ${latest.prerelease ? 'pre-release' : 'stable'}`
    : 'Latest release';

  return (
    <>
      {/* ---------------- hero ---------------- */}
      <section className="hero section-dark-text">
        <div
          className="hero-bg"
          role="img"
          aria-label="Dreamlike sunset above a city, with a developer and cat using a laptop"
        ></div>
        <div className="hero-wash"></div>
        <div className="shell hero-grid">
          <div className="hero-copy reveal">
            <p className="script-kicker">Your Personal</p>
            <h1>AI, on your terms.</h1>
            <p className="hero-lede">
              PocketLLM Lite is a local-first AI workspace built around a simple
              rule: your conversations, documents, memories and models should
              stay under your control.
            </p>
            <div className="hero-actions">
              {apkUrl ? (
                <a className="button button-pink" href={apkUrl} data-latest-download>
                  Download for Android <span>→</span>
                </a>
              ) : (
                <a className="button button-pink" href="#/releases" data-latest-download>
                  Download for Android <span>→</span>
                </a>
              )}
              <a className="button button-paper" href="#features" onClick={(e) => scrollToAnchor(e, 'features')}>
                Explore features
              </a>
            </div>
            <div className="hero-orbit" aria-label="What you get">
              <div className="orbit-tile">
                <span className="orbit-icon" aria-hidden="true">
                  <Smartphone strokeWidth={2.2} />
                </span>
                <span className="orbit-label">Android</span>
              </div>
              <div className="orbit-tile">
                <span className="orbit-icon" aria-hidden="true">
                  <Cpu strokeWidth={2.2} />
                </span>
                <span className="orbit-label">Local models</span>
              </div>
              <div className="orbit-tile">
                <span className="orbit-icon" aria-hidden="true">
                  <FileSearch strokeWidth={2.2} />
                </span>
                <span className="orbit-label">Doc RAG</span>
              </div>
              <div className="orbit-tile">
                <span className="orbit-icon" aria-hidden="true">
                  <Server strokeWidth={2.2} />
                </span>
                <span className="orbit-label">Ollama</span>
              </div>
            </div>
          </div>
          <div className="hero-version reveal delay-1" aria-live="polite">
            <span className="status-dot"></span>
            <span data-latest-version>{versionText}</span>
          </div>
        </div>
      </section>

      {/* ---------------- manifesto + command bar ---------------- */}
      <section className="manifesto paper-grid section-pad">
        <div className="shell narrow center reveal">
          <div className="mini-orbit" aria-hidden="true">
            <span title="Local GGUF Models">GGUF</span>
            <span title="Document RAG">RAG</span>
            <span title="Confirmed Tools">TOOLS</span>
            <span title="Ollama Bridge">OLLAMA</span>
          </div>
          <p className="script-kicker pink">PocketLLM Lite</p>
          <h2 className="display-title">
            It’s not another AI account.
            <br /> It’s your own AI workspace.
          </h2>
          <p className="section-lede">
            No cloud profile is required to chat, save history, use personas,
            build local memory, or work with documents. Network features are
            explicit, inspectable and optional.
          </p>

          {/* Interactive command bar — Enter carries the prompt into the web app */}
          <form
            className="command-bar-box"
            onSubmit={(e) => {
              e.preventDefault();
              launchInApp();
            }}
          >
            <span className="command-orb" aria-hidden="true">
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <circle cx="11" cy="11" r="8"></circle>
                <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
              </svg>
            </span>
            <input
              ref={commandInputRef}
              type="text"
              className="command-input"
              id="commandInput"
              placeholder="Try searching 'photos from summer' or /notes..."
              aria-label="Search prompt"
              value={command}
              onChange={(e) => setCommand(e.target.value)}
            />
          </form>
          <p className="command-note">
            Press Enter to continue in the web app — your prompt carries over.
          </p>
          <div className="command-chips" aria-label="Quick prompts">
            <button className="chip" type="button" onClick={() => setCommandText('Summarize my PDF notes')}>
              ✦ Summarize notes
            </button>
            <button className="chip" type="button" onClick={() => setCommandText('Explain quantum entanglement')}>
              ✦ Explain quantum physics
            </button>
            <button className="chip" type="button" onClick={() => setCommandText('Run Phi-3 Mini GGUF on-device')}>
              ✦ Run Phi-3 GGUF
            </button>
            <button className="chip" type="button" onClick={() => setCommandText('Audit network traffic and permissions')}>
              ✦ Audit network log
            </button>
          </div>

          <a className="text-link" href="#/docs">
            See how local-first works <span>↗</span>
          </a>
        </div>
      </section>

      <div className="cloud-break" aria-hidden="true"></div>

      {/* ---------------- story: own your data ---------------- */}
      <section className="story section-pad" id="features">
        <div className="shell story-grid">
          <div className="story-copy reveal">
            <p className="script-kicker blue">Own your data</p>
            <h2 className="display-title">
              The app is yours,
              <br /> the data is yours.
            </h2>
            <p>
              Chats, local memories, prompts, personas, skills and document
              indexes stay in the app sandbox. Strict Offline can block
              non-loopback app-managed network traffic before a request leaves
              the app.
            </p>
            <div className="story-points">
              <div>
                <strong>Private by default</strong>
                <span>No analytics or advertising SDK required for the core experience.</span>
              </div>
              <div>
                <strong>Inspect the boundary</strong>
                <span>Network destinations and purposes are visible in the audit log.</span>
              </div>
              <div>
                <strong>Back it up</strong>
                <span>Password-derived AES-256-GCM backups are portable and verifiable.</span>
              </div>
            </div>

            {/* Interactive dialogue card */}
            <div className="chat-preview-box">
              <div className="chat-preview-head">
                <span className="dot"></span>
                <strong>Local Assistant · Sandbox Active</strong>
              </div>
              <div className="chat-bubble-u">
                Did you know PocketLLM runs completely offline?
              </div>
              <div className="chat-bubble-a">
                Yes! All model weights run directly on your phone’s NPU/CPU.
                Chats, document indexes, and private memories remain strictly
                inside your device sandbox.
              </div>
            </div>
          </div>
          <figure className="story-visual reveal delay-1">
            <img
              src="/pocketllm-website/assets/workspace-sunrise.webp"
              alt="PocketLLM-inspired local AI workspace overlooking a sunrise city"
              loading="lazy"
              decoding="async"
            />
          </figure>
        </div>
      </section>

      {/* ---------------- feature showcase ---------------- */}
      <section className="feature-showcase section-pad-sm">
        <div className="shell">
          <div className="center narrow reveal">
            <p className="script-kicker pink">Explore</p>
            <h2 className="display-title">Tools for your thinking.</h2>
            <p className="section-lede">
              Not a single giant magic button. A proper local workspace with
              composable pieces you can understand and control.
            </p>
          </div>
          <div className="feature-grid">
            <article className="feature-card reveal">
              <span className="feature-no">01</span>
              <h3>Documents &amp; RAG</h3>
              <p>
                Ingest PDF, TXT, Markdown and CSV files. Use lexical, semantic
                or hybrid retrieval with source-aware context.
              </p>
            </article>
            <article className="feature-card reveal delay-1">
              <span className="feature-no">02</span>
              <h3>Personas &amp; skills</h3>
              <p>
                Build reusable assistants, prompts and skills. PocketLLM
                composes them into the generation pipeline instead of hiding
                the prompt stack.
              </p>
            </article>
            <article className="feature-card reveal delay-2">
              <span className="feature-no">03</span>
              <h3>Memory, locally</h3>
              <p>
                Inspect, pin, disable and supersede local memories. Retrieval
                falls back honestly when embeddings are unavailable.
              </p>
            </article>
            <article className="feature-card reveal">
              <span className="feature-no">04</span>
              <h3>Confirmed tools</h3>
              <p>
                Calculator, notes, reminders, clipboard, links and web search
                use schema validation and visible confirmation where required.
              </p>
            </article>
            <article className="feature-card reveal delay-1">
              <span className="feature-no">05</span>
              <h3>Voice &amp; audio</h3>
              <p>
                Dictate, listen and transcribe through supported local or
                platform paths, with capabilities shown instead of guessed.
              </p>
            </article>
            <article className="feature-card reveal delay-2">
              <span className="feature-no">06</span>
              <h3>Honest model setup</h3>
              <p>
                Browse, import and manage models with explicit source, size,
                license and compatibility state. Unknown stays unknown.
              </p>
            </article>
          </div>
          <figure className="wide-art reveal">
            <img
              src="/pocketllm-website/assets/feature-collage.webp"
              alt="Illustrated PocketLLM feature workspace showing local documents, runtimes, tools, privacy and storage"
              loading="lazy"
              decoding="async"
            />
          </figure>
        </div>
      </section>

      {/* ---------------- runtimes journey ---------------- */}
      <section className="journey section-pad" id="how-it-runs">
        <div className="shell journey-grid">
          <figure className="journey-art reveal">
            <img
              src="/pocketllm-website/assets/runtime-journey.webp"
              alt="A retro-futuristic aircraft flying through clouds carrying local AI runtimes"
              loading="lazy"
              decoding="async"
            />
          </figure>
          <div className="journey-copy reveal delay-1">
            <p className="script-kicker coral">Choose your route</p>
            <h2 className="display-title">
              One workspace.
              <br /> More than one runtime.
            </h2>
            <p>
              PocketLLM separates the product from the inference backend. Pick
              the route that makes sense for your device and your privacy
              boundary.
            </p>
            <div className="runtime-list">
              <div>
                <span>01</span>
                <strong>On-device GGUF</strong>
                <small>Compatible local models through the supported mobile runtime.</small>
              </div>
              <div>
                <span>02</span>
                <strong>Ollama</strong>
                <small>Use a loopback or trusted LAN Ollama endpoint you control.</small>
              </div>
              <div>
                <span>03</span>
                <strong>OpenAI-compatible</strong>
                <small>
                  Connect a configurable endpoint only when you want remote
                  inference.
                </small>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ---------------- downloads ---------------- */}
      <section className="downloads section-pad" id="download">
        <div className="shell">
          <div className="center narrow reveal">
            <p className="script-kicker pink">Download</p>
            <h2 className="display-title">Get PocketLLM Lite.</h2>
            <p className="section-lede">
              Android builds are published on GitHub with release notes and
              checksums. Choose the universal APK if you are unsure about your
              device ABI.
            </p>
          </div>
          <div className="download-panel reveal" data-home-release>
            <div className="download-panel-main">
              <div>
                <span className="eyebrow">Current GitHub release</span>
                <h3 data-home-release-name>
                  {latest ? latest.name || latest.tag_name : 'PocketLLM Lite'}
                </h3>
                <p data-home-release-date>
                  {latest
                    ? `${formatDateSafe(latest.published_at)} · ${
                        latest.prerelease ? 'Engineering pre-release' : 'Stable release'
                      }`
                    : 'Loading release information…'}
                </p>
              </div>
              <div className="download-panel-actions">
                <a className="button button-pink" href="#/releases">
                  Choose APK
                </a>
                <a className="button button-outline" href="#/changelog">
                  Read changelog
                </a>
              </div>
            </div>
            <div className="download-platforms">
              <div className="platform active">
                <strong>Android</strong>
                <span>Available now</span>
              </div>
              {/* The web edition exists — this port IS it. Entry point into the app. */}
              <a className="platform platform-link" href="#/app">
                <strong>Web</strong>
                <span>Open the local-first edition →</span>
              </a>
              <div className="platform">
                <strong>Source</strong>
                <span>MIT licensed on GitHub</span>
              </div>
            </div>
          </div>
          <div className="center release-links reveal">
            <a className="text-link" href="#/releases">
              Browse every release and older APK <span>→</span>
            </a>
            <a className="text-link" href="#/changelog">
              Full version history <span>→</span>
            </a>
          </div>
        </div>
      </section>

      {/* ---------------- open source ---------------- */}
      <section className="open-source section-pad">
        <div className="open-source-bg" aria-hidden="true"></div>
        <div className="shell open-source-grid">
          <div className="open-source-copy reveal">
            <p className="script-kicker gold">For builders</p>
            <h2 className="display-title light">
              Build it for yourself,
              <br /> see it run everywhere.
            </h2>
            <p>
              PocketLLM Lite is MIT licensed. Read the source, reproduce the
              behavior, inspect the tests and contribute focused improvements.
              The project prefers evidence over marketing folklore, which is
              refreshing in AI land.
            </p>
            <div className="hero-actions">
              <a
                className="button button-pink"
                href={GITHUB_REPO}
                target="_blank"
                rel="noreferrer"
              >
                Star on GitHub <span>↗</span>
              </a>
              <a
                className="button button-ghost-light"
                href={`${GITHUB_REPO}/blob/main/CONTRIBUTING.md`}
                target="_blank"
                rel="noreferrer"
              >
                Contributor guide
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* ---------------- closing ---------------- */}
      <section className="closing section-pad">
        <div className="shell narrow center reveal">
          <div className="closing-sky" aria-hidden="true"></div>
          <p className="script-kicker blue">Local AI, properly</p>
          <h2 className="display-title">
            A smaller app with
            <br /> clearer boundaries.
          </h2>
          <p className="section-lede">
            PocketLLM is being built around inspectable capabilities, portable
            data and runtime choice instead of tying your AI workspace to one
            vendor or one account.
          </p>
          <a className="button button-dark" href="#/docs">
            Read the docs
          </a>
        </div>
      </section>
    </>
  );
}

/** Local import of the shared date formatter (keeps HomePage self-contained). */
function formatDateSafe(input: string): string {
  const date = new Date(input);
  if (Number.isNaN(date.valueOf())) return 'Unknown date';
  return new Intl.DateTimeFormat('en', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  }).format(date);
}
