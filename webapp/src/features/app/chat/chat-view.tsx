'use client';

/**
 * ChatView — the core conversation screen.
 *
 * Header: runtime/model selector, persona, privacy state, chat actions.
 * Body: message list with streaming overlays + tool confirmation banner.
 * Footer: composer with attachments, dictation, prompt enhancer.
 */
import { Fragment, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ArrowUp,
  Paperclip,
  Mic,
  Square,
  PanelLeft,
  PanelRight,
  Star,
  Archive,
  Trash2,
  Brain,
  Sparkles,
  Search,
  Image as ImageIcon,
  X,
  Check,
  CheckCircle2,
} from 'lucide-react';
import { useAppStore, useChatStore } from '@/lib/store/app-store';
import { chatService } from '@/lib/services/chat-service';
import { pipeline } from '@/lib/services/generation-pipeline';
import { audioService } from '@/lib/services/audio-service';
import { router } from '@/lib/core/router';
import { settingsService } from '@/lib/services/settings-service';
import { ModelSelector } from './model-selector';
import { PersonaSelector } from './persona-selector';
import { MessageBubble } from './message-bubble';
import { InspectorPanel } from './inspector-panel';
import { pendingSend } from '@/features/app/home/home-view';
import { DEEP_LINK_EVENT, deepLink, marketingDraft, pendingDraft } from '@/lib/core/deep-link';
import { cn, formatBytes, uuid, estimateTokens } from '@/lib/utils';
import { toast } from '@/hooks/use-toast';
import { bus } from '@/lib/core/events/event-bus';
import type { Attachment, Chat, ChatBranch } from '@/lib/types/domain';
import { exportChatToMarkdown, exportChatToPrint } from './chat-export';
import { FileText, Printer, ArrowDown, Pencil, Gauge } from 'lucide-react';
import { BrainCircuit } from 'lucide-react';
import {
  useSlashMenu,
  SlashMenu,
  type SlashCommand,
  type SlashCommandKind,
} from './slash-menu';
import { FollowUpSuggestions } from './follow-up-suggestions';
import {
  KnowledgeScopeChips,
  KnowledgeScopePicker,
  useReadyDocuments,
} from './knowledge-scope';
import {
  clearMatchHighlights,
  highlightMatches,
} from './jump-highlight';

