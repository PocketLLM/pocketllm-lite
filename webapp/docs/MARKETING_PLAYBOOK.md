# PocketLLM Lite — Marketing Playbook & Ready-to-Post Content

Everything here is written to be **copy-paste ready** and to sound like a
person, not a press release. Tweak the personal details (device, use case,
how long you've been building) so it's genuinely yours — authenticity is the
whole strategy.

---

## 1. Positioning (the one page to internalize)

**What it is, in one line each:**

- *For everyone:* "Your AI, on your terms — a local-first AI workspace that
  runs on your phone, keeps your data on your device, and only goes online
  when you say so."
- *For devs:* "An open-source, MIT-licensed local LLM workspace for Android
  with document RAG, personas, tool calls with confirmations, and an
  Ollama/OpenAI-compatible runtime bridge."
- *The elevator pitch:* "Most AI apps want your data in their cloud. PocketLLM
  Lite keeps it in your pocket. Local models, private memory, document search
  — all on-device, all inspectable, MIT licensed."

**Three messages that matter (repeat these, not everything):**

1. **Local-first** — chats, memories, documents and models live on your
   device. No account required.
2. **Visible boundaries** — a network audit log shows every destination and
   purpose. Strict Offline mode blocks traffic before it leaves.
3. **Runtime choice** — on-device GGUF, Ollama on your LAN, or an
   OpenAI-compatible endpoint *you* pick. Swap freely.

**Words to avoid** (they make posts sound like ads): revolutionary,
game-changer, unleash, cutting-edge, seamless, 10x, "in today's fast-paced
world".

**Words that work:** on my phone, actually works offline, I can see what it
sends, no account, open source, free, it's your data.

---

## 2. Voice rules (how to sound human)

1. **First person, singular.** "I built", "I got tired of", "I wanted". Not
   "we at PocketLLM are thrilled".
2. **Lead with the frustration, not the feature.** The story starts with the
   problem you actually felt.
3. **One idea per post.** A post about RAG shouldn't also pitch the model
   store.
4. **Short paragraphs (1–3 lines).** LinkedIn truncates at ~210 characters
   before "see more" — the first two lines must carry the hook.
5. **Specifics beat adjectives.** "a 1.9 GB Phi-3 model runs on my 3-year-old
   phone" > "blazing fast performance".
6. **End with a soft CTA**, or none at all. "The whole thing is on GitHub if
   you want to poke at it" is enough.
7. **Never post links in the first edit.** Put the link in the first comment
   (reach is better), or after a few hours.

---

## 3. LinkedIn posts (ready to post)

### Post 1 — The launch story (your anchor post)

> I gave an AI app my notes, my documents, and my questions. Then I read its
> privacy policy and stopped.
>
> Everything I typed was training data, or ad targeting, or "shared with
> trusted partners" — a phrase that somehow always has 400 sub-clauses.
>
> So I built the thing I wanted instead.
>
> PocketLLM Lite is a local-first AI workspace for Android:
>
> • Chats, memory and document indexes stay in the app sandbox
> • Runs GGUF models directly on the device — or bridges to Ollama on my LAN
> • A network audit log shows every request before it happens
> • There's a Strict Offline switch that just says no
> • MIT licensed, no account, no analytics in the core
>
> The part I'm proudest of isn't a feature. It's that "where does my data go"
> has a real answer: nowhere, unless I flip the switch myself.
>
> It's on GitHub — link in the comments. The web edition runs in your browser
> right now if you just want to try it.
>
> If you've been putting sensitive notes into a chatbot and hoping for the
> best — this one's for you.

*First comment:* `GitHub: https://github.com/PocketLLM/pocketllm-lite · Try the web app: https://pocketllm.app (or your URL) · Android APK in Releases`

---

### Post 2 — The honest engineering angle (for the dev audience)

> Hardest bug I fixed this month: making an AI app say "I don't know."
>
> Most AI products hide their failure modes. PocketLLM Lite does the
> opposite:
>
> • If embeddings aren't available, retrieval says so — it doesn't quietly
>   pretend a keyword search is "semantic"
> • Model compatibility shows "untested" instead of green-checking everything
> • Network requests render as confirmation cards: destination, purpose, payload
>
> This is slower to build. Every feature needs an honest empty state, an
> honest error, an honest "this part is remote" label.
>
> But it changes the relationship with the app. You stop auditing it and
> start trusting it — because the app audits itself in front of you.
>
> Open source forces this discipline anyway. Someone would've found the
> fake "semantic" badge. Might as well ship the truth.
>
> What's a "honest empty state" you wish more apps had?

---

### Post 3 — Feature spotlight: documents + RAG

> I handed it a 90-page PDF manual and asked "what's the warranty on part
> 47-B."
>
> It answered — with a [1] citation I could tap to see the exact chunk it
> used.
>
> This is document RAG in PocketLLM Lite, and it runs entirely on my phone:
>
> • Import PDF, TXT, Markdown, CSV
> • Lexical, semantic or hybrid retrieval
> • Every answer carries source citations that jump back to the text
> • The index lives in app storage — not a vector database I rent monthly
>
> The workflow that sold me: contracts. I drop in a lease, ask "can I paint
> the walls", and get the clause with a link to it. No uploading a legal
> document to someone else's cloud to find out.
>
> That's the whole pitch for local AI, honestly. Same questions, same
> sources — minus the part where the document leaves the building.

---

### Post 4 — The comparison post (polite, no names)

> Privacy policies have a tell.
>
> Look for the sentence "including but not limited to". Whatever follows is
> the actual product. Usually it's your prompts.
>
> I stopped keeping notes, drafts and research questions in a cloud chatbot
> the day I did this exercise and realized the answer to "what do you do with
> my data" was a shrug in legal formatting.
>
> PocketLLM Lite, my local-first alternative, takes the opposite default:
>
> • No account — the app doesn't know who I am
> • No cloud profile to leak
> • Backups are AES-256 encrypted files I move myself
> • The one screen about networking is a list of "where, why, when" — a
>   switch, not a paragraph
>
> Cloud AI is genuinely great for lots of things. Your private notes
> shouldn't have to be one of them.

---

### Post 5 — Building in public / milestone

> 6 months ago PocketLLM Lite was a note on my phone: "AI app that doesn't
> phone home."
>
> Today it has 38 releases, document RAG, personas, tool calls with
> confirmation cards, voice in and out, encrypted backups, and a network
> audit log I actually enjoy reading (nerd confession).
>
> Things I learned shipping an offline-first AI app:
>
> 1. "Local" is a spectrum. On-device GGUF, LAN Ollama, remote endpoint —
>    users want all three, switchable. Runtime choice became the architecture.
> 2. Offline isn't a mode, it's the default. Online is the mode you opt into
>    per feature.
> 3. The audit log won trust faster than any feature. Transparency > promises.
> 4. MIT license brought in the best contributors. People read the source and
>   fixed things I'd stopped noticing.
>
> Next: smarter memory, faster indexing, and a proper lab for prompt
> comparison.
>
> If you want to watch a local-AI app get built in the open, the repo is
> linked below. Star it if you believe AI should have an off switch.

---

### Post 6 — The "try it in 30 seconds" post (drives web-app traffic)

> You can try local-first AI before you install anything.
>
> The PocketLLM Lite web edition runs in your browser:
>
> 1. Open the site
> 2. Type a prompt in the command bar on the landing page
> 3. Hit Enter — it carries your prompt straight into the app
> 4. Chat, search history, star answers, import a document and ask it
>    questions — all without an account
>
> Your data stays in your browser's storage on your machine. Clear site data
> and it's like you were never there. That's the point.
>
> Android users: the full app with on-device models and Ollama bridging is in
> GitHub Releases.
>
> Link in the comments — tell me what breaks. Seriously. The issue tracker
> is the roadmap.

---

## 4. X / Twitter — launch thread (10 tweets)

> **1/** I got tired of AI apps that treat my notes as their training data.
> So I built PocketLLM Lite — a local-first AI workspace for Android. No
> account. No cloud. No "trusted partners". Everything on-device. 🧵
>
> **2/** Chats, memories, document indexes, models — all in the app sandbox
> on YOUR device. There is no PocketLLM cloud. There's nothing to log into.
>
> **3/** Runtime choice is the architecture: 📱 on-device GGUF models, 🏠
> Ollama on your LAN, 🔌 any OpenAI-compatible endpoint — switch anytime,
> per your privacy boundary.
>
> **4/** Documents: import PDF/TXT/MD/CSV, then ask questions. Lexical,
> semantic or hybrid retrieval — with citations you can tap to verify. The
> index lives on your phone, not a rented vector DB.
>
> **5/** The network audit log is my favorite screen. Every request:
> destination, purpose, timestamp. Strict Offline blocks non-loopback traffic
> before it leaves. "Where does my data go" has a real answer: nowhere.
>
> **6/** Tools (calculator, notes, reminders, web search) use schema
> validation + confirmation cards. The app shows you what it's about to do
> before it does it.
>
> **7/** Memory you can audit: inspect, pin, disable, supersede. When
> embeddings aren't available it says so — instead of quietly pretending
> keyword search is "semantic".
>
> **8/** Backups: PBKDF2 → AES-256-GCM encrypted .pllm files. Portable,
> verifiable, yours. Move them with a file manager like it's 2010.
>
> **9/** MIT licensed, 38 releases in, built in the open:
> github.com/PocketLLM/pocketllm-lite — Android APK in Releases, and a web
> edition that runs in your browser right now.
>
> **10/** Try it: open the site, type a prompt, hit Enter. It drops you
> straight into the app with your prompt loaded. No signup wall, no cookie
> banner, no onboarding carousel. Just the thing. 💛

---

## 5. Reddit (the honest channels)

**r/LocalLLaMA — post title options:**

- "I built an offline-first Android workspace for local LLMs (GGUF on-device,
  Ollama bridge, document RAG with citations) — MIT licensed"
- "PocketLLM Lite: local AI with a network audit log and a Strict Offline
  switch — source included"

**Post body (works for r/LocalLLaMA, r/androidapps, r/opensource):**

> Not here with marketing — happy to answer anything about the architecture.
>
> What it is: a local-first AI workspace for Android. The design rule was
> "the app is a guest on your device": chats/memories/document indexes stay
> in the sandbox, no account, and networking is explicit — there's an audit
> log (destination + purpose per request) and a Strict Offline switch that
> blocks non-loopback traffic before it leaves.
>
> Runtimes: on-device GGUF via the mobile runtime, Ollama over LAN, or any
> OpenAI-compatible endpoint you configure. You can swap between them.
>
> Document RAG: PDF/TXT/MD/CSV import, lexical/semantic/hybrid retrieval,
> answers carry [1]-style citations that jump to the source chunk. If
> embeddings aren't available it tells you it fell back to lexical — no
> fake "semantic" badge.
>
> MIT licensed: github.com/PocketLLM/pocketllm-lite. There's also a web
> edition (single-page app, data stays in browser storage) if you want to
> poke at the UX without installing anything.
>
> Known limitations, since this sub will find them anyway: on-device speed
> depends on your SoC (a 2–4 GB GGUF is the sweet spot on mid-range phones),
> semantic retrieval needs embeddings available, and the OpenAI-compatible
> bridge is only as private as the endpoint you point it at.
>
> What should I build next?

**r/SideProject / r/selfhosted angle:** emphasize the Ollama LAN bridge +
audit log. **r/privacy angle:** lead with Strict Offline + no account +
encrypted backups.

---

## 6. Product Hunt (launch day copy)

**Tagline:** `Your AI, on your terms — local-first, offline-capable, open source`

**Description:**

> PocketLLM Lite is a local-first AI workspace for Android (plus a web
> edition). Chats, private memory, document RAG with citations, personas and
> confirmed tools — all stored on your device, no account required.
>
> 🔒 Local-first: your data lives in the app sandbox, not our cloud (there
> isn't one)
> 📡 Visible boundaries: a network audit log + Strict Offline switch
> 🧠 Runtime choice: on-device GGUF, Ollama on your LAN, or an
> OpenAI-compatible endpoint
> 📄 Documents: PDF/TXT/MD/CSV → hybrid retrieval → cited answers
> 🔓 MIT licensed: read the source, build it yourself
>
> Built for anyone who's ever pasted something sensitive into a chatbot and
> immediately regretted it.

**First comment (maker's note):** tell the origin story in 3 short
paragraphs — the privacy-policy moment, the first offline prototype on a
cheap phone, why the audit log became the centerpiece. Same material as
LinkedIn Post 1, more casual.

---

## 7. Show HN (text post)

**Title:** `Show HN: PocketLLM Lite – Local-first AI workspace with a network audit log`

**Body:**

> I built an Android app (and web edition) for using LLMs without handing
> over your data. Local-first by default: chats, memory, and document indexes
> stay in the app sandbox; there's no account and no backend of ours to send
> anything to.
>
> Three things I did differently from most "private AI" apps:
>
> 1. Networking is explicit and inspectable. The audit log records every
>    non-loopback request (destination, purpose). A Strict Offline switch
>    blocks app-managed traffic entirely.
> 2. Runtime is a choice, not a religion: on-device GGUF models, Ollama on
>    your LAN, or any OpenAI-compatible endpoint — switchable in settings.
> 3. Failure states are honest. No embeddings available → retrieval says it
>    fell back to lexical. Untested model → shows "untested", not a green
>    check.
>
> Document RAG supports PDF/TXT/MD/CSV with lexical/semantic/hybrid retrieval
> and source citations on every answer. Backups are
> PBKDF2(600k)+AES-256-GCM encrypted .pllm files. MIT licensed:
> https://github.com/PocketLLM/pocketllm-lite
>
> Tech details I'm happy to go into: the generation pipeline is a state
> machine (no mystery "the AI is thinking" screens), tool calls validate
> against JSON schemas before confirmation cards render, and the web edition
> keeps everything in IndexedDB so it works fully offline after first load.
>
> Ask me anything — especially about where local inference is still painful
> (Spoiler: mid-range phones and 7B+ models don't mix).

---

## 8. Two-week launch calendar

| Day | Action | Channel | Asset |
|---|---|---|---|
| 1 | Landing page + web edition live; deploy final | — | Site URL |
| 2 | **Anchor launch post** (LinkedIn Post 1, link in comments) | LinkedIn | Post 1 |
| 2 | Launch thread | X/Twitter | Thread (§4) |
| 3 | "Ask HN"-style discussion + honest architecture post | Reddit r/LocalLLaMA | §5 |
| 4 | **Product Hunt launch** (Tue–Thu best) | PH | §6 |
| 4 | Show HN (link the PH page or GitHub, not both posts at once) | HN | §7 |
| 5 | Engage: answer every comment on PH/HN/Reddit within 2h | all | — |
| 7 | Feature post: RAG + citations (Post 3) | LinkedIn | Post 3 |
| 8 | Demo clip: prompt → landing command bar → app → cited answer (30s, screen recording, no voiceover, captions) | X, LinkedIn, r/androidapps | video |
| 10 | Dev-audience post: honest engineering (Post 2) | LinkedIn | Post 2 |
| 11 | Privacy comparison post (Post 4) | LinkedIn | Post 4 |
| 13 | Milestone/builder post (Post 5, update the numbers!) | LinkedIn | Post 5 |
| 14 | "Try it in 30 seconds" traffic post (Post 6) + retro: what worked, reply counts | LinkedIn + X | Post 6 |

**Recurring after launch:** 1 LinkedIn post/week (rotate angles), 1 demo clip
or screenshot post/week, keep the GitHub README's "why" section synced with
your best-performing post language.

---

## 9. Assets you already have

- **Hero visual** — `pocketllm-website/assets/hero-local-ai.webp` (dreamy
  city-at-sunset illustration) → OG image, post banner.
- **OG card** — already wired in `src/app/layout.tsx`
  (`openGraph.images`). Set `metadataBase` after you have the final domain.
- **Demo flow for videos** — landing command bar → Enter → app opens with the
  prompt pre-filled → send → cited answer. This 30-second path IS the
  product story. Record it once, post it everywhere.
- **Release notes** — every GitHub release is a mini changelog post; repost
  the interesting ones ("what took 200 lines: an honest offline state").

---

## 10. Metrics that matter (first 30 days)

| Metric | Healthy signal | Where |
|---|---|---|
| GitHub stars | 300+ in month 1 (organic, no paid) | repo |
| Star conversion | ≥ 8% of unique site visitors | site vs repo |
| Web app opens | ≥ 15% of landing visitors click "Web App" | (add analytics later — or count via a 1px endpoint you control) |
| PH upvotes | 100+ with 30+ real comments | PH |
| APK downloads | 10–20% of stars | GitHub Releases traffic |
| LinkedIn | posts ≥ 2% engagement, 5+ saves on anchor post | LinkedIn analytics |

Track manually the first month — a spreadsheet beats a tracking script you'll
argue with.

---

## Final note on tone

The product's promise is honesty. The marketing has to be the same way:
admit the limitations in every post (mid-range phones, embedding
availability, endpoint trust), link the source before the landing page, and
answer criticism in public. A local-first app marketed like a SaaS hype
launch would be a contradiction people can smell instantly.
