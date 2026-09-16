'use client';

/**
 * Marketing sub-pages — ports of the repository's internal website
 * pages (`pocketllm-website/releases.html`, `changelog.html`,
 * `docs.html`, `privacy.html`, `terms.html`) rendered inside the
 * single-route SPA as hash destinations (#/releases, #/changelog,
 * #/docs, #/privacy, #/terms).
 *
 * Release data comes from `releases-data.ts` (GitHub API with an
 * embedded fallback). The legal pages reuse the exact PRIVACY_HTML /
 * TERMS_HTML markup strings — repo-owned static content, never user
 * input.
 */

import { useEffect, useMemo, useState } from 'react';
import {
  assetKind,
  escapeHTML,
  fetchReleases,
  formatBytes,
  formatDate,
  renderMarkdown,
  type ReleaseAsset,
  type ReleaseInfo,
} from './releases-data';

/* ------------------------------------------------------------------ */
/* Shared release cache (one request for shell + both pages)           */
/* ------------------------------------------------------------------ */

let releaseCache: ReleaseInfo[] | null = null;
let releasePromise: Promise<ReleaseInfo[]> | null = null;

/** Get releases (cached) — one fetch per browser session. */
export function getReleases(): Promise<ReleaseInfo[]> {
  if (releaseCache) return Promise.resolve(releaseCache);
  if (!releasePromise) {
    releasePromise = fetchReleases().then((list) => {
      releaseCache = list;
      return list;
    });
  }
  return releasePromise;
}

/** Synchronous peek at the cache (null until the first fetch settles). */
export function peekReleases(): ReleaseInfo[] | null {
  return releaseCache;
}

/* ------------------------------------------------------------------ */
/* Downloads / Releases page                                           */
/* ------------------------------------------------------------------ */

export function ReleasesPage() {
  const [releases, setReleases] = useState<ReleaseInfo[] | null>(peekReleases());
  const [search, setSearch] = useState('');

  useEffect(() => {
    if (!releases) void getReleases().then(setReleases);
  }, [releases]);

  const filtered = useMemo(() => {
    if (!releases) return null;
    const value = search.trim().toLowerCase();
    if (!value) return releases;
    return releases.filter((release) =>
      `${release.tag_name} ${release.name ?? ''}`.toLowerCase().includes(value)
    );
  }, [releases, search]);

  return (
    <>
      <section className="internal-hero">
        <div className="shell reveal is-visible">
          <p className="script-kicker pink">Downloads</p>
          <h1 className="display-title">
            Current builds.
            <br /> Older versions too.
          </h1>
          <p className="internal-lede">
            Every published GitHub release is listed here with attached APKs. New
            releases appear automatically from the repository API, so this page
            does not need a manual version bump every time you ship.
          </p>
          <div className="search-row">
            <input
              className="search-input"
              type="search"
              placeholder="Search version or release name…"
              aria-label="Search releases"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <span className="eyebrow">
              {releases
                ? `${releases.length} published release${releases.length === 1 ? '' : 's'}`
                : 'Loading…'}
            </span>
          </div>
        </div>
      </section>

      <section className="section-pad-sm">
        <div className="shell">
          <div className="content-card reveal is-visible">
            <p className="script-kicker blue">Which APK?</p>
            <h2>Pick the build that fits.</h2>
            <p>
              If you do not know your device architecture, use the universal
              Android APK whenever the release provides one.
            </p>
            <div className="abi-guide">
              <div>
                <strong>Universal</strong>
                <span>
                  Safest choice when you are unsure. Larger file, broad
                  compatibility.
                </span>
              </div>
              <div>
                <strong>arm64-v8a</strong>
                <span>
                  Most modern Android phones. Usually the best smaller download.
                </span>
              </div>
              <div>
                <strong>armeabi-v7a / x86_64</strong>
                <span>
                  Older 32-bit ARM devices or compatible emulator/x86 hardware.
                </span>
              </div>
            </div>
          </div>

          <div className="release-stack">
            {!filtered ? (
              <div className="load-state">Loading releases from GitHub…</div>
            ) : filtered.length === 0 ? (
              <div className="load-state">
                No releases match “{escapeHTML(search)}”.
              </div>
            ) : (
              filtered.map((release) => (
                <ReleaseCard key={release.tag_name} release={release} />
              ))
            )}
          </div>

          <div className="center release-links reveal is-visible">
            <a className="text-link" href="#/changelog">
              Full version history <span>→</span>
            </a>
            <a
              className="text-link"
              href="https://github.com/PocketLLM/pocketllm-lite/releases"
              target="_blank"
              rel="noreferrer"
            >
              Browse releases on GitHub <span>↗</span>
            </a>
          </div>
        </div>
      </section>
    </>
  );
}