export function ChatView({ chatId }: { chatId: string | null }) {
  const { setSidebarOpen, settings, inspectorOpen, setInspectorOpen, sidebarCollapsed, setSidebarCollapsed } = useAppStore();
  const { open, messages, toolEvents, streaming, activeChatId, refresh } = useChatStore();
  const [chat, setChat] = useState<Chat | null>(null);
  const [draft, setDraft] = useState('');
  const [draftSaved, setDraftSaved] = useState(false);
  const [attachments, setAttachments] = useState<Attachment[]>([]);
  const [recording, setRecording] = useState(false);
  const [enhancing, setEnhancing] = useState(false);
  const [branches, setBranches] = useState<ChatBranch[]>([]);
  /** Inline header rename state. */
  const [titleEditing, setTitleEditing] = useState(false);
  const [titleDraft, setTitleDraft] = useState('');
  /** Floating jump-to-latest pill visibility (scrolled away from bottom). */
  const [showJumpToBottom, setShowJumpToBottom] = useState(false);
  /** Whether the message list is scrolled at all (drives the top fade). */
  const [scrolledDown, setScrolledDown] = useState(false);
  /** j/k keyboard navigation cursor — index into `messages`, null = off. */
  const [navIndex, setNavIndex] = useState<number | null>(null);
  /** Active search jump-context: the query + how many marks were placed. */
  const [jumpMatch, setJumpMatch] = useState<{ query: string; count: number } | null>(null);
  /** Knowledge-scope popover open state — controlled so /scope can open it. */
  const [scopePickerOpen, setScopePickerOpen] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const bottomRef = useRef<HTMLDivElement>(null);
  const stickToBottom = useRef(true);
  /** Highest seq present when this chat opened — new messages animate in. */
  const initialMaxSeq = useRef<number | null>(null);

  // Reset the animation baseline when switching chats.
  useEffect(() => {
    initialMaxSeq.current = null;
  }, [chatId]);

  // Capture the baseline once the first (loaded) message list arrives.
  useEffect(() => {
    if (messages.length > 0 && initialMaxSeq.current === null) {
      initialMaxSeq.current = messages.reduce((max, m) => Math.max(max, m.seq), 0);
    }
  }, [messages]);

  // Load chat + subscribe.
  useEffect(() => {
    void open(chatId);
    if (chatId) {
      // Knowledge → Chat draft hand-off. Consumed synchronously so the
      // async getChat() below can never clobber it with the stored
      // (empty) draft of the brand-new chat.
      const handoff = pendingDraft.chatId === chatId && pendingDraft.text !== '';
      if (handoff) {
        const text = pendingDraft.text;
        pendingDraft.chatId = '';
        pendingDraft.text = '';
        setDraft(text);
        requestAnimationFrame(() => {
          const ta = textareaRef.current;
          if (!ta) return;
          ta.focus();
          // Caret at the end so typing continues the prefilled intent.
          const end = ta.value.length;
          ta.setSelectionRange(end, end);
        });
        toast({
          title: 'Draft ready',
          description: 'Send it as-is or edit first — this chat is scoped to that document, so retrieval searches only it.',
        });
      }
      void chatService.getChat(chatId).then((c) => {
        setChat(c ?? null);
        if (!handoff) setDraft(c?.draft ?? '');
      });
      void chatService.listBranches(chatId).then(setBranches);
      settingsService.patch({ meta: { lastActiveChatId: chatId } });
    } else {
      setChat(null);
      // Marketing command-bar hand-off: the website's "try it" bar
      // deposits a prompt and jumps into the app — land it in the
      // fresh-chat composer so the demo funnels into the product.
      const marketingHandoff = marketingDraft.text !== '';
      const text = marketingHandoff ? marketingDraft.text : '';
      marketingDraft.text = '';
      setDraft(text);
      if (marketingHandoff) {
        requestAnimationFrame(() => {
          const ta = textareaRef.current;
          if (!ta) return;
          ta.focus();
          const end = ta.value.length;
          ta.setSelectionRange(end, end);
        });
        toast({
          title: 'Prompt ready',
          description: 'Carried over from the website — edit it or hit send.',
        });
      }
      setBranches([]);
    }
    setAttachments([]);
  }, [chatId, open]);

  /* --------------------- knowledge retrieval scope ------------------- */
  // Ready documents feed the scope picker; the scope itself lives on the
  // Chat record so it persists and the generation pipeline reads it.
  const readyDocs = useReadyDocuments();

  /** Persists a new scope (empty = global) and updates local chat state. */
  const changeScope = useCallback(
    (docIds: string[]) => {
      if (!chat) return;
      void chatService.updateChat(chat.id, { knowledgeDocIds: docIds }).then((next) => {
        if (!next) return;
        setChat(next);
        if (docIds.length === 0) {
          toast({
            title: 'Scope reset',
            description: 'Retrieval searches all ready documents again.',
          });
        } else {
          toast({
            title: `Scope set — ${docIds.length} document${docIds.length > 1 ? 's' : ''}`,
            description: 'Retrieval now searches only the scoped documents.',
          });
        }
      });
    },
    [chat]
  );

  /**
   * Pins or resets this chat's retrieval-mode override. Null = follow
   * the Settings default; a concrete mode keeps this chat's ranking
   * stable even when the global default changes.
   */
  const changeRetrievalMode = useCallback(
    (mode: Chat['retrievalMode']) => {
      if (!chat) return;
      void chatService.updateChat(chat.id, { retrievalMode: mode }).then((next) => {
        if (!next) return;
        setChat(next);
        toast({
          title: mode ? `Retrieval mode pinned — ${mode}` : 'Retrieval mode reset',
          description: mode
            ? `This chat always ranks Knowledge results with ${mode}, regardless of Settings.`
            : 'This chat follows the Settings default again.',
        });
      });
    },
    [chat]
  );

  /* ------------------- message deep-link (search jumps) -------------- */
  // History-view message search deposits a {kind:'message'} request and
  // navigates here. The target message may not be rendered yet, so the
  // pending id waits in a ref until the message list contains it; then
  // the bubble scrolls into view and flashes (same treatment as the
  // inspector's in-chat search). When the request carries a query, its
  // occurrences inside the bubble are temporarily <mark>-highlighted so
  // the jump shows WHY the message matched.
  const pendingJumpId = useRef<string | null>(null);
  const pendingJumpQuery = useRef<string | null>(null);
  /** Auto-clear timer for the jump-context highlight. */
  const jumpClearTimer = useRef<number | null>(null);

  /** Removes any jump-context marks + chip state. */
  const clearJumpMatch = useCallback(() => {
    if (jumpClearTimer.current != null) {
      window.clearTimeout(jumpClearTimer.current);
      jumpClearTimer.current = null;
    }
    clearMatchHighlights();
    setJumpMatch(null);
  }, []);

  /** Scrolls to + flashes the pending jump target, if rendered. */
  const attemptJump = useCallback(() => {
    const id = pendingJumpId.current;
    if (!id) return;
    const el = document.querySelector(`[data-message-id="${id}"]`);
    if (!el) return;
    pendingJumpId.current = null;
    el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    el.classList.add('message-flash');
    window.setTimeout(() => el.classList.remove('message-flash'), 1400);
    // Jump-context: highlight occurrences of the originating query.
    const query = pendingJumpQuery.current;
    pendingJumpQuery.current = null;
    if (query) {
      const count = highlightMatches(el as HTMLElement, query);
      setJumpMatch({ query, count });
      if (jumpClearTimer.current != null) {
        window.clearTimeout(jumpClearTimer.current);
      }
      // Highlights are temporary — cleared by Escape, the chip's X, or
      // this generous timeout (a re-render of the bubble self-heals too).
      jumpClearTimer.current = window.setTimeout(() => {
        clearMatchHighlights();
        setJumpMatch(null);
        jumpClearTimer.current = null;
      }, 12_000);
    }
  }, []);

  useEffect(() => {
    const req = deepLink.take('message');
    pendingJumpId.current = req && req.chatId === chatId ? req.id : null;
    pendingJumpQuery.current = req && req.chatId === chatId ? (req.query ?? null) : null;
    // Same-route live jumps (rare: search results while a chat is open).
    const onLive = (e: Event) => {
      const detail = (e as CustomEvent<{ kind: string; id: string; chatId?: string; query?: string }>).detail;
      if (detail?.kind === 'message' && detail.chatId === chatId) {
        pendingJumpId.current = detail.id;
        pendingJumpQuery.current = detail.query ?? null;
        attemptJump();
      }
    };
    window.addEventListener(DEEP_LINK_EVENT, onLive);
    return () => window.removeEventListener(DEEP_LINK_EVENT, onLive);
  }, [chatId, attemptJump]);

  // Retry the jump whenever messages arrive (covers async load).
  useEffect(() => {
    if (pendingJumpId.current && messages.some((m) => m.id === pendingJumpId.current)) {
      // Wait a frame so the bubble's layout is committed.
      requestAnimationFrame(() => attemptJump());
    }
  }, [messages, attemptJump]);

  // Live branch updates (edit→branch while viewing).
  useEffect(() => {
    if (!chatId) return;
    return bus.on('branches:changed', ({ chatId: changed }) => {
      if (changed === chatId) void chatService.listBranches(chatId).then(setBranches);
    });
  }, [chatId]);

  /* -------------------- j/k message navigation ----------------------- */
  // (Effect moved below the slash declaration — it depends on slash.open.)

  // "Continue in chat" hand-off (starred view) — after the deep-link jump
  // lands, put the caret in the composer so typing can resume immediately.
  // The caret is placed at the END of any prefilled draft (Knowledge → Chat
  // hand-off) so continued typing extends the intent naturally.
  useEffect(() => {
    const onFocusComposer = () => {
      const ta = textareaRef.current;
      if (!ta) return;
      ta.focus();
      const end = ta.value.length;
      ta.setSelectionRange(end, end);
    };
    window.addEventListener('pocketllm:focus-composer', onFocusComposer);
    return () => window.removeEventListener('pocketllm:focus-composer', onFocusComposer);
  }, []);

  // Initial hand-off message from the Home screen.
  useEffect(() => {
    if (chatId && pendingSend.message && messages.length === 0 && !pipeline.isStreaming()) {
      const message = pendingSend.message;
      pendingSend.message = '';
      void pipeline.send({ chatId, content: message });
    }
  }, [chatId, messages.length]);

  // Draft autosave (debounced) with a subtle saved indicator. Empty drafts
  // are still persisted — otherwise a sent message would resurrect as a
  // draft after reload.
  useEffect(() => {
    if (!chatId) return;
    setDraftSaved(false);
    const t = setTimeout(
      () =>
        void chatService
          .saveDraft(chatId, draft)
          .then(() => setDraftSaved(!!draft.trim())),
      600
    );
    return () => clearTimeout(t);
  }, [draft, chatId]);

  // Acknowledge automatic memory extraction (plan §memory: honest feedback).
  useEffect(() => {
    return bus.on('memories:extracted', ({ chatId: changed, count, facts }) => {
      if (changed !== chatId) return;
      toast({
        title: `${count} memor${count === 1 ? 'y' : 'ies'} saved`,
        description: facts[0]
          ? `“${facts[0].slice(0, 90)}”${facts.length > 1 ? ` · +${facts.length - 1} more` : ''}`
          : 'Review or edit them anytime in Memories.',
        duration: 6000,
      });
    });
  }, [chatId]);

  // Autoscroll while streaming / on new messages.
  useEffect(() => {
    if (stickToBottom.current) {
      bottomRef.current?.scrollIntoView({ behavior: pipeline.isStreaming() ? 'auto' : 'smooth' });
    }
  }, [messages.length, streaming]);

  // Edit-branch event from MessageBubble.
  useEffect(() => {
    const handler = (e: Event) => {
      const detail = (e as CustomEvent<{ messageId: string; content: string }>).detail;
      if (!chatId) return;
      void pipeline.send({
        chatId,
        content: detail.content,
        branchFromMessageId: detail.messageId,
      });
      toast({
        title: 'Branch created',
        description: 'The original message is preserved — switch variants from its branch menu.',
      });
    };
    window.addEventListener('pocketllm:edit-branch', handler);
    return () => window.removeEventListener('pocketllm:edit-branch', handler);
  }, [chatId]);

  // Keep the local chat object fresh (title changes, etc).
  useEffect(() => {
    if (!chatId) return;
    const unsub = useAppStore.subscribe((s) => {
      const found = s.chats.find((c) => c.id === chatId);
      if (found) setChat(found);
    });
    return unsub;
  }, [chatId]);

  const onScroll = () => {
    const el = scrollRef.current;
    if (!el) return;
    stickToBottom.current = el.scrollHeight - el.scrollTop - el.clientHeight < 120;
    const away = el.scrollHeight - el.scrollTop - el.clientHeight > 300;
    setShowJumpToBottom((prev) => (prev === away ? prev : away));
    const scrolled = el.scrollTop > 8;
    setScrolledDown((prev) => (prev === scrolled ? prev : scrolled));
  };

  const jumpToLatest = () => {
    stickToBottom.current = true;
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const send = useCallback(
    async (override?: string) => {
      const text = (override ?? draft).trim();
      if (!text && attachments.length === 0) return;
      if (pipeline.isStreaming()) return;
      if (!chatId) return;
      setDraft('');
      const currentAttachments = attachments;
      setAttachments([]);
      stickToBottom.current = true;
      await pipeline.send({
        chatId,
        content: text,
        attachments: currentAttachments,
      });
    },
    [draft, attachments, chatId]
  );

  const regenerate = useCallback(async () => {
    if (!chatId) return;
    // Find the last user message.
    const lastUser = [...messages].reverse().find((m) => m.role === 'user');
    if (!lastUser) return;
    // Remove trailing assistant messages after it.
    const after = messages.filter(
      (m) => m.seq > lastUser.seq && m.role === 'assistant'
    );
    for (const m of after) await chatService.deleteMessage(m.id);
    await refresh();
    await pipeline.send({ chatId, content: lastUser.content, regenerateAfterMessageId: lastUser.id });
  }, [chatId, messages, refresh]);

  const startRecording = async () => {
    try {
      await audioService.startRecording();
      setRecording(true);
    } catch {
      toast({
        title: 'Microphone unavailable',
        description: 'Grant microphone permission to dictate.',
        variant: 'destructive',
      });
    }
  };

  const stopRecording = async () => {
    setRecording(false);
    try {
      const blob = await audioService.stopRecording();
      if (blob.size === 0) return;
      toast({ title: 'Transcribing…' });
      const transcript = await audioService.transcribe(blob, 'recording.webm', 0);
      if (transcript.text) setDraft((v) => (v ? `${v} ${transcript.text}` : transcript.text));
    } catch (err) {
      toast({
        title: 'Transcription failed',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    }
  };

  const enhance = async () => {
    if (!draft.trim() || enhancing) return;
    setEnhancing(true);
    try {
      const { gateway } = await import('@/lib/core/net/network-gateway');
      const res = await gateway.request('assist-enhance', '/api/enhance', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt: draft }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = (await res.json()) as { prompt?: string };
      if (json.prompt) setDraft(json.prompt);
      toast({ title: 'Prompt enhanced', description: 'Original wording is preserved in history.' });
    } catch (err) {
      toast({
        title: 'Could not enhance prompt',
        description: err instanceof Error ? err.message : 'Try again.',
        variant: 'destructive',
      });
    } finally {
      setEnhancing(false);
    }
  };

  const addFiles = useCallback((files: FileList | File[]) => {
    for (const file of Array.from(files)) {
      if (file.type.startsWith('image/')) {
        if (file.size > 8 * 1024 * 1024) {
          toast({ title: 'Image too large', description: 'Keep images under 8 MB.', variant: 'destructive' });
          continue;
        }
        const reader = new FileReader();
        reader.onload = () => {
          setAttachments((prev) => [
            ...prev,
            {
              id: uuid(),
              kind: 'image',
              name: file.name,
              mimeType: file.type,
              sizeBytes: file.size,
              dataUrl: String(reader.result),
            },
          ]);
        };
        reader.readAsDataURL(file);
      } else {
        // Non-image files → suggest Knowledge import.
        toast({
          title: `${file.name} added to Knowledge instead`,
          description: 'Documents are searchable from chat through Knowledge.',
        });
        import('@/lib/services/document-service').then(({ documentService }) => {
          documentService.import(file).catch((err: unknown) => {
            toast({
              title: 'Import failed',
              description: err instanceof Error ? err.message : String(err),
              variant: 'destructive',
            });
          });
        });
      }
    }
  }, []);

  // Paste image support.
  useEffect(() => {
    const onPaste = (e: ClipboardEvent) => {
      if (!chatId) return;
      const items = Array.from(e.clipboardData?.items ?? []);
      const images = items
        .filter((i) => i.type.startsWith('image/'))
        .map((i) => i.getAsFile())
        .filter((f): f is File => !!f);
      if (images.length) {
        e.preventDefault();
        addFiles(images);
      }
    };
    document.addEventListener('paste', onPaste);
    return () => document.removeEventListener('paste', onPaste);
  }, [chatId, addFiles]);

  // Textarea autosize.
  useEffect(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = 'auto';
    el.style.height = `${Math.min(el.scrollHeight, 180)}px`;
  }, [draft]);

  const busy = pipeline.isStreaming();
  const status = useAppStore((s) => s.pipelineStatus);
  const models = useAppStore((s) => s.models);

  /* -------------------- generating tab title -------------------------- */
  // While a reply streams, flag it in the browser tab so a user parked on
  // another tab knows the exact moment the answer lands. The route title
  // AppShell set is saved before the swap and restored afterwards — but
  // only if the tab still shows OUR marker (if the user navigated to a
  // different route mid-generation, AppShell already replaced the title
  // and we must not clobber it with a stale one).
  const generatingTitleRef = useRef<string | null>(null);
  useEffect(() => {
    const MARKER = '● Generating… · PocketLLM';
    if (busy) {
      if (generatingTitleRef.current === null) {
        generatingTitleRef.current = document.title;
        document.title = MARKER;
      }
    } else if (generatingTitleRef.current !== null) {
      if (document.title === MARKER) document.title = generatingTitleRef.current;
      generatingTitleRef.current = null;
    }
    return () => {
      // Unmounted mid-generation (route change, chat switch): hand the
      // saved title back only when the marker is still on display.
      if (generatingTitleRef.current !== null) {
        if (document.title === MARKER) document.title = generatingTitleRef.current;
        generatingTitleRef.current = null;
      }
    };
  }, [busy]);

  /* -------------------- inline title renaming ------------------------ */
  const commitTitle = useCallback(async () => {
    setTitleEditing(false);
    if (!chat) return;
    const value = titleDraft.trim().slice(0, 120);
    if (!value || value === chat.title) return;
    await chatService.updateChat(chat.id, { title: value });
    useAppStore.getState().refreshChats();
    toast({ title: 'Chat renamed', description: `Now called “${value}”.` });
  }, [chat, titleDraft]);

  /* ----------------- composer context budget ------------------------- */
  // Same honest estimate the inspector uses: chars/4 for the messages
  // inside the context window, scaled against the model's real limit
  // (or an explicit "assumed 8k" fallback for runtimes that report none).
  const contextPct = useMemo(() => {
    const windowMsgs = messages.slice(-settings.chat.maxContextMessages);
    const used = windowMsgs.reduce(
      (sum, m) => sum + estimateTokens(m.content) + 4,
      0
    );
    const activeModel = models.find((m) => m.id === chat?.modelId);
    const scale = activeModel?.contextLimit ?? 8192;
    return Math.min(100, Math.round((used / scale) * 100));
  }, [messages, settings.chat.maxContextMessages, models, chat?.modelId]);
  const contextAssumed = !models.find((m) => m.id === chat?.modelId)?.contextLimit;

  /* ---------------------- slash command menu ------------------------ */
  const applySlashPick = useCallback(
    (pick: SlashCommandKind) => {
      if (!chat) return;
      if (pick.type === 'insert') {
        setDraft(pick.text);
        requestAnimationFrame(() => textareaRef.current?.focus());
        return;
      }
      // Every other outcome clears the slash text from the composer.
      setDraft('');
      if (pick.type === 'persona') {
        void chatService
          .updateChat(chat.id, { personaId: pick.persona.id })
          .then(() => {
            useAppStore.getState().refreshChats();
            toast({
              title: `Persona switched to ${pick.persona.emoji} ${pick.persona.name}`,
              description: 'New replies follow its instructions and temperature.',
            });
          });
        return;
      }
      switch (pick.action) {
        case 'new-chat':
          void chatService.createChat().then((c) => {
            useAppStore.getState().refreshChats();
            router.navigate(`/app/chat/${c.id}`);
          });
          break;
        case 'export-markdown':
          try {
            const filename = exportChatToMarkdown(chat, messages, toolEvents);
            toast({
              title: 'Markdown exported',
              description: `${filename} downloaded — open it in any notes app.`,
            });
          } catch (err) {
            toast({
              title: 'Export failed',
              description: err instanceof Error ? err.message : 'Try again.',
              variant: 'destructive',
            });
          }
          break;
        case 'export-pdf':
          try {
            exportChatToPrint(chat, messages, toolEvents);
          } catch (err) {
            toast({
              title: 'Export blocked',
              description: err instanceof Error ? err.message : 'Try again.',
              variant: 'destructive',
            });
          }
          break;
        case 'toggle-inspector':
          setInspectorOpen(!inspectorOpen);
          break;
        case 'toggle-focus':
          setSidebarCollapsed(!sidebarCollapsed);
          break;
        case 'open-scope':
          setScopePickerOpen(true);
          break;
        case 'open-shortcuts':
          // The shortcuts dialog listens for a global "?" keypress.
          window.dispatchEvent(
            new KeyboardEvent('keydown', { key: '?', bubbles: true })
          );
          break;
      }
    },
    [chat, messages, toolEvents, inspectorOpen, sidebarCollapsed, setInspectorOpen, setSidebarCollapsed]
  );

  const slash = useSlashMenu({
    draft,
    setDraft,
    onPick: applySlashPick,
  });

  /* -------------------- j/k message navigation ----------------------- */
  // Vim-style cursor over the visible messages. Only active while the
  // user is NOT typing somewhere (composer, inputs) and no menu/dialog
  // is open, so it never fights the slash menu or Radix surfaces.
  //   j → toward the bottom (newer) · k → toward the top (older)
  //   c → copy the selected message · s → star it · Esc → leave
  // From no selection: j starts at the first message, k at the latest.
  const isTypingHost = (target: EventTarget | null): boolean => {
    const el = target as HTMLElement | null;
    if (!el) return false;
    const tag = el.tagName?.toLowerCase();
    return (
      tag === 'input' ||
      tag === 'textarea' ||
      tag === 'select' ||
      el.isContentEditable === true
    );
  };

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      if (isTypingHost(e.target)) return;
      if (slash.open) return;
      if (document.querySelector('[role="dialog"], [role="menu"], [role="listbox"]')) return;

      if (e.key === 'j' || e.key === 'k') {
        if (messages.length === 0) return;
        e.preventDefault();
        setNavIndex((prev) => {
          if (prev == null) return e.key === 'j' ? 0 : messages.length - 1;
          if (e.key === 'j') return Math.min(prev + 1, messages.length - 1);
          return Math.max(prev - 1, 0);
        });
        return;
      }

      if (e.key === 'Escape') {
        // Esc clears the nav cursor first, then any jump highlights.
        if (navIndex != null) {
          setNavIndex(null);
          return;
        }
        if (jumpMatch) clearJumpMatch();
        return;
      }

      if (navIndex != null && messages[navIndex]) {
        const target = messages[navIndex];
        if (e.key === 'c') {
          e.preventDefault();
          void navigator.clipboard
            .writeText(target.content)
            .then(() => toast({ title: 'Message copied', description: `${target.content.length.toLocaleString()} characters on the clipboard.` }))
            .catch(() => toast({ title: 'Clipboard blocked by the browser', variant: 'destructive' }));
        } else if (e.key === 's') {
          e.preventDefault();
          void chatService
            .updateMessage(target.id, { starred: !target.starred })
            .then(() => {
              toast({ title: target.starred ? 'Star removed' : 'Message starred' });
            });
        }
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [messages, navIndex, jumpMatch, slash.open, clearJumpMatch]);

  // Keep the selected message in view while the cursor moves.
  useEffect(() => {
    if (navIndex == null) return;
    const m = messages[navIndex];
    if (!m) return;
    document
      .querySelector(`[data-message-id="${m.id}"]`)
      ?.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }, [navIndex, messages]);

  // Reset the cursor when switching chats, and clamp it if the list shrinks.
  useEffect(() => {
    setNavIndex(null);
  }, [chatId]);
  useEffect(() => {
    if (navIndex != null && navIndex >= messages.length) setNavIndex(null);
  }, [messages.length, navIndex]);

  // Clear any leftover jump highlights on unmount.
  useEffect(() => {
    return () => {
      clearMatchHighlights();
    };
  }, []);

  if (!chatId || !chat) {
    return (
      <div className="flex flex-1 flex-col items-center justify-center gap-2 text-center">
        <p className="text-sm text-muted-foreground">This chat doesn&apos;t exist.</p>
        <button className="text-sm underline" onClick={() => router.navigate('/app')}>
          Back home
        </button>
      </div>
    );
  }

  return (
    <div className="flex h-full min-h-0">
      <div className="flex h-full min-h-0 min-w-0 flex-1 flex-col">
      {/* Header */}
      <header className="flex h-14 shrink-0 items-center gap-2 border-b border-border px-3 sm:px-4">
        <button
          className={cn(
            'rounded-lg p-2 hover:bg-muted',
            // Always visible below lg; on lg only when focus mode hid the sidebar.
            sidebarCollapsed ? 'inline-flex' : 'lg:hidden'
          )}
          onClick={() => {
            if (window.matchMedia('(min-width: 1024px)').matches) {
              setSidebarCollapsed(false);
            } else {
              setSidebarOpen(true);
            }
          }}
          aria-label="Open menu"
        >
          <PanelLeft className="h-4 w-4" />
        </button>
        <ModelSelector chat={chat} />
        <PersonaSelector chat={chat} />
        {/* Conversation title — click to rename (sm+; the sidebar carries
            the title on xs screens). */}
        {titleEditing ? (
          <input
            autoFocus
            value={titleDraft}
            onChange={(e) => setTitleDraft(e.target.value)}
            onBlur={() => void commitTitle()}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                void commitTitle();
              }
              if (e.key === 'Escape') {
                e.preventDefault();
                setTitleEditing(false);
              }
            }}
            maxLength={120}
            aria-label="Chat title"
            className="min-w-0 flex-1 rounded-lg border border-brand-strong bg-card px-2.5 py-1 text-[13px] font-medium outline-none ring-2 ring-brand/25"
          />
        ) : (
          <button
            onClick={() => {
              setTitleDraft(chat.title);
              setTitleEditing(true);
            }}
            title="Rename this chat"
            aria-label={`Rename chat: ${chat.title || 'Untitled chat'}`}
            className="group/title ml-1 hidden min-w-0 flex-1 items-center gap-1.5 overflow-hidden rounded-lg border border-transparent px-2 py-1 text-[13px] font-medium text-foreground/75 transition-all hover:border-border hover:bg-muted hover:text-foreground lg:flex"
          >
            <span className="min-w-0 truncate">{chat.title || 'Untitled chat'}</span>
            <Pencil className="h-3 w-3 shrink-0 opacity-0 transition-opacity group-hover/title:opacity-60" aria-hidden />
          </button>
        )}
        <div className="ml-1 hidden items-center gap-2 sm:flex">
          {settings.privacy.strictOffline && (
            <span className="rounded-full bg-brand px-2 py-0.5 text-[10px] font-semibold text-brand-foreground">
              STRICT OFFLINE
            </span>
          )}
        </div>
        <div className="ml-auto flex items-center gap-0.5">
          <button
            onClick={() => useAppStore.getState().setCommandPaletteOpen(true)}
            className={cn(
              'mr-1 hidden items-center gap-2 rounded-full border border-border bg-card px-3 py-1.5 text-[12px] text-muted-foreground transition-colors hover:border-brand-strong hover:text-foreground sm:flex',
              // The inspector (xl+) carries its own conversation search —
              // reclaim the header space for the chat title there.
              inspectorOpen && 'xl:hidden'
            )}
            aria-label="Open command palette (Ctrl+K)"
            aria-keyshortcuts="Ctrl+K"
          >
            <Search className="h-3.5 w-3.5" />
            <span className="hidden lg:inline">Search…</span>
            <kbd className="hidden rounded border border-border bg-muted px-1.5 py-0.5 font-mono text-[10px] font-semibold lg:inline">
              ⌘K
            </kbd>
          </button>
          <HeaderIconButton
            label={inspectorOpen ? 'Hide inspector' : 'Show inspector'}
            onClick={() => setInspectorOpen(!inspectorOpen)}
            active={inspectorOpen}
            className="hidden xl:inline-flex"
          >
            <PanelRight className="h-4 w-4" />
          </HeaderIconButton>
          <HeaderIconButton
            label="Export chat as PDF (print dialog)"
            onClick={() => {
              try {
                exportChatToPrint(chat, messages, toolEvents);
              } catch (err) {
                toast({
                  title: 'Export blocked',
                  description: err instanceof Error ? err.message : 'Try again.',
                  variant: 'destructive',
                });
              }
            }}
          >
            <Printer className="h-4 w-4" />
          </HeaderIconButton>
          <HeaderIconButton
            label="Export chat as Markdown file"
            onClick={() => {
              try {
                const filename = exportChatToMarkdown(chat, messages, toolEvents);
                toast({
                  title: 'Markdown exported',
                  description: `${filename} downloaded — open it in any notes app.`,
                });
              } catch (err) {
                toast({
                  title: 'Export failed',
                  description: err instanceof Error ? err.message : 'Try again.',
                  variant: 'destructive',
                });
              }
            }}
          >
            <FileText className="h-4 w-4" />
          </HeaderIconButton>
          <HeaderIconButton
            label={chat.memoryEnabled ? 'Memory is on for this chat' : 'Memory is off for this chat'}
            onClick={async () => {
              await chatService.updateChat(chat.id, {
                memoryEnabled: !chat.memoryEnabled,
              });
              toast({
                title: chat.memoryEnabled ? 'Memory paused for this chat' : 'Memory enabled',
                description: chat.memoryEnabled
                  ? 'Nothing new will be extracted or retrieved while paused.'
                  : 'Relevant memories will be used and new ones may be extracted.',
              });
            }}
            active={chat.memoryEnabled}
          >
            <BrainCircuit className={cn('h-4 w-4', !chat.memoryEnabled && 'text-destructive')} />
          </HeaderIconButton>
          <HeaderIconButton
            label="Star conversation"
            onClick={async () => {
              await chatService.updateChat(chat.id, { pinned: !chat.pinned });
              useAppStore.getState().refreshChats();
            }}
            active={chat.pinned}
          >
            <Star className={cn('h-4 w-4', chat.pinned && 'fill-brand text-brand-strong')} />
          </HeaderIconButton>
          <HeaderIconButton
            label={chat.archived ? 'Unarchive' : 'Archive'}
            onClick={async () => {
              await chatService.updateChat(chat.id, { archived: !chat.archived });
              useAppStore.getState().refreshChats();
              toast({ title: chat.archived ? 'Chat unarchived' : 'Chat archived' });
            }}
          >
            <Archive className="h-4 w-4" />
          </HeaderIconButton>
          <HeaderIconButton
            label="Delete conversation"
            danger
            onClick={async () => {
              await chatService.deleteChat(chat.id);
              useAppStore.getState().refreshChats();
              router.navigate('/app');
              toast({ title: 'Chat deleted', description: 'Messages, branches and tool events removed.' });
            }}
          >
            <Trash2 className="h-4 w-4" />
          </HeaderIconButton>
        </div>
      </header>

      {/* Messages */}
      <div
        className="relative min-h-0 flex-1"
        data-scrolled={scrolledDown ? 'true' : 'false'}
      >
        {/* Top scroll fade — appears once the list is scrolled. */}
        <div className="scroll-fade-top" aria-hidden />
        {/* Jump-context chip — shows why a search jump landed here. Sits
            bottom-LEFT (mirroring the j/k pill on the right) so it can never
            cover the jumped-to message, which scrolls to the center. */}
        {jumpMatch && (
          <div
            role="status"
            className="absolute bottom-3 left-4 z-10 flex max-w-[60%] items-center gap-2 rounded-full border border-brand-strong/50 bg-brand-soft/95 py-1.5 pl-3 pr-1.5 text-[12px] text-foreground shadow-md backdrop-blur animate-pop-in sm:max-w-none dark:bg-brand/10"
          >
            <Search className="h-3.5 w-3.5 shrink-0 text-brand-strong" aria-hidden />
            <span className="truncate">
              Matched{' '}
              <mark className="match-jump">{jumpMatch.query}</mark>
              {jumpMatch.count > 0 && (
                <span className="ml-1 tabular-nums text-muted-foreground">
                  · {jumpMatch.count} highlight{jumpMatch.count === 1 ? '' : 's'}
                </span>
              )}
            </span>
            <button
              type="button"
              onClick={clearJumpMatch}
              aria-label="Clear match highlighting"
              className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
            >
              <X className="h-3 w-3" />
            </button>
          </div>
        )}
        {/* j/k navigation position pill. */}
        {navIndex != null && messages.length > 0 && (
          <div
            role="status"
            aria-label={`Message ${navIndex + 1} of ${messages.length} selected. Press c to copy, s to star, Escape to exit.`}
            className="absolute bottom-3 right-4 z-10 flex items-center gap-2 rounded-full border border-border bg-background/95 py-1.5 pl-3 pr-2 text-[11px] text-muted-foreground shadow-md backdrop-blur animate-pop-in"
          >
            <span className="font-medium tabular-nums text-foreground">
              {navIndex + 1} / {messages.length}
            </span>
            <span className="h-3 w-px bg-border" aria-hidden />
            {/* Action hints collapse below sm so the pill can never collide
                with the jump-context chip on narrow screens. */}
            <span className="hidden items-center gap-1 sm:flex">
              <MiniKbd>c</MiniKbd> copy
            </span>
            <span className="hidden items-center gap-1 sm:flex">
              <MiniKbd>s</MiniKbd> star
            </span>
            <span className="hidden items-center gap-1 sm:flex">
              <MiniKbd>esc</MiniKbd> exit
            </span>
            <button
              type="button"
              onClick={() => setNavIndex(null)}
              aria-label="Exit message navigation"
              className="ml-0.5 flex h-5 w-5 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
            >
              <X className="h-3 w-3" />
            </button>
          </div>
        )}
        {/* Floating jump-to-latest pill. Lifts one row when the match chip
            is showing so the two never collide on narrow screens. */}
        {showJumpToBottom && (
          <button
            type="button"
            onClick={jumpToLatest}
            className={cn(
              'absolute left-1/2 z-10 flex -translate-x-1/2 items-center gap-1.5 rounded-full border border-border bg-background/95 py-1.5 pl-2.5 pr-3 text-[12px] font-medium text-foreground shadow-md backdrop-blur transition-all hover:-translate-y-0.5 hover:border-brand-strong animate-pop-in',
              jumpMatch ? 'bottom-14' : 'bottom-3'
            )}
            aria-label="Jump to latest message"
          >
            <span className="flex h-5 w-5 items-center justify-center rounded-full bg-brand text-brand-foreground">
              <ArrowDown className="h-3 w-3" />
            </span>
            Jump to latest
          </button>
        )}
      <div
        ref={scrollRef}
        onScroll={onScroll}
        className="h-full overflow-y-auto scrollbar-slim"
        role="log"
        aria-live="polite"
        aria-label="Conversation"
      >
        <div className="mx-auto w-full max-w-3xl px-4 py-4 pb-6">
          {messages.length === 0 && !busy && (
            <div className="flex flex-col items-center py-14 text-center">
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl border border-brand/50 bg-brand-soft dark:bg-brand/15">
                <Brain className="h-6 w-6 text-brand-strong" />
              </div>
              <p className="mt-4 text-[15px] font-medium">Start the conversation</p>
              <p className="mt-1 max-w-sm text-[13px] leading-relaxed text-muted-foreground">
                Everything stays on this device. Type{' '}
                <code className="rounded border border-border bg-muted/60 px-1 font-mono text-[11px]">/</code>{' '}
                for commands, or start from one of these:
              </p>
              <div className="mt-5 flex max-w-md flex-wrap justify-center gap-2">
                {STARTER_CHIPS.map((chip) => (
                  <button
                    key={chip}
                    type="button"
                    onClick={() => {
                      setDraft(chip);
                      requestAnimationFrame(() => textareaRef.current?.focus());
                    }}
                    className="rounded-full border border-border bg-card px-3.5 py-1.5 text-[12.5px] text-muted-foreground transition-all hover:-translate-y-px hover:border-brand-strong hover:text-foreground hover:shadow-sm"
                  >
                    {chip}
                  </button>
                ))}
              </div>
            </div>
          )}
          {messages.map((m, index) => {
            const isLastAssistant =
              m.role === 'assistant' &&
              messages.findIndex((x) => x.role === 'assistant' && x.seq > m.seq) === -1;
            // Branch switcher: this message is one of several variants.
            const branchForMessage = branches.find(
              (b) => b.variants.includes(m.id) && b.variants.length > 1
            );
            const variantIndex = branchForMessage
              ? branchForMessage.variants.indexOf(m.id)
              : -1;
            // Day separator appears when the calendar day changes between
            // consecutive messages (classic chat-log rhythm, honest local
            // timezone grouping).
            const prev = messages[index - 1];
            const newDay = !prev || !sameLocalDay(prev.createdAt, m.createdAt);
            return (
              <Fragment key={m.id}>
                {newDay && (
                  <div
                    className="my-4 flex items-center gap-3 first:mt-0"
                    role="separator"
                    aria-label={dayLabel(m.createdAt)}
                  >
                    <span className="h-px flex-1 bg-border" aria-hidden="true" />
                    <time
                      className="rounded-full border border-border bg-muted/70 px-2.5 py-0.5 text-[10.5px] font-medium uppercase tracking-wider text-muted-foreground"
                      dateTime={new Date(m.createdAt).toISOString().slice(0, 10)}
                    >
                      {dayLabel(m.createdAt)}
                    </time>
                    <span className="h-px flex-1 bg-border" aria-hidden="true" />
                  </div>
                )}
                <MessageBubble
                  message={streaming[m.id] !== undefined ? { ...m, content: streaming[m.id] } : m}
                  toolEvents={toolEvents}
                  isStreamingThis={streaming[m.id] !== undefined}
                  isLastAssistant={isLastAssistant && !busy}
                  isFirst={index === 0}
                  selected={navIndex === index}
                  animate={
                    initialMaxSeq.current !== null && m.seq > initialMaxSeq.current
                  }
                  branch={
                    branchForMessage && variantIndex >= 0
                      ? {
                          id: branchForMessage.id,
                          count: branchForMessage.variants.length,
                          index: variantIndex,
                          onSwitch: (dir: 1 | -1) => {
                            const nextId =
                              branchForMessage.variants[
                                (variantIndex + dir + branchForMessage.variants.length) %
                                  branchForMessage.variants.length
                              ];
                            if (nextId) {
                              void chatService.switchVariant(chatId, branchForMessage.id, nextId);
                            }
                          },
                        }
                      : undefined
                  }
                  onRegenerate={() => void regenerate()}
                  onDeleted={() => void refresh()}
                  showTokens={settings.chat.showTokenCounters}
                  alwaysTimestamps={settings.chat.showTimestamps === 'always'}
                />
              </Fragment>
            );
          })}
          {/* Status line while preparing */}
          {busy && !Object.keys(streaming).length && (
            <div className="flex items-center gap-2 px-1 py-2 text-[13px] text-muted-foreground" role="status">
              <span className="flex gap-1" aria-hidden>
                <Dot delay="0ms" />
                <Dot delay="150ms" />
                <Dot delay="300ms" />
              </span>
              {status.message || 'Working…'}
            </div>
          )}
          <div ref={bottomRef} />
        </div>
      </div>
      </div>

      {/* Follow-up suggestion chips for the latest reply. */}
      {settings.chat.followUpSuggestions && (() => {
        const lastMsg = messages[messages.length - 1];
        if (!lastMsg || lastMsg.role !== 'assistant' || busy) return null;
        if (!lastMsg.content.trim()) return null;
        const lastUser = [...messages].reverse().find((m) => m.role === 'user');
        return (
          <FollowUpSuggestions
            key="follow-ups"
            messageId={lastMsg.id}
            userText={lastUser?.content ?? ''}
            assistantText={lastMsg.content}
            onPick={(text) => {
              setDraft(text);
              requestAnimationFrame(() => textareaRef.current?.focus());
            }}
          />
        );
      })()}

      {/* Tool confirmation banner */}
      {pipeline.pendingToolEvent && status.state === 'waitingForToolConfirmation' && (
        <div
          role="alertdialog"
          aria-label="Tool confirmation"
          className="mx-auto mb-2 w-full max-w-3xl rounded-xl border-2 border-brand-strong bg-brand-soft px-4 py-3 px-4 dark:bg-brand/10"
        >
          <p className="text-[13px] font-semibold">PocketLLM wants to run a tool</p>
          <p className="mt-0.5 text-[12px] text-muted-foreground">
            <span className="font-mono font-medium">{pipeline.pendingToolEvent.tool}</span> — review the exact
            arguments before approving. Authorization applies only to these values.
          </p>
          <pre className="mt-2 max-h-32 overflow-auto rounded-lg bg-background/70 p-2 font-mono text-[11px] scrollbar-slim">
            {JSON.stringify(pipeline.pendingToolEvent.args, null, 2)}
          </pre>
          <div className="mt-2 flex justify-end gap-2">
            <button
              className="rounded-lg border border-border px-3 py-1.5 text-xs hover:bg-muted"
              onClick={() => pipeline.resolveToolConfirmation(false)}
            >
              Cancel
            </button>
            <button
              className="rounded-lg bg-primary px-3 py-1.5 text-xs font-medium text-primary-foreground"
              onClick={() => pipeline.resolveToolConfirmation(true)}
            >
              Allow once
            </button>
          </div>
        </div>
      )}

      {/* Composer */}
      <div
        className="shrink-0 border-t border-border bg-background px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-3 md:px-4"
        style={{ paddingBottom: 'max(0.75rem, env(safe-area-inset-bottom))' }}
      >
        <div className="mx-auto w-full max-w-3xl">
          {/* One-time j/k navigation hint (dismissed → persisted setting). */}
          {!settings.chat.jkHintDismissed && messages.length > 0 && (
            <div
              className="mb-2 flex items-center gap-2 rounded-xl border border-brand/40 bg-brand-soft/75 px-3 py-1.5 text-[12px] text-foreground animate-rise-in dark:bg-brand/10"
              role="note"
              aria-label="Keyboard navigation tip"
            >
              <BrainCircuit className="h-3.5 w-3.5 shrink-0 text-brand-strong" aria-hidden="true" />
              <span className="min-w-0 flex-1 leading-snug">
                Tip: <MiniKbd>j</MiniKbd>/<MiniKbd>k</MiniKbd> moves through messages,{' '}
                <MiniKbd>c</MiniKbd> copies, <MiniKbd>s</MiniKbd> stars, <MiniKbd>esc</MiniKbd> exits.
              </span>
              <button
                type="button"
                onClick={() => settingsService.patch({ chat: { jkHintDismissed: true } })}
                className="flex h-5 w-5 shrink-0 items-center justify-center self-center rounded-md text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                aria-label="Dismiss keyboard navigation tip"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            </div>
          )}
          {/* Per-chat knowledge scope chips (mirror of the attachment chips). */}
          {chat && (
            <KnowledgeScopeChips
              chat={chat}
              docs={readyDocs}
              onChange={changeScope}
              onModeChange={changeRetrievalMode}
            />
          )}
          {attachments.length > 0 && (
            <div className="mb-2.5 flex flex-wrap gap-2">
              {attachments.map((a) => (
                <span
                  key={a.id}
                  className="group/att relative inline-flex items-center gap-1.5 rounded-lg border border-border bg-card px-2 py-1 text-[11px] text-muted-foreground"
                >
                  <ImageIcon className="h-3 w-3" />
                  <span className="max-w-[140px] truncate">{a.name}</span>
                  <span className="text-[10px] opacity-60">{formatBytes(a.sizeBytes)}</span>
                  <button
                    className="rounded p-0.5 hover:bg-muted"
                    aria-label={`Remove ${a.name}`}
                    onClick={() => setAttachments((prev) => prev.filter((x) => x.id !== a.id))}
                  >
                    <X className="h-3 w-3" />
                  </button>
                </span>
              ))}
            </div>
          )}

          <form
            className="relative"
            onSubmit={(e) => {
              e.preventDefault();
              void send();
            }}
          >
            {/* Slash command menu — anchored above the composer input. */}
            {slash.open && (
              <SlashMenu
                filtered={slash.filtered}
                index={slash.index}
                setIndex={slash.setIndex}
                onPickRow={(command: SlashCommand) => command.run()}
              />
            )}
            <div
              className={cn(
                'flex items-end gap-1.5 rounded-2xl border border-border bg-card p-1.5 shadow-sm transition-all focus-within:border-brand-strong focus-within:ring-2 focus-within:ring-brand/25'
              )}
              onDragOver={(e) => e.preventDefault()}
              onDrop={(e) => {
                e.preventDefault();
                addFiles(e.dataTransfer.files);
              }}
            >
              <label
                className="flex h-9 w-9 cursor-pointer items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                title="Attach image"
              >
                <Paperclip className="h-4 w-4" />
                <span className="sr-only">Attach image</span>
                <input
                  type="file"
                  accept="image/*"
                  multiple
                  className="hidden"
                  onChange={(e) => e.target.files && addFiles(e.target.files)}
                />
              </label>
              {/* Knowledge scope picker — per-chat retrieval scoping. */}
              {chat && (
                <KnowledgeScopePicker
                  chat={chat}
                  docs={readyDocs}
                  onChange={changeScope}
                  onModeChange={changeRetrievalMode}
                  open={scopePickerOpen}
                  onOpenChange={setScopePickerOpen}
                />
              )}
              <textarea
                ref={textareaRef}
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => {
                  // Slash menu gets first claim on navigation keys.
                  if (slash.handleKeyDown(e)) return;
                  if (e.key === 'Enter' && !e.shiftKey && settings.general.sendOnEnter) {
                    e.preventDefault();
                    void send();
                  }
                }}
                placeholder={busy ? 'Generating…' : 'Message PocketLLM… “/” for commands · Shift+Enter for a new line'}
                aria-label="Message PocketLLM"
                rows={1}
                className="max-h-[180px] min-h-[38px] flex-1 resize-none bg-transparent px-2 py-2 text-[15px] outline-none placeholder:text-muted-foreground/75"
              />
              <button
                type="button"
                onClick={enhance}
                disabled={!draft.trim() || enhancing}
                className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-muted hover:text-foreground disabled:opacity-40"
                title="Enhance prompt"
                aria-label="Enhance prompt"
              >
                <Sparkles className={cn('h-4 w-4', enhancing && 'animate-pulse text-brand-strong')} />
              </button>
              {recording ? (
                <button
                  type="button"
                  onClick={stopRecording}
                  className="flex h-9 w-9 items-center justify-center rounded-xl bg-destructive text-white"
                  aria-label="Stop recording"
                >
                  <Square className="h-3.5 w-3.5 fill-current" />
                </button>
              ) : (
                <button
                  type="button"
                  onClick={startRecording}
                  className="flex h-9 w-9 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
                  aria-label="Dictate"
                  title="Dictate"
                >
                  <Mic className="h-4 w-4" />
                </button>
              )}
              {busy ? (
                <button
                  type="button"
                  onClick={() => pipeline.stop()}
                  className="flex h-9 items-center gap-1.5 rounded-xl bg-primary px-3 text-[13px] font-medium text-primary-foreground transition-transform active:scale-95"
                  aria-label="Stop generation"
                >
                  <Square className="h-3 w-3 fill-current" />
                  Stop
                </button>
              ) : (
                <button
                  type="submit"
                  disabled={!draft.trim() && attachments.length === 0}
                  className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary text-primary-foreground shadow-sm transition-all hover:-translate-y-px hover:shadow-md active:scale-90 active:translate-y-0 disabled:pointer-events-none disabled:opacity-30 disabled:shadow-none"
                  aria-label="Send message"
                >
                  <ArrowUp className="h-4 w-4" />
                </button>
              )}
            </div>
          </form>
          {/* Composer meta line: context budget · privacy note · draft state. */}
          <div className="mt-1.5 hidden items-center justify-between gap-3 text-[10px] text-muted-foreground/60 sm:flex">
            {/* Context budget — same honest chars/4 estimate as the
                inspector, over the model's real window (or assumed 8k). */}
            <span
              className="inline-flex items-center gap-1.5 rounded-full border border-border/60 bg-card/60 px-2 py-0.5 font-medium tabular-nums"
              title={
                contextAssumed
                  ? 'Estimated share of an assumed 8k-token window (this runtime reports no limit).'
                  : 'Estimated share of this model\'s context window used by the recent messages.'
              }
            >
              <Gauge
                className={cn(
                  'h-3 w-3',
                  contextPct >= 95 ? 'text-destructive' : contextPct >= 80 ? 'text-warning' : 'text-brand-strong'
                )}
                aria-hidden
              />
              <span
                className={cn(
                  contextPct >= 95 ? 'text-destructive' : contextPct >= 80 ? 'text-warning' : 'text-muted-foreground'
                )}
              >
                {contextPct}% context
              </span>
            </span>
            <span className="text-center">
              {settings.privacy.strictOffline
                ? 'Strict Offline — only local runtimes can answer.'
                : 'Chats are stored only in this browser. Models can make mistakes.'}
            </span>
            <span className="inline-flex items-center gap-2">
              {draftSaved && (
                <span
                  className="inline-flex items-center gap-1 rounded-full bg-success/10 px-2 py-0.5 text-[9.5px] font-medium text-success transition-opacity"
                  role="status"
                >
                  <CheckCircle2 className="h-3 w-3" />
                  Draft saved
                </span>
              )}
              {draft.length > 120 && (
                <span className="font-mono tabular-nums" aria-label="Draft size">
                  {draft.length.toLocaleString()} chars ·{' '}
                  {draft.trim().split(/\s+/).length.toLocaleString()} words
                </span>
              )}
            </span>
          </div>
        </div>
      </div>
      </div>

      {/* Inspector — third column on xl+ (plan §15) */}
      {inspectorOpen && chat && (
        <div className="hidden h-full xl:block">
          <InspectorPanel
            chat={chat}
            branches={branches}
            onChatChanged={() => {
              // Tags changed in the inspector — reload chat state so the
              // header/row chips stay in sync.
              void chatService.getChat(chat.id).then((c) => {
                if (c) setChat(c);
              });
            }}
          />
        </div>
      )}
    </div>
  );
}

