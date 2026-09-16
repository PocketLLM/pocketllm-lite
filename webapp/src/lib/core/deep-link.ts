/**
 * DeepLink — cross-view navigation hand-off.
 *
 * The command palette and search results know about entities (a specific
 * persona, prompt, note, memory, tag or chat message), but the manager
 * views own the editors. Rather than reaching into their internals, the
 * caller deposits a request here and navigates to the view; the view
 * consumes it:
 *
 *   - on mount, via `take()` — covers navigation from a different route
 *   - live, via the `pocketllm:deep-link` window event — covers navigation
 *     to the route that is already on screen (no remount)
 *
 * Mirrors the `pendingSend` hand-off used by the Home screen.
 */

export type DeepLinkKind = 'persona' | 'prompt' | 'note' | 'memory' | 'tag' | 'message';

export interface DeepLinkRequest {
  kind: DeepLinkKind;
  /** Entity id the target view should open its editor for. */
  id: string;
  /** For 'message' links — the chat the message lives in. */
  chatId?: string;
  /** For 'message' links — the search query that produced the hit. The
   *  chat view temporarily highlights occurrences inside the target
   *  message so the jump shows WHY it matched. */
  query?: string;
}

/** Window event name used for live (same-route) requests. */
export const DEEP_LINK_EVENT = 'pocketllm:deep-link';

/**
 * Pending composer draft (Knowledge → Chat hand-off).
 *
 * "Ask about this document" creates a fresh chat, deposits a prefilled
 * draft here and navigates; the chat view consumes it on mount so the
 * caret lands in the composer with the intent already typed out.
 * Unlike `pendingSend` (Home screen) this never auto-sends — the user
 * reviews/edits the draft first.
 */
export const pendingDraft = {
  chatId: '',
  text: '',
};

/**
 * Draft handed from the MARKETING site's command bar into the app's
 * home composer. The website deposits the prompt right before
 * navigating to `#/app`; the chat view consumes it when it mounts
 * without a chat id (the fresh-chat composer), so the marketing
 * demo funnels straight into the real product. Never auto-sends —
 * the user reviews the draft first.
 */
export const marketingDraft = {
  text: '',
};

/**
 * Module-level slot for the pending request. Only the most recent request
 * is kept — stale requests are simply overwritten.
 */
export const deepLink = {
  request: null as DeepLinkRequest | null,

  /** Deposit a request (called by the command palette before navigating). */
  set(request: DeepLinkRequest): void {
    this.request = request;
    // Notify a view that is already on screen (same-route navigation).
    window.dispatchEvent(new CustomEvent(DEEP_LINK_EVENT, { detail: request }));
  },

  /**
   * Consume the pending request for a given kind, if any. One-shot:
   * the request is cleared even when it does not match (navigation to the
   * view by other means discards it).
   */
  take(kind: DeepLinkKind): DeepLinkRequest | null {
    const request = this.request;
    this.request = null;
    return request && request.kind === kind ? request : null;
  },
};