/** One release card: header (badge/tag/meta) + notes + asset list. */
function ReleaseCard({ release }: { release: ReleaseInfo }) {
  return (
    <article className="release-card">
      <div className="release-head">
        <div>
          <span className={`release-badge ${release.prerelease ? '' : 'stable'}`}>
            {release.prerelease ? 'Pre-release' : 'Stable'}
          </span>
          <h2>{release.tag_name}</h2>
          <div className="release-meta">
            <span>{release.name || release.tag_name}</span>
            <span>{formatDate(release.published_at)}</span>
          </div>
        </div>
        <a
          className="button button-outline button-small"
          href={release.html_url}
          target="_blank"
          rel="noreferrer"
        >
          GitHub release ↗
        </a>
      </div>
      <div className="release-body">
        {/* Release notes are escaped by renderMarkdown before use. */}
        <div
          dangerouslySetInnerHTML={{
            __html: renderMarkdown(release.body || 'No release notes supplied.'),
          }}
        />
        {release.assets?.length ? (
          <div className="asset-list">
            {release.assets.map((asset) => (
              <AssetRow key={asset.name} asset={asset} />
            ))}
          </div>
        ) : (
          <p>No downloadable assets are attached to this release.</p>
        )}
      </div>
    </article>
  );
}

function AssetRow({ asset }: { asset: ReleaseAsset }) {
  const digest = asset.digest
    ? ` · ${escapeHTML(asset.digest.replace('sha256:', 'SHA ')).slice(0, 24)}…`
    : '';
  return (
    <div className="asset">
      <div className="asset-main">
        <span className="asset-name" title={asset.name}>
          {asset.name}
        </span>
        <span className="asset-sub">
          {assetKind(asset.name)} · {formatBytes(asset.size)}
          {digest}
        </span>
      </div>
      <a href={asset.browser_download_url}>Download ↓</a>
    </div>
  );
}

/* ------------------------------------------------------------------ */
/* Changelog page                                                      */
/* ------------------------------------------------------------------ */

export function ChangelogPage() {
  const [releases, setReleases] = useState<ReleaseInfo[] | null>(peekReleases());
  const [search, setSearch] = useState('');

  useEffect(() => {
    if (!releases) void getReleases().then(setReleases);
  }, [releases]);

  const value = search.trim().toLowerCase();
  const items = (releases ?? []).filter(
    (release) =>
      !value ||
      `${release.tag_name} ${release.name ?? ''} ${release.body ?? ''}`
        .toLowerCase()
        .includes(value)
  );

  return (
    <>
      <section className="internal-hero">
        <div className="shell reveal is-visible">
          <p className="script-kicker coral">Version history</p>
          <h1 className="display-title">
            What changed,
            <br /> and why it matters.
          </h1>
          <p className="internal-lede">
            Release notes are loaded directly from GitHub and rendered as a
            searchable timeline. No stale marketing paraphrase hiding three
            versions behind reality.
          </p>
          <div className="search-row">
            <input
              className="search-input"
              type="search"
              placeholder="Search release notes…"
              aria-label="Search changelog"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
        </div>
      </section>

      <section className="section-pad-sm">
        <div className="shell">
          <div className="timeline">
            {!releases ? (
              <div className="load-state">Loading changelog from GitHub…</div>
            ) : items.length === 0 ? (
              <div className="load-state">
                No release notes match “{escapeHTML(search)}”.
              </div>
            ) : (
              items.map((release, index) => (
                <details key={release.tag_name} open={index === 0}>
                  <summary>
                    <span className="timeline-version">{release.tag_name}</span>
                    <span className="timeline-title">
                      {release.name || release.tag_name}
                    </span>
                    <span className="timeline-date">
                      {formatDate(release.published_at)}
                    </span>
                  </summary>
                  <div className="timeline-content">
                    <div
                      dangerouslySetInnerHTML={{
                        __html: renderMarkdown(
                          release.body || 'No release notes supplied.'
                        ),
                      }}
                    />
                    <p>
                      <a
                        className="text-link"
                        href={release.html_url}
                        target="_blank"
                        rel="noreferrer"
                      >
                        Open release on GitHub ↗
                      </a>
                    </p>
                  </div>
                </details>
              ))
            )}
          </div>
        </div>
      </section>
    </>
  );
}

/* ------------------------------------------------------------------ */
/* Docs page                                                           */
/* ------------------------------------------------------------------ */

const DOCS_SECTIONS = [
  { id: 'install', label: 'Install' },
  { id: 'models', label: 'Models' },
  { id: 'ollama', label: 'Ollama' },
  { id: 'knowledge', label: 'Knowledge Base' },
  { id: 'privacy', label: 'Privacy' },
  { id: 'backup', label: 'Backup' },
  { id: 'evidence', label: 'Evidence' },
];