function HeaderIconButton({
  label,
  onClick,
  children,
  active,
  danger,
  className,
}: {
  label: string;
  onClick: () => void;
  children: React.ReactNode;
  active?: boolean;
  danger?: boolean;
  className?: string;
}) {
  return (
    <button
      onClick={onClick}
      title={label}
      aria-label={label}
      aria-pressed={active}
      className={cn(
        'rounded-lg p-2 text-muted-foreground transition-all hover:bg-muted hover:text-foreground active:scale-90',
        active && 'bg-muted text-brand-strong',
        danger && 'hover:text-destructive',
        className
      )}
    >
      {children}
    </button>
  );
}

function Dot({ delay }: { delay: string }) {
  return (
    <span
      className="h-1.5 w-1.5 animate-bounce rounded-full bg-muted-foreground/60"
      style={{ animationDelay: delay }}
    />
  );
}

/** Tiny keyboard-key chip used by the j/k navigation position pill. */
function MiniKbd({ children }: { children: React.ReactNode }) {
  return (
    <kbd className="rounded border border-border bg-muted px-1 py-px font-mono text-[9.5px] font-semibold text-foreground">
      {children}
    </kbd>
  );
}

/** Starter chips offered when a brand-new chat has no messages yet. */
const STARTER_CHIPS = [
  'Explain a concept simply',
  'Brainstorm ideas for a project',
  'Draft a short email',
  'Summarize my documents',
  'Help me plan a week',
];

/** True when two timestamps fall on the same local calendar day. */
function sameLocalDay(a: number, b: number): boolean {
  const da = new Date(a);
  const db = new Date(b);
  return (
    da.getFullYear() === db.getFullYear() &&
    da.getMonth() === db.getMonth() &&
    da.getDate() === db.getDate()
  );
}

/** Human label for a day-separator chip ("Today", "Yesterday", "Mon, Sep 15"). */
function dayLabel(ts: number): string {
  const now = Date.now();
  if (sameLocalDay(ts, now)) return 'Today';
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  if (sameLocalDay(ts, yesterday.getTime())) return 'Yesterday';
  return new Date(ts).toLocaleDateString(undefined, {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  });
}

void Check;
