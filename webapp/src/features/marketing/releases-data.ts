/**
 * Release data for the marketing site's Downloads / Changelog pages.
 *
 * Ported 1:1 from `pocketllm-website/site.js` (repository commit
 * 1863b49): same GitHub API endpoint, same embedded fallback list
 * (used when the API is unreachable — e.g. offline or rate-limited),
 * same formatting helpers and the same minimal markdown renderer for
 * release bodies. Everything is escaped before being rendered.
 */

/** GitHub API endpoint for published releases (same as site.js). */
export const RELEASES_API =
  'https://api.github.com/repos/PocketLLM/pocketllm-lite/releases?per_page=100';

export interface ReleaseAsset {
  name: string;
  size: number;
  digest?: string;
  browser_download_url: string;
}

export interface ReleaseInfo {
  tag_name: string;
  name?: string;
  prerelease: boolean;
  draft: boolean;
  published_at: string;
  html_url: string;
  body: string;
  assets: ReleaseAsset[];
}

/**
 * Embedded fallback (verbatim from site.js): three most recent
 * releases with their APK assets and checksums so the Downloads and
 * Changelog pages remain useful with no network access.
 */
export const FALLBACK_RELEASES: ReleaseInfo[] = [
  {
    tag_name: 'v1.0.38',
    name: 'PocketLLM Lite v1.0.38 — Guided Model Setup',
    prerelease: true,
    draft: false,
    published_at: '2026-08-29T16:31:55Z',
    html_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/tag/v1.0.38',
    body: '# PocketLLM Lite v1.0.38 - Guided Model Setup\n\nPocketLLM Lite v1.0.38 removes the missing-model dead end from Knowledge Base and audio workflows.\n\n## What changed\n- Guided prerequisite downloads automatically continue the original document or audio action.\n- Model Store search includes IDs, source, license and capabilities.\n- On-device and speech catalogs fail independently.\n- Resumed downloads safely restart if a server ignores HTTP Range.\n- Managed archives validate paths, links and GGUF headers before publishing installs.\n\n## Verification\n- Flutter analyze passed.\n- 144 tests passed.\n- Universal and per-ABI Android APKs built successfully.\n\nThese APKs are engineering prerelease artifacts and are debug-signed.',
    assets: [
      { name: 'PocketLLM-Lite-v1.0.38-android.apk', size: 123410783, digest: 'sha256:45c3c3b9ff205b0adb325a5d9263c815a0152643708291316570d5e66c0536c9', browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.38/PocketLLM-Lite-v1.0.38-android.apk' },
      { name: 'PocketLLM-Lite-v1.0.38-arm64-v8a.apk', size: 58118680, digest: 'sha256:3bfb3d9cdc94c6d82426ba8d5b0043d252153d395ccdebcd27e77e54f08092c6', browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.38/PocketLLM-Lite-v1.0.38-arm64-v8a.apk' },
      { name: 'PocketLLM-Lite-v1.0.38-armeabi-v7a.apk', size: 43330001, digest: 'sha256:90d34398b1c67f36474a5aefa9c91a54380fc98733775a2602f56b75f13d2fbc', browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.38/PocketLLM-Lite-v1.0.38-armeabi-v7a.apk' },
      { name: 'PocketLLM-Lite-v1.0.38-x86_64.apk', size: 52598172, digest: 'sha256:9dd42d0a28c9c3e37a46681e743fcacd02fb53c6b7e78c3beccb15c2194c6309', browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.38/PocketLLM-Lite-v1.0.38-x86_64.apk' },
      { name: 'SHA256SUMS.txt', size: 409, digest: '', browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.38/SHA256SUMS.txt' },
    ],
  },
  {
    tag_name: 'v1.0.37',
    name: 'PocketLLM Lite v1.0.37 — Durable Local Workspaces',
    prerelease: true,
    draft: false,
    published_at: '2026-08-25T22:28:32Z',
    html_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/tag/v1.0.37',
    body: '# PocketLLM Lite v1.0.37 — Durable Local Workspaces\n\n- New model store and live policy-gated catalog discovery.\n- Resumable model downloads with durable task records.\n- Rebuilt Knowledge Base with keyword, semantic and hybrid retrieval.\n- Real audio-file transcription workflow and model readiness.\n- Per-chat system prompts persist across restart and export.',
    assets: [
      { name: 'PocketLLM-Lite-v1.0.37-android.apk', size: 123312407, browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.37/PocketLLM-Lite-v1.0.37-android.apk' },
      { name: 'PocketLLM-Lite-v1.0.37-arm64-v8a.apk', size: 58053076, browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.37/PocketLLM-Lite-v1.0.37-arm64-v8a.apk' },
      { name: 'PocketLLM-Lite-v1.0.37-armeabi-v7a.apk', size: 43297165, browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.37/PocketLLM-Lite-v1.0.37-armeabi-v7a.apk' },
      { name: 'PocketLLM-Lite-v1.0.37-x86_64.apk', size: 52598104, browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.37/PocketLLM-Lite-v1.0.37-x86_64.apk' },
    ],
  },
  {
    tag_name: 'v1.0.35',
    name: 'v1.0.35 — Typed Tools, Offline Voice Workspace, Prompt Lab & Local OpenAI API',
    prerelease: false,
    draft: false,
    published_at: '2026-08-04T07:04:08Z',
    html_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/tag/v1.0.35',
    body: '# PocketLLM Lite v1.0.35\n\nIntroduced typed tool calling, skill permissions, agentic mobile actions, audio workspace, Prompt Lab, an embedded OpenAI-compatible local server and encrypted local backup migration.',
    assets: [
      { name: 'app-arm64-v8a-release.apk', size: 43749228, browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.35/app-arm64-v8a-release.apk' },
      { name: 'app-armeabi-v7a-release.apk', size: 33597219, browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.35/app-armeabi-v7a-release.apk' },
      { name: 'app-x86_64-release.apk', size: 37671671, browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.35/app-x86_64-release.apk' },
    ],
  },
];

/** Fetch releases from the GitHub API; fall back to the embedded list. */
export async function fetchReleases(): Promise<ReleaseInfo[]> {
  try {
    const response = await fetch(RELEASES_API, {
      headers: { Accept: 'application/vnd.github+json' },
    });
    if (!response.ok) throw new Error(`GitHub API ${response.status}`);
    const releases = (await response.json()) as ReleaseInfo[];
    const usable = releases.filter((item) => !item.draft);
    if (!usable.length) throw new Error('No releases returned');
    return usable;
  } catch {
    // Offline / rate-limited / blocked — keep the page honest and useful.
    return FALLBACK_RELEASES;
  }
}

/** "Aug 29, 2026" style date (same Intl format as site.js). */
export function formatDate(input: string): string {
  const date = new Date(input);
  if (Number.isNaN(date.valueOf())) return 'Unknown date';
  return new Intl.DateTimeFormat('en', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  }).format(date);
}

/** Human file size ("123.4 MB"); em-dash for missing sizes. */
export function formatBytes(bytes = 0): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB'];
  const index = Math.min(
    Math.floor(Math.log(bytes) / Math.log(1024)),
    units.length - 1
  );
  return `${(bytes / Math.pow(1024, index)).toFixed(index > 1 ? 1 : 0)} ${units[index]}`;
}

/** The APK asset a "Download" CTA should point at (universal first). */
export function universalAPK(release: ReleaseInfo): ReleaseAsset | null {
  const apks = (release.assets || []).filter((asset) => /\.apk$/i.test(asset.name));
  return (
    apks.find(
      (asset) => /android\.apk$/i.test(asset.name) || /universal/i.test(asset.name)
    ) ||
    apks[0] ||
    null
  );
}

/** Descriptive label for an asset row ("ARM64 APK · most modern…"). */
export function assetKind(name: string): string {
  const lower = name.toLowerCase();
  if (lower.endsWith('.apk')) {
    if (lower.includes('arm64')) return 'ARM64 APK · most modern Android phones';
    if (lower.includes('armeabi')) return 'ARMv7 APK · older 32-bit Android';
    if (lower.includes('x86_64')) return 'x86_64 APK · emulator / compatible x86 device';
    return 'Universal Android APK';
  }
  if (lower.includes('sha256')) return 'SHA-256 checksums';
  return 'Release asset';
}

/** HTML-escape a value before it enters rendered markup. */
export function escapeHTML(value = ''): string {
  return value.replace(
    /[&<>'"]/g,
    (char) =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[
        char
      ] ?? char
  );
}

/** Inline markdown: code, bold and safe https links (after escaping). */
function inlineMarkdown(text: string): string {
  let safe = escapeHTML(text);
  safe = safe.replace(/`([^`]+)`/g, '<code>$1</code>');
  safe = safe.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  safe = safe.replace(
    /\[([^\]]+)\]\((https?:\/\/[^)]+)\)/g,
    '<a href="$2" target="_blank" rel="noreferrer">$1</a>'
  );
  return safe;
}

/**
 * Minimal block markdown for release notes: headings, bullets, code
 * fences and paragraphs. Identical to site.js `renderMarkdown`.
 */
export function renderMarkdown(markdown = ''): string {
  const lines = markdown.replace(/\r/g, '').split('\n');
  let html = '';
  let inList = false;
  let inCode = false;
  const closeList = () => {
    if (inList) {
      html += '</ul>';
      inList = false;
    }
  };
  for (const raw of lines) {
    const line = raw.trimEnd();
    if (line.startsWith('```')) {
      closeList();
      html += inCode ? '</code></pre>' : '<pre><code>';
      inCode = !inCode;
      continue;
    }
    if (inCode) {
      html += `${escapeHTML(raw)}\n`;
      continue;
    }
    if (!line.trim()) {
      closeList();
      continue;
    }
    if (/^###\s+/.test(line)) {
      closeList();
      html += `<h3>${inlineMarkdown(line.replace(/^###\s+/, ''))}</h3>`;
      continue;
    }
    if (/^##\s+/.test(line)) {
      closeList();
      html += `<h3>${inlineMarkdown(line.replace(/^##\s+/, ''))}</h3>`;
      continue;
    }
    if (/^#\s+/.test(line)) {
      continue;
    }
    if (/^[-*]\s+/.test(line)) {
      if (!inList) {
        html += '<ul>';
        inList = true;
      }
      html += `<li>${inlineMarkdown(line.replace(/^[-*]\s+/, ''))}</li>`;
      continue;
    }
    closeList();
    html += `<p>${inlineMarkdown(line)}</p>`;
  }
  closeList();
  if (inCode) html += '</code></pre>';
  return html;
}
