<div align="center">

<img src="public/pocketllm-website/assets/logo.png" width="76" alt="PocketLLM Lite logo" />

# PocketLLM Lite Web Edition

**Your AI, on your terms.** The complete web app with a local-first AI workspace in one Next.js project.

![Next.js 16](https://img.shields.io/badge/Next.js-16-black) ![TypeScript](https://img.shields.io/badge/TypeScript-5-3178C6) ![Tailwind CSS](https://img.shields.io/badge/Tailwind-4-38BDF8) ![shadcn/ui](https://img.shields.io/badge/shadcn%2Fui-New%20York-18181B)

<img src="public/pocketllm-website/assets/hero-local-ai.webp" alt="PocketLLM Lite — local AI hero" width="880" />

</div>

---

## What's in this zip

One Next.js app, two surfaces:

| URL | What you get |
|---|---|
| `/` | The marketing website — hero, features, runtime journey, docs, downloads, releases, changelog, terms & privacy |
| `#/app` | **The full product** — a local-first AI workspace: chat, knowledge (RAG), model manager, personas, lab, notes, memories, and 15 sections of settings |

Everything runs from a single page — hash routing keeps the app client-side and fully static-safe, while thin API routes handle server-side AI calls.

## Run it locally (2 minutes)

**Prerequisites:** [Node.js 20+](https://nodejs.org) (or [Bun](https://bun.sh) 1.1+).

```bash
cd webapp

# install dependencies (any one of these)
npm install          # or: bun install | pnpm install

# start the dev server
npm run dev          # or: bun run dev

# open
http://localhost:3000
```

Optional environment:

```bash
cp .env.example .env
```

**No database required.** All app data (chats, documents, settings, memories) lives in your **browser's IndexedDB** — that's the local-first design. The included Prisma + SQLite scaffold is optional and only relevant if you later add server-side features.

## Deploy to Vercel

### Option A — via GitHub (recommended, ~5 minutes)

```bash
cd webapp
git init
git add -A
git commit -m "PocketLLM Lite web edition"
git remote add origin https://github.com/<your-user>/pocketllm-web.git
git push -u origin main
```

Then:

1. Open [vercel.com/new](https://vercel.com/new) and **Import** the repository.
2. Framework preset is auto-detected as **Next.js** — keep the defaults.
3. *(Optional)* Add the environment variable `DATABASE_URL=file:./db/custom.db` (see note above — the app runs fine without it).
4. Click **Deploy**. Every future push to `main` auto-deploys; PRs get preview URLs.

### Option B — via the Vercel CLI

```bash
npm i -g vercel
cd webapp
vercel          # first run: link the project, confirm defaults
vercel --prod   # promote to production
```

### What works on Vercel — honest notes

- ✅ **Marketing site** — fully static, CDN-served, instant.
- ✅ **The `#/app` workspace** — all views, IndexedDB persistence, model discovery via `/api/hf`, PWA offline support.
- ⚠️ **Built-in AI proxy routes** — `/api/chat`, `/api/title`, `/api/suggest`, `/api/search`, `/api/vision`, `/api/asr`, `/api/memory`, `/api/enhance` rely on a development-environment SDK. In the cloud they fail **and the app degrades gracefully by design**:
  - chat streaming → falls back to the runtime **you** configure in the app (Ollama endpoint or any OpenAI-compatible API — see *Models → Runtime*),
  - chat titles → fall back to the first message line,
  - suggestions → fall back to built-in prompts.

  Want real streaming replies in the cloud? Either connect an OpenAI-compatible endpoint inside the app (no code), or port the thin pass-through routes in `src/app/api/` to your provider (each is < 80 lines).

Full guide with custom domains, DNS, and a troubleshooting table: [`docs/VERCEL_DEPLOYMENT.md`](docs/VERCEL_DEPLOYMENT.md).

## The `#/app` workspace — feature map

- 💬 **Chats** — streaming replies, branches, tags, stars, drafts, full-text search, slash commands, follow-up suggestions, jump-to-context, export (Markdown/JSON)
- 🧠 **Knowledge** — import PDF / TXT / Markdown, chunking + embeddings, retrieval tester, scoped "ask your documents" chat
- 📦 **Models** — Hugging Face discovery, downloads with progress, model detail pages, runtime switching
- 🎭 **Personas · Prompts · Skills** — full CRUD, import/export
- 🔬 **Lab** — prompt lab, side-by-side model compare, benchmarks
- 🗒️ **Notes** — markdown editor with live preview
- 🧩 **Memories** — persistent facts with usage tracking
- 📊 **Activity** — usage sparklines and per-day stats
- 🔊 **Audio** — text-to-speech and speech-to-text
- 🌐 **Network** — gateway controls, strict-offline mode, request audit log
- 🔐 **Backup** — encrypted `.pllm` vault (PBKDF2 600k iterations + AES-256-GCM), full export/import
- 🎨 **Appearance** — light / dark / system themes, compact / medium / expanded densities
- ⌨️ **Command palette**, keyboard shortcuts, `pocketllm://` deep links, installable PWA

## Tech stack

| Layer | Tech |
|---|---|
| Framework | Next.js 16 (App Router — one page, hash-routed SPA) |
| Language | TypeScript 5 |
| UI | Tailwind CSS 4 · shadcn/ui (New York) · Lucide icons · Framer Motion |
| State | Zustand + IndexedDB repositories (client-side persistence) |
| AI | Thin server routes (`z-ai-web-dev-sdk`) + pluggable runtimes: Ollama, OpenAI-compatible, mock |
| Optional DB | Prisma + SQLite scaffold (unused by the app out of the box) |

## Project structure

```
webapp/
├── src/
│   ├── app/                  # the single page + 10 thin API routes
│   │   ├── page.tsx          # everything mounts here
│   │   └── api/              # chat, title, suggest, search, vision, asr, memory, enhance, hf
│   ├── features/
│   │   ├── marketing/        # landing, docs, releases, legal pages
│   │   └── app/              # the #/app workspace (25+ views)
│   ├── components/ui/        # shadcn/ui primitives
│   ├── hooks/                # use-toast, use-mobile
│   └── lib/                  # hash router, event bus, repositories, services, crypto
├── public/                   # logo, manifest, sw.js, marketing images (webp)
├── prisma/                   # optional SQLite scaffold
├── docs/                     # deployment, integration & marketing guides
├── .env.example              # env template (optional vars only)
└── README.md                 # you are here
```

## Scripts

| Command | What it does |
|---|---|
| `npm run dev` | Dev server on [localhost:3000](http://localhost:3000) |
| `npm run build` | Production build (standalone output) |
| `npm start` | Serve the production build |
| `npm run lint` | ESLint (Next.js rules) |
| `npm run db:push` | Push the Prisma schema to SQLite *(optional)* |

> Using Bun? Swap `npm run X` for `bun run X`. The included `bun.lock` pins the exact dependency versions this app was built and tested with — Vercel picks it up automatically and installs with Bun. If you prefer npm, delete `bun.lock` and commit `package-lock.json` instead.

## Documentation

| Doc | What's inside |
|---|---|
| [`docs/VERCEL_DEPLOYMENT.md`](docs/VERCEL_DEPLOYMENT.md) | Vercel hosting (static marketing site **or** this full web edition), env vars, custom domain, troubleshooting |
| [`docs/INTEGRATION_GUIDE.md`](docs/INTEGRATION_GUIDE.md) | Keep the static site and this web edition in sync — exact diffs, plain-HTML snippets, smoke-test checklist |
| [`docs/MARKETING_PLAYBOOK.md`](docs/MARKETING_PLAYBOOK.md) | Positioning, voice rules, ready-to-post LinkedIn/X/Reddit copy, 2-week launch calendar |

## FAQ

**Do I need a database or an account system?**
No. PocketLLM Lite is local-first: your data stays in your browser, exportable as encrypted `.pllm` backups. No sign-up, no server state.

**Can I chat with a real model?**
Yes. Run [Ollama](https://ollama.com) locally and point the app to it (*Models → Runtime*), or configure any OpenAI-compatible endpoint. In the development sandbox, the built-in `/api/chat` proxy streams out of the box; on your own Vercel deploy, use your configured runtime (see the honest notes above).

**I only want the static marketing site.**
That's the separate `pocketllm-website.zip` (plain HTML/CSS, zero build step). This zip is the full web edition.

**Why does the first load feel instant on repeat visits?**
The app registers a service worker (`public/sw.js`) and is an installable PWA — it works offline once visited.

---

<div align="center">

Made with ☕ &nbsp;·&nbsp; PocketLLM Lite — *Your AI, on your terms.*

</div>
