/**
 * ChatExport — honest print-to-PDF and Markdown exports.
 *
 * print: opens a styled print window with the conversation rendered as
 * clean article HTML, then triggers the browser's print dialog (Save as
 * PDF works everywhere, zero dependencies, no server involved).
 *
 * markdown: renders the conversation as GitHub-flavoured Markdown and
 * downloads it as a .md file — portable, diffable, paste-able into any
 * notes app. Also zero dependencies.
 */
import type { Chat, Message, ToolEvent } from '@/lib/types/domain';

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** Sanitizes a chat title for use as a filename. */
function safeFilename(title: string): string {
  const base = title
    .trim()
    .replace(/[^\w\s.-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .slice(0, 60);
  return base || 'chat';
}

/** Minimal markdown → HTML for the print view (bold/code/lists/headings). */
function lightMarkdown(md: string): string {
  const esc = escapeHtml(md);
  const lines = esc.split('\n');
  const out: string[] = [];
  let inList = false;
  let inCode = false;
  const inline = (s: string) =>
    s
      .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
      .replace(/`([^`]+)`/g, '<code>$1</code>')
      .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');

  for (const line of lines) {
    if (line.trim().startsWith('```')) {
      if (inCode) {
        out.push('</code></pre>');
        inCode = false;
      } else {
        out.push('<pre><code>');
        inCode = true;
      }
      continue;
    }
    if (inCode) {
      out.push(line);
      continue;
    }
    const heading = /^(#{1,3})\s+(.*)$/.exec(line);
    const bullet = /^\s*[-*]\s+(.*)$/.exec(line);
    if (bullet) {
      if (!inList) {
        out.push('<ul>');
        inList = true;
      }
      out.push(`<li>${inline(bullet[1])}</li>`);
      continue;
    }
    if (inList) {
      out.push('</ul>');
      inList = false;
    }
    if (heading) {
      out.push(`<h${heading[1].length}>${inline(heading[2])}</h${heading[1].length}>`);
    } else if (line.trim() === '') {
      out.push('');
    } else {
      out.push(`<p>${inline(line)}</p>`);
    }
  }
  if (inList) out.push('</ul>');
  if (inCode) out.push('</code></pre>');
  return out.join('\n');
}

