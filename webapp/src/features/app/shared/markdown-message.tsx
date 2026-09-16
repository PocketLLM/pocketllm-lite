'use client';

/**
 * MarkdownMessage — safe Markdown renderer for chat content.
 *
 * react-markdown does not render raw HTML by default (XSS-safe).
 * Code blocks get syntax highlighting + a copy button.
 */
import { memo, useState } from 'react';
import ReactMarkdown from 'react-markdown';
import { Check, Copy } from 'lucide-react';

function CodeBlock({ children, className }: { children: React.ReactNode; className?: string }) {
  const [copied, setCopied] = useState(false);
  const language = /language-(\w+)/.exec(className ?? '')?.[1] ?? 'code';

  const copy = async (e: React.MouseEvent<HTMLButtonElement>) => {
    const pre = e.currentTarget.closest('[data-code-wrapper]')?.querySelector('code');
    const text = pre?.textContent ?? '';
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      /* clipboard denied */
    }
  };

  return (
    <div className="group/code relative my-3" data-code-wrapper>
      <div className="absolute right-2 top-2 z-10 flex items-center gap-1.5">
        <span className="rounded-md bg-white/10 px-1.5 py-0.5 font-mono text-[10px] uppercase tracking-wide text-slate-300/80">
          {language}
        </span>
        <button
          onClick={copy}
          className="rounded-md bg-white/10 p-1.5 text-slate-300 opacity-0 transition-opacity hover:bg-white/20 group-hover/code:opacity-100 focus:opacity-100"
          aria-label="Copy code"
        >
          {copied ? <Check className="h-3 w-3" /> : <Copy className="h-3 w-3" />}
        </button>
      </div>
      <pre>
        <code className={className}>{children}</code>
      </pre>
    </div>
  );
}

export const MarkdownMessage = memo(function MarkdownMessage({
  content,
}: {
  content: string;
}) {
  return (
    <div className="chat-prose">
      <ReactMarkdown
        components={{
          pre: ({ children }) => <>{children}</>,
          code: ({ className, children, ...props }) => {
            const isBlock = /language-/.test(className ?? '') || String(children).includes('\n');
            if (isBlock) {
              return <CodeBlock className={className}>{children}</CodeBlock>;
            }
            return (
              <code className={className} {...props}>
                {children}
              </code>
            );
          },
          a: ({ href, children }) => (
            <a href={href} target="_blank" rel="noopener noreferrer">
              {children}
            </a>
          ),
        }}
      >
        {content}
      </ReactMarkdown>
    </div>
  );
});
