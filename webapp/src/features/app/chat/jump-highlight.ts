/**
 * Jump-highlight — temporary in-chat match highlighting for search
 * jumps ("why it matched").
 *
 * When the History message-search hands off to a chat, the target
 * bubble's occurrences of the query are wrapped in <mark class=
 * "match-jump"> by a pure DOM pass over text nodes. React never sees
 * these edits: the next real re-render of the bubble self-heals the
 * tree, and clearMatchHighlights() unwraps them on Escape / dismiss /
 * timeout. This mirrors the message-flash mechanism already used for
 * jump affordances.
 */

/** Elements whose text is never highlighted (controls + code chips). */
const SKIP_TAGS = new Set([
  'SCRIPT',
  'STYLE',
  'BUTTON',
  'KBD',
  'MARK',
  'TEXTAREA',
  'INPUT',
  'SELECT',
]);

/**
 * Wraps case-insensitive occurrences of `query` inside `root` with
 * <mark class="match-jump">. Idempotent: any previous pass is cleared
 * first, so repeated jumps re-apply cleanly. Returns the number of
 * highlights created (0 when the query is empty or absent).
 */
export function highlightMatches(root: HTMLElement, query: string): number {
  clearMatchHighlights(root);
  const q = query.trim();
  if (!q) return 0;
  const lower = q.toLowerCase();

  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
    acceptNode(node) {
      const parent = (node as Text).parentElement;
      if (!parent) return NodeFilter.FILTER_REJECT;
      if (SKIP_TAGS.has(parent.tagName)) return NodeFilter.FILTER_REJECT;
      if (
        !node.nodeValue ||
        !node.nodeValue.toLowerCase().includes(lower)
      ) {
        return NodeFilter.FILTER_REJECT;
      }
      return NodeFilter.FILTER_ACCEPT;
    },
  });

  const targets: Text[] = [];
  for (let n = walker.nextNode(); n; n = walker.nextNode()) {
    targets.push(n as Text);
  }

  let count = 0;
  for (const textNode of targets) {
    const text = textNode.nodeValue ?? '';
    const lowerText = text.toLowerCase();
    const frag = document.createDocumentFragment();
    let cursor = 0;
    let i = lowerText.indexOf(lower);
    while (i !== -1) {
      if (i > cursor) {
        frag.appendChild(document.createTextNode(text.slice(cursor, i)));
      }
      const mark = document.createElement('mark');
      mark.className = 'match-jump';
      mark.textContent = text.slice(i, i + q.length);
      frag.appendChild(mark);
      count += 1;
      cursor = i + q.length;
      i = lowerText.indexOf(lower, cursor);
    }
    if (cursor < text.length) {
      frag.appendChild(document.createTextNode(text.slice(cursor)));
    }
    textNode.parentNode?.replaceChild(frag, textNode);
  }
  return count;
}

/** Unwraps every match-jump mark under `root` (default: document). */
export function clearMatchHighlights(
  root: ParentNode = document
): void {
  for (const mark of Array.from(root.querySelectorAll('mark.match-jump'))) {
    const parent = mark.parentNode;
    if (!parent) continue;
    parent.replaceChild(document.createTextNode(mark.textContent ?? ''), mark);
    parent.normalize();
  }
}