export function exportChatToPrint(
  chat: Chat,
  messages: Message[],
  toolEvents: ToolEvent[]
): void {
  const visible = messages.filter((m) => m.role !== 'system');
  const toolById = new Map(toolEvents.map((t) => [t.id, t] as const));
  const date = new Date().toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  const body = visible
    .map((m) => {
      const role = m.role === 'user' ? 'you' : 'PocketLLM';
      const time = new Date(m.createdAt).toLocaleString();
      const toolBlocks = m.toolEvents
        .map((id) => toolById.get(id))
        .filter(Boolean)
        .map(
          (t) => `
        <div class="tool">
          <span class="tool-name">${escapeHtml(t!.tool)}</span>
          <span class="tool-status">${t!.status}</span>
        </div>`
        )
        .join('');
      const citations = m.citations.length
        ? `<div class="cites">Sources: ${m.citations
            .map((c) => `${escapeHtml(c.documentName)}${c.page ? ` p.${c.page}` : ''}`)
            .join(' · ')}</div>`
        : '';
      return `
      <article class="${m.role}">
        <header><span class="role">${role}</span><time>${time}</time></header>
        <div class="content">${lightMarkdown(m.content)}</div>
        ${toolBlocks}
        ${citations}
      </article>`;
    })
    .join('\n');

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>${escapeHtml(chat.title)} — PocketLLM export</title>
<style>
  @page { margin: 18mm 16mm; }
  * { box-sizing: border-box; }
  body { font-family: 'Inter', -apple-system, 'Segoe UI', Roboto, sans-serif; color: #1b2430; line-height: 1.55; font-size: 10.5pt; margin: 0; }
  .doc-header { border-bottom: 3px solid #ffef4d; padding-bottom: 10px; margin-bottom: 20px; }
  .doc-header h1 { font-size: 16pt; margin: 0 0 4px; }
  .doc-header p { margin: 0; color: #6e6a5e; font-size: 9pt; }
  article { margin-bottom: 14px; padding: 10px 12px; border: 1px solid #e8e5dc; border-radius: 8px; page-break-inside: avoid; }
  article.user { background: #1b2430; color: #fffdf5; border-color: #1b2430; }
  article.user .content code { background: rgba(255,255,255,0.15); }
  article header { display: flex; justify-content: space-between; font-size: 8.5pt; margin-bottom: 6px; opacity: 0.85; }
  article.user header { color: #ffef4d; }
  article.assistant header { color: #6e6a5e; }
  .role { font-weight: 600; letter-spacing: 0.02em; }
  .content p { margin: 0 0 6px; }
  .content ul { margin: 4px 0; padding-left: 18px; }
  .content pre { background: #141c26; color: #dbe6f3; padding: 8px 10px; border-radius: 6px; font-family: 'JetBrains Mono', monospace; font-size: 8.5pt; white-space: pre-wrap; word-break: break-word; }
  .content code { font-family: 'JetBrains Mono', monospace; font-size: 9pt; background: #f1efe9; border-radius: 3px; padding: 0 3px; }
  .content a { color: inherit; }
  .tool { display: flex; gap: 8px; font-size: 8.5pt; margin-top: 6px; padding: 4px 8px; background: #fff9c9; border-radius: 4px; }
  .tool-name { font-family: 'JetBrains Mono', monospace; font-weight: 600; }
  .tool-status { color: #2f7d4f; }
  .cites { margin-top: 6px; font-size: 8.5pt; color: #6e6a5e; }
  .doc-footer { margin-top: 24px; border-top: 1px solid #e8e5dc; padding-top: 8px; font-size: 8pt; color: #9ca3af; text-align: center; }
  .print-hint { position: fixed; bottom: 12px; left: 50%; transform: translateX(-50%); background: #1b2430; color: white; padding: 6px 14px; border-radius: 99px; font-size: 9pt; }
  @media print { .print-hint { display: none; } }
</style>
</head>
<body>
  <div class="doc-header">
    <h1>${escapeHtml(chat.title)}</h1>
    <p>PocketLLM Web · exported ${date} · ${visible.length} messages · stays on this device</p>
  </div>
  ${body}
  <div class="doc-footer">Exported locally from PocketLLM Web — no cloud involved in producing this file.</div>
  <div class="print-hint">Use “Save as PDF” in the print dialog to keep a copy.</div>
  <script>window.addEventListener('load', () => setTimeout(() => window.print(), 350));</script>
</body>
</html>`;

  const win = window.open('', '_blank', 'noopener');
  if (!win) {
    throw new Error('The browser blocked the export window. Allow pop-ups for this page.');
  }
  win.document.write(html);
  win.document.close();
}

/* ==================================================================== */
/*                          Markdown export                              */
/* ==================================================================== */

/** Renders one message as Markdown. Assistant content is already Markdown
 *  and is passed through untouched; user content is fenced off when it
 *  would otherwise collide with the surrounding structure.
 *  Shared with the combined history export. */
export function messageToMarkdown(
  m: Message,
  toolById: Map<string, ToolEvent>
): string {
  const who = m.role === 'user' ? 'You' : 'PocketLLM';
  const time = new Date(m.createdAt).toLocaleString();
  const header = `### ${who} · ${time}`;

  const toolLines = m.toolEvents
    .map((id) => toolById.get(id))
    .filter(Boolean)
    .map((t) => `> 🔧 \`${t!.tool}\` — ${t!.status}`)
    .join('\n>\n');

  const citeLines = m.citations.length
    ? m.citations
        .map(
          (c, i) =>
            `> 📄 [${i + 1}] ${c.documentName}${c.page ? ` (p.${c.page})` : ''} — score ${c.score.toFixed(2)}`
        )
        .join('\n')
    : '';

  const body =
    m.role === 'user'
      ? m.content.includes('\n') || /^#{1,6} |- |``` |\*\*|> /.test(m.content)
        ? `\n${m.content}\n` // multi-line/markdown-ish user text: keep verbatim
        : m.content
      : `\n${m.content}\n`; // assistant markdown passes through

  const blocks = [header, ''];
  if (toolLines) blocks.push(toolLines, '');
  blocks.push(body);
  if (citeLines) blocks.push('', citeLines);
  return blocks.join('\n');
}

/**
 * Exports a chat as a Markdown file. Returns the filename used so the
 * caller can confirm in a toast.
 */
export function exportChatToMarkdown(
  chat: Chat,
  messages: Message[],
  toolEvents: ToolEvent[]
): string {
  const visible = messages.filter((m) => m.role !== 'system');
  if (visible.length === 0) {
    throw new Error('Nothing to export — this chat has no messages yet.');
  }
  const toolById = new Map(toolEvents.map((t) => [t.id, t] as const));
  const exported = new Date().toLocaleString();

  const parts: string[] = [
    `# ${chat.title || 'Untitled chat'}`,
    '',
    `> Exported from **PocketLLM Web** on ${exported} · ${visible.length} messages · produced entirely on this device.`,
    '',
    '---',
    '',
  ];
  for (const m of visible) parts.push(messageToMarkdown(m, toolById), '');

  const blob = new Blob([parts.join('\n')], {
    type: 'text/markdown;charset=utf-8',
  });
  const url = URL.createObjectURL(blob);
  const filename = `${safeFilename(chat.title)}-${new Date().toISOString().slice(0, 10)}.md`;

  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.rel = 'noopener';
  document.body.appendChild(a);
  a.click();
  a.remove();
  // Give the download a moment before releasing the blob URL.
  window.setTimeout(() => URL.revokeObjectURL(url), 5_000);
  return filename;
}
