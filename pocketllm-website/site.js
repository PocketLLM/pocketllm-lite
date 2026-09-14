(() => {
  'use strict';

  const API = 'https://api.github.com/repos/PocketLLM/pocketllm-lite/releases?per_page=100';

  const FALLBACK_RELEASES = [
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
        { name: 'SHA256SUMS.txt', size: 409, digest: '', browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.38/SHA256SUMS.txt' }
      ]
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
        { name: 'PocketLLM-Lite-v1.0.37-x86_64.apk', size: 52598104, browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.37/PocketLLM-Lite-v1.0.37-x86_64.apk' }
      ]
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
        { name: 'app-x86_64-release.apk', size: 37671671, browser_download_url: 'https://github.com/PocketLLM/pocketllm-lite/releases/download/v1.0.35/app-x86_64-release.apk' }
      ]
    }
  ];

  const qs = (selector, root = document) => root.querySelector(selector);
  const qsa = (selector, root = document) => [...root.querySelectorAll(selector)];

  function initNav() {
    const header = qs('[data-header], .site-header');
    const button = qs('[data-nav-toggle], #navToggle');
    const nav = qs('[data-nav], #navLinks');
    const updateHeader = () => header?.classList.toggle('is-scrolled', window.scrollY > 18);

    updateHeader();
    addEventListener('scroll', updateHeader, { passive: true });

    if (!button || !nav) return;

    button.addEventListener('click', () => {
      const open = nav.classList.toggle('is-open');
      button.setAttribute('aria-expanded', String(open));
    });

    qsa('a', nav).forEach(link => link.addEventListener('click', () => {
      nav.classList.remove('is-open');
      button.setAttribute('aria-expanded', 'false');
    }));
  }

  function initReveal() {
    const items = qsa('.reveal');
    if (!items.length) return;
    if (matchMedia('(prefers-reduced-motion: reduce)').matches || !('IntersectionObserver' in window)) {
      items.forEach(el => el.classList.add('is-visible'));
      return;
    }
    const observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: .12, rootMargin: '0px 0px -30px' });
    items.forEach(el => observer.observe(el));
  }

  function formatDate(input) {
    const date = new Date(input);
    if (Number.isNaN(date.valueOf())) return 'Unknown date';
    return new Intl.DateTimeFormat('en', { year: 'numeric', month: 'short', day: 'numeric' }).format(date);
  }

  function formatBytes(bytes = 0) {
    if (!Number.isFinite(bytes) || bytes <= 0) return '—';
    const units = ['B', 'KB', 'MB', 'GB'];
    const index = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
    return `${(bytes / Math.pow(1024, index)).toFixed(index > 1 ? 1 : 0)} ${units[index]}`;
  }

  function escapeHTML(value = '') {
    return value.replace(/[&<>'"]/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[char]));
  }

  function inlineMarkdown(text) {
    let safe = escapeHTML(text);
    safe = safe.replace(/`([^`]+)`/g, '<code>$1</code>');
    safe = safe.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    safe = safe.replace(/\[([^\]]+)\]\((https?:\/\/[^)]+)\)/g, '<a href="$2" target="_blank" rel="noreferrer">$1</a>');
    return safe;
  }

  function renderMarkdown(markdown = '') {
    const lines = markdown.replace(/\r/g, '').split('\n');
    let html = '';
    let inList = false;
    let inCode = false;
    const closeList = () => { if (inList) { html += '</ul>'; inList = false; } };
    for (const raw of lines) {
      const line = raw.trimEnd();
      if (line.startsWith('```')) {
        closeList();
        html += inCode ? '</code></pre>' : '<pre><code>';
        inCode = !inCode;
        continue;
      }
      if (inCode) { html += `${escapeHTML(raw)}\n`; continue; }
      if (!line.trim()) { closeList(); continue; }
      if (/^###\s+/.test(line)) { closeList(); html += `<h3>${inlineMarkdown(line.replace(/^###\s+/, ''))}</h3>`; continue; }
      if (/^##\s+/.test(line)) { closeList(); html += `<h3>${inlineMarkdown(line.replace(/^##\s+/, ''))}</h3>`; continue; }
      if (/^#\s+/.test(line)) { continue; }
      if (/^[-*]\s+/.test(line)) {
        if (!inList) { html += '<ul>'; inList = true; }
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

  async function getReleases() {
    try {
      const response = await fetch(API, { headers: { Accept: 'application/vnd.github+json' } });
      if (!response.ok) throw new Error(`GitHub API ${response.status}`);
      const releases = await response.json();
      const usable = releases.filter(item => !item.draft);
      if (!usable.length) throw new Error('No releases returned');
      return usable;
    } catch (error) {
      console.warn('Using embedded release fallback:', error);
      return FALLBACK_RELEASES;
    }
  }

  function universalAPK(release) {
    const apks = (release.assets || []).filter(asset => /\.apk$/i.test(asset.name));
    return apks.find(asset => /android\.apk$/i.test(asset.name) || /universal/i.test(asset.name)) || apks[0] || null;
  }

  async function initHomeRelease() {
    if (!qs('[data-home-release]')) return;
    const releases = await getReleases();
    const latest = releases[0];
    if (!latest) return;
    const name = qs('[data-home-release-name]');
    const date = qs('[data-home-release-date]');
    const version = qs('[data-latest-version]');
    const download = qs('[data-latest-download]');
    if (name) name.textContent = latest.name || latest.tag_name;
    if (date) date.textContent = `${formatDate(latest.published_at)} · ${latest.prerelease ? 'Engineering pre-release' : 'Stable release'}`;
    if (version) version.textContent = `${latest.tag_name} · ${latest.prerelease ? 'pre-release' : 'stable'}`;
    const apk = universalAPK(latest);
    if (download && apk) download.href = apk.browser_download_url;
  }

  function assetKind(name) {
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

  function releaseCard(release) {
    const assets = (release.assets || []).map(asset => `
      <div class="asset">
        <div class="asset-main">
          <span class="asset-name" title="${escapeHTML(asset.name)}">${escapeHTML(asset.name)}</span>
          <span class="asset-sub">${assetKind(asset.name)} · ${formatBytes(asset.size)}${asset.digest ? ` · ${escapeHTML(asset.digest.replace('sha256:', 'SHA ')).slice(0, 24)}…` : ''}</span>
        </div>
        <a href="${escapeHTML(asset.browser_download_url)}">Download ↓</a>
      </div>`).join('');
    return `
      <article class="release-card" data-release="${escapeHTML(`${release.tag_name} ${release.name || ''}`.toLowerCase())}">
        <div class="release-head">
          <div>
            <span class="release-badge ${release.prerelease ? '' : 'stable'}">${release.prerelease ? 'Pre-release' : 'Stable'}</span>
            <h2>${escapeHTML(release.tag_name)}</h2>
            <div class="release-meta"><span>${escapeHTML(release.name || release.tag_name)}</span><span>${formatDate(release.published_at)}</span></div>
          </div>
          <a class="button button-outline button-small" href="${escapeHTML(release.html_url)}" target="_blank" rel="noreferrer">GitHub release ↗</a>
        </div>
        <div class="release-body">
          <div>${renderMarkdown(release.body || 'No release notes supplied.')}</div>
          ${assets ? `<div class="asset-list">${assets}</div>` : '<p>No downloadable assets are attached to this release.</p>'}
        </div>
      </article>`;
  }

  async function initReleasesPage() {
    const root = qs('[data-releases-list]');
    if (!root) return;
    const releases = await getReleases();
    root.innerHTML = releases.map(releaseCard).join('');
    const count = qs('[data-release-count]');
    if (count) count.textContent = `${releases.length} published release${releases.length === 1 ? '' : 's'}`;
    const input = qs('[data-release-search]');
    input?.addEventListener('input', () => {
      const value = input.value.trim().toLowerCase();
      qsa('[data-release]', root).forEach(card => card.hidden = value && !card.dataset.release.includes(value));
    });
  }

  function changelogItem(release, index) {
    return `
      <details data-changelog="${escapeHTML(`${release.tag_name} ${release.name || ''} ${release.body || ''}`.toLowerCase())}" ${index === 0 ? 'open' : ''}>
        <summary>
          <span class="timeline-version">${escapeHTML(release.tag_name)}</span>
          <span class="timeline-title">${escapeHTML(release.name || release.tag_name)}</span>
          <span class="timeline-date">${formatDate(release.published_at)}</span>
        </summary>
        <div class="timeline-content">
          ${renderMarkdown(release.body || 'No release notes supplied.')}
          <p><a class="text-link" href="${escapeHTML(release.html_url)}" target="_blank" rel="noreferrer">Open release on GitHub ↗</a></p>
        </div>
      </details>`;
  }

  async function initChangelogPage() {
    const root = qs('[data-changelog-list]');
    if (!root) return;
    const releases = await getReleases();
    root.innerHTML = releases.map(changelogItem).join('');
    const input = qs('[data-changelog-search]');
    input?.addEventListener('input', () => {
      const value = input.value.trim().toLowerCase();
      qsa('[data-changelog]', root).forEach(item => item.hidden = value && !item.dataset.changelog.includes(value));
    });
  }

  document.addEventListener('DOMContentLoaded', () => {
    initNav();
    initReveal();
    qsa('[data-year]').forEach(node => node.textContent = String(new Date().getFullYear()));
    initHomeRelease();
    initReleasesPage();
    initChangelogPage();
  });
})();
