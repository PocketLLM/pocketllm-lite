import DOMPurify from "dompurify";
import { marked } from "marked";
import { useMemo } from "react";

marked.setOptions({ breaks: true, gfm: true });

export function Markdown({ content }: { content: string }) {
  const html = useMemo(() => {
    const raw = marked.parse(content || "", { async: false }) as string;
    return DOMPurify.sanitize(raw, {
      USE_PROFILES: { html: true },
      FORBID_TAGS: ["style", "iframe", "object", "embed", "form"],
      FORBID_ATTR: ["style", "onerror", "onclick", "onload"],
    });
  }, [content]);

  return <div className="markdown" dangerouslySetInnerHTML={{ __html: html }} />;
}