export function DocsPage() {
  const scrollTo = (e: React.MouseEvent<HTMLAnchorElement>, id: string) => {
    e.preventDefault();
    document
      .getElementById(id)
      ?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  return (
    <>
      <section className="internal-hero">
        <div className="shell reveal is-visible">
          <p className="script-kicker blue">Getting started</p>
          <h1 className="display-title">
            Local AI without
            <br /> the mystery meat.
          </h1>
          <p className="internal-lede">
            This page is the short path. For implementation evidence,
            verification and exact limitations, the repository documentation
            remains the source of truth.
          </p>
        </div>
      </section>

      <section className="section-pad-sm">
        <div className="shell page-grid">
          <aside className="page-aside" aria-label="Documentation sections">
            {DOCS_SECTIONS.map((s) => (
              <a key={s.id} href={`#${s.id}`} onClick={(e) => scrollTo(e, s.id)}>
                {s.label}
              </a>
            ))}
          </aside>
          <article className="content-card">
            <section id="install">
              <p className="script-kicker pink">01</p>
              <h2>Install the Android build.</h2>
              <p>
                Open the <a href="#/releases">Downloads page</a>, choose the
                universal APK if you are unsure about ABI, and review the signing
                notice for that release before installation. Current engineering
                prereleases may be debug-signed and can require uninstalling a
                differently signed build before installation.
              </p>
            </section>
            <section id="models">
              <p className="script-kicker blue">02</p>
              <h2>Choose how the model runs.</h2>
              <h3>Local GGUF / managed models</h3>
              <p>
                Use the Model Store or import a GGUF file. PocketLLM validates
                the file header and source evidence it has, but a valid GGUF
                header does not guarantee that every architecture will load on
                every device.
              </p>
              <h3>Capabilities</h3>
              <p>
                Vision, tools, embeddings and other capabilities remain unknown
                unless the manifest, provider configuration or runtime evidence
                establishes them. The app intentionally fails closed when a
                capability is unverified.
              </p>
            </section>
            <section id="ollama">
              <p className="script-kicker coral">03</p>
              <h2>Connect Ollama.</h2>
              <p>
                Start Ollama on your own machine, pull the model you want, then
                configure PocketLLM with the endpoint. Same-device loopback is
                normally:
              </p>
              <pre>
                <code>http://127.0.0.1:11434</code>
              </pre>
              <p>
                Test the connection inside PocketLLM before starting a chat. LAN
                endpoints should only be used when you understand the network
                exposure and trust the host.
              </p>
            </section>
            <section id="knowledge">
              <p className="script-kicker pink">04</p>
              <h2>Work with your documents.</h2>
              <p>
                The Knowledge Base supports text PDFs, TXT, Markdown and CSV.
                Keyword retrieval can work without an embedding model; semantic
                and hybrid retrieval require a compatible embedding model.
                Source metadata is retained so retrieved context can point back
                to document/page/chunk evidence.
              </p>
              <p>
                Image-only or malformed PDFs are not silently treated as
                successful text imports. If the current app cannot extract
                useful text, it reports the limitation.
              </p>
            </section>
            <section id="privacy">
              <p className="script-kicker blue">05</p>
              <h2>Set the network boundary.</h2>
              <p>
                Strict Offline blocks non-loopback application-managed requests
                before PocketLLM performs its own HTTP I/O. Loopback remains
                intentionally available so local Ollama can work. Optional
                Hugging Face discovery, Tavily search, GitHub skill installs,
                update checks and remote inference require network access when
                enabled.
              </p>
            </section>
            <section id="backup">
              <p className="script-kicker coral">06</p>
              <h2>Back up what matters.</h2>
              <p>
                New <code>.pllm</code> backups use password-derived
                authenticated encryption. Restore validates the archive before
                mutating live application data and attempts rollback when an
                application-level restore step fails.
              </p>
            </section>
            <section id="evidence">
              <p className="script-kicker pink">Source of truth</p>
              <h2>Read the evidence, not the vibe.</h2>
              <p>
                For the exact current release boundary, use these repository
                documents:
              </p>
              <ul>
                <li>
                  <a
                    href="https://github.com/PocketLLM/pocketllm-lite/blob/main/README.md"
                    target="_blank"
                    rel="noreferrer"
                  >
                    README
                  </a>
                </li>
                <li>
                  <a
                    href="https://github.com/PocketLLM/pocketllm-lite/blob/main/docs/V1_0_38_VERIFICATION.md"
                    target="_blank"
                    rel="noreferrer"
                  >
                    v1.0.38 verification
                  </a>
                </li>
                <li>
                  <a
                    href="https://github.com/PocketLLM/pocketllm-lite/blob/main/docs/KNOWN_LIMITATIONS.md"
                    target="_blank"
                    rel="noreferrer"
                  >
                    Known limitations
                  </a>
                </li>
                <li>
                  <a
                    href="https://github.com/PocketLLM/pocketllm-lite/blob/main/SECURITY.md"
                    target="_blank"
                    rel="noreferrer"
                  >
                    Security policy
                  </a>
                </li>
                <li>
                  <a
                    href="https://github.com/PocketLLM/pocketllm-lite/blob/main/CONTRIBUTING.md"
                    target="_blank"
                    rel="noreferrer"
                  >
                    Contributor guide
                  </a>
                </li>
              </ul>
            </section>
          </article>
        </div>
      </section>
    </>
  );
}

/* ------------------------------------------------------------------ */
/* Legal pages                                                         */
/* ------------------------------------------------------------------ */

/**
 * Legal page body (privacy/terms). The markup comes from
 * legal-content.ts — repo-owned static HTML, never user input — and
 * uses the `legal-page__*` classes from the ported stylesheet.
 */
export function LegalPage({ html }: { html: string }) {
  return <div dangerouslySetInnerHTML={{ __html: html }} />;
}
