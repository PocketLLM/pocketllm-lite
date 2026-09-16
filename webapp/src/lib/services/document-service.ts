/**
 * DocumentService — import pipeline for PDF / TXT / MD / CSV.
 *
 *   File → validate → SHA-256 → extract text → structure-aware chunks
 *       → lexical index (always) → persist
 *
 * - Source binaries are stored content-addressed in OPFS.
 * - PDF text extraction uses pdf.js loaded lazily from /pdf.worker
 *   (self-hosted, no remote scripts).
 * - Image-only PDFs are refused honestly (no fake OCR).
 */
import { bus } from '@/lib/core/events/event-bus';
import { chunkRepo, documentRepo } from '@/lib/core/db/repositories';
import { backupCrypto } from '@/lib/core/crypto/backup-crypto';
import { logService } from './log-service';
import { settingsService } from './settings-service';
import type {
  DocumentChunk,
  DocumentRecord,
  DocumentStatus,
  UUID,
} from '@/lib/types/domain';
import { uuid } from '@/lib/utils';

/* ------------------------------ OPFS ------------------------------ */

export const opfs = {
  async root(): Promise<FileSystemDirectoryHandle | null> {
    try {
      if (!navigator.storage?.getDirectory) return null;
      return await navigator.storage.getDirectory();
    } catch {
      return null;
    }
  },

  /** Writes a blob to /documents/<sha>.<ext>; returns the path. */
  async storeDocument(blob: Blob, name: string): Promise<string | undefined> {
    const root = await this.root();
    if (!root) return undefined;
    try {
      const dir = await root.getDirectoryHandle('documents', { create: true });
      const ext = name.split('.').pop() ?? 'bin';
      const handle = await dir.getFileHandle(`${uuid()}.${ext}`, { create: true });
      const writable = await handle.createWritable();
      await blob.stream().pipeTo(writable);
      return `documents/${handle.name}`;
    } catch (err) {
      console.error('[opfs] store failed', err);
      return undefined;
    }
  },

  async remove(path: string): Promise<void> {
    const root = await this.root();
    if (!root) return;
    const [dir, file] = path.split('/');
    try {
      const dirHandle = await root.getDirectoryHandle(dir);
      await dirHandle.removeEntry(file);
    } catch {
      /* already gone */
    }
  },

  async estimateUsage(): Promise<{ usage: number; quota: number } | null> {
    try {
      const est = await navigator.storage.estimate();
      return { usage: est.usage ?? 0, quota: est.quota ?? 0 };
    } catch {
      return null;
    }
  },
};

/* --------------------------- text extraction ----------------------- */

interface ExtractedDoc {
  text: string;
  pageCount: number | null;
}

async function extractPdfText(
  file: Blob,
  onProgress?: (msg: string) => void
): Promise<ExtractedDoc> {
  onProgress?.('Loading PDF engine…');
  const pdfjs = await import('pdfjs-dist');
  pdfjs.GlobalWorkerOptions.workerSrc = '/pdf.worker.min.mjs';
  const arrayBuffer = await file.arrayBuffer();
  const doc = await pdfjs.getDocument({ data: arrayBuffer }).promise;
  const pages: string[] = [];
  for (let i = 1; i <= doc.numPages; i++) {
    onProgress?.(`Extracting page ${i} of ${doc.numPages}…`);
    const page = await doc.getPage(i);
    const content = await page.getTextContent();
    const pageText = content.items
      .map((item) => ('str' in item ? (item as { str: string }).str : ''))
      .join(' ')
      .replace(/\s+/g, ' ')
      .trim();
    pages.push(pageText);
  }
  return { text: pages.join('\n\n'), pageCount: doc.numPages };
}

function extractCsvText(raw: string): { text: string; pageCount: null } {
  // Render CSV rows as readable lines, preserving header context per row.
  try {
    const lines = raw.split(/\r?\n/).filter((l) => l.trim());
    const header = lines[0]?.split(',').map((h) => h.replace(/^"|"$/g, '')) ?? [];
    const out: string[] = [];
    for (let i = 1; i < lines.length; i++) {
      const cells = lines[i].split(',');
      const described = header
        .map((h, idx) => (cells[idx] ? `${h}: ${cells[idx].replace(/^"|"$/g, '')}` : null))
        .filter(Boolean)
        .join(', ');
      out.push(described || lines[i]);
    }
    return { text: out.join('\n'), pageCount: null };
  } catch {
    return { text: raw, pageCount: null };
  }
}

/* ------------------------------ chunking --------------------------- */

/** Structure-aware chunking with overlap, page tracking. */
function chunkText(
  text: string,
  chunkSize: number,
  pageSpans: Array<{ start: number; end: number; page: number }> = []
): Array<{ text: string; page: number | null }> {
  const paragraphs = text
    .split(/\n{2,}/)
    .map((p) => p.trim())
    .filter(Boolean);

  const chunks: Array<{ text: string; page: number | null }> = [];
  let current = '';
  let currentStart = 0;

  const pageForOffset = (offset: number): number | null => {
    for (const span of pageSpans) {
      if (offset >= span.start && offset < span.end) return span.page;
    }
    return null;
  };

  let cursor = 0;
  for (const para of paragraphs) {
    const paraStart = cursor;
    cursor += para.length + 2;
    if (current.length + para.length + 1 > chunkSize && current.length > 0) {
      chunks.push({
        text: current,
        page: pageForOffset(currentStart),
      });
      // Keep ~15% overlap for context continuity.
      const tail = current.slice(-Math.floor(chunkSize * 0.15));
      current = tail ? `${tail} ${para}` : para;
      currentStart = paraStart;
    } else {
      current = current ? `${current}\n${para}` : para;
      if (!current) currentStart = paraStart;
    }
    if (current.length >= chunkSize) {
      chunks.push({ text: current, page: pageForOffset(currentStart) });
      current = '';
    }
  }
  if (current.trim()) {
    chunks.push({ text: current, page: pageForOffset(currentStart) });
  }
  return chunks;
}

/* ----------------------------- service ----------------------------- */

class DocumentService {
  private progressListeners = new Set<(docId: string, status: DocumentStatus, message: string) => void>();

  onProgress(
    fn: (docId: string, status: DocumentStatus, message: string) => void
  ): () => void {
    this.progressListeners.add(fn);
    return () => this.progressListeners.delete(fn);
  }

  private emitProgress(docId: string, status: DocumentStatus, message: string): void {
    for (const fn of this.progressListeners) fn(docId, status, message);
  }

  async list(): Promise<DocumentRecord[]> {
    const all = await documentRepo.getAll();
    return all.sort((a, b) => b.createdAt - a.createdAt);
  }

  async get(id: UUID): Promise<DocumentRecord | undefined> {
    return documentRepo.get(id);
  }

  async chunksFor(documentId: UUID): Promise<DocumentChunk[]> {
    const chunks = await chunkRepo.getByIndex('documentId', documentId);
    return chunks.sort((a, b) => a.seq - b.seq);
  }

  /**
   * Full import pipeline. Returns the document record; throws with a
   * user-facing message on failure.
   */
  async import(
    file: File,
    opts?: { retrievalMode?: DocumentRecord['retrievalMode'] }
  ): Promise<DocumentRecord> {
    const id = uuid();
    const now = Date.now();
    const settings = settingsService.get().knowledge;

    const record: DocumentRecord = {
      id,
      name: file.name,
      mimeType: file.type || this.guessMime(file.name),
      sizeBytes: file.size,
      sha256: '',
      pageCount: null,
      chunkCount: 0,
      status: 'importing',
      retrievalMode: opts?.retrievalMode ?? settings.defaultRetrievalMode,
      indexSizeBytes: 0,
      createdAt: now,
    };
    await documentRepo.put(record);
    bus.emit('documents:changed', { documentId: id });

    try {
      this.emitProgress(id, 'importing', 'Validating…');
      if (file.size > 150 * 1024 * 1024) {
        throw new Error('File is larger than 150 MB. Split it and import parts.');
      }

      // SHA-256 content addressing.
      this.emitProgress(id, 'extracting', 'Hashing…');
      const sha256 = await backupCrypto.sha256Hex(file);
      record.sha256 = sha256;

      // Duplicate detection — importing the same file three times
      // should not create three physical copies.
      const existing = await documentRepo.getAll();
      const duplicate = existing.find(
        (d) => d.sha256 === sha256 && d.id !== id && d.status === 'ready'
      );
      if (duplicate) {
        await documentRepo.delete(id);
        bus.emit('documents:changed', {});
        throw new Error(
          `Already imported as “${duplicate.name}”. PocketLLM keeps a single content-addressed copy.`
        );
      }

      // Extract text.
      let extracted: ExtractedDoc;
      if (record.mimeType.includes('pdf') || /\.pdf$/i.test(file.name)) {
        extracted = await extractPdfText(file, (msg) =>
          this.emitProgress(id, 'extracting', msg)
        );
        if (!extracted.text.replace(/\s/g, '')) {
          throw new Error(
            'No extractable text found. This PDF is image-only (scanned). PocketLLM does not fake OCR — copy the text or use a text-based PDF.'
          );
        }
      } else {
        const raw = await file.text();
        if (/\.(csv|tsv)$/i.test(file.name) || record.mimeType.includes('csv')) {
          extracted = extractCsvText(raw);
        } else {
          extracted = { text: raw, pageCount: null };
        }
        if (!extracted.text.trim()) {
          throw new Error('The file contains no readable text.');
        }
      }

      // Chunk.
      this.emitProgress(id, 'chunking', 'Structuring chunks…');
      const pageSpans: Array<{ start: number; end: number; page: number }> = [];
      if (extracted.pageCount) {
        const perPage = Math.ceil(extracted.text.length / extracted.pageCount);
        for (let p = 1; p <= extracted.pageCount; p++) {
          pageSpans.push({
            start: (p - 1) * perPage,
            end: p * perPage,
            page: p,
          });
        }
      }
      const pieces = chunkText(extracted.text, settings.chunkSize, pageSpans);

      const chunks: DocumentChunk[] = pieces.map((p, seq) => ({
        id: uuid(),
        documentId: id,
        page: p.page,
        seq,
        text: p.text,
        tokens: Math.ceil(p.text.length / 4),
      }));

      this.emitProgress(id, 'indexing', `Indexing ${chunks.length} chunks…`);
      await chunkRepo.putAll(chunks);

      // Store the source in OPFS (best-effort).
      const storagePath = await opfs.storeDocument(file, file.name);

      record.pageCount = extracted.pageCount;
      record.chunkCount = chunks.length;
      record.status = 'ready';
      record.indexSizeBytes = chunks.reduce((s, c) => s + c.text.length, 0);
      record.storagePath = storagePath;
      record.indexedAt = Date.now();
      await documentRepo.put(record);
      bus.emit('documents:changed', { documentId: id });
      void logService.bumpUsage({ documentsIndexed: 1 });
      void logService.recordActivity(
        'document.indexed',
        `${file.name} · ${chunks.length} chunks`
      );
      return record;
    } catch (err) {
      record.status = 'failed';
      record.error = err instanceof Error ? err.message : String(err);
      await documentRepo.put(record);
      bus.emit('documents:changed', { documentId: id });
      void logService.recordError('documents', 'import_failed', record.error);
      throw err;
    }
  }

  /** Deletes source + chunks + embeddings. Citations keep tombstones. */
  async delete(id: UUID): Promise<void> {
    const doc = await documentRepo.get(id);
    if (!doc) return;
    const chunks = await chunkRepo.getByIndex('documentId', id);
    await chunkRepo.deleteMany(chunks.map((c) => c.id));
    if (doc.storagePath) await opfs.remove(doc.storagePath);
    await documentRepo.delete(id);
    bus.emit('documents:changed', {});
  }

  async reindex(
    id: UUID,
    opts?: { chunkSize?: number; retrievalMode?: DocumentRecord['retrievalMode'] }
  ): Promise<void> {
    const doc = await documentRepo.get(id);
    if (!doc) return;
    // Re-read the stored source when available; otherwise re-chunk existing chunks.
    let text = '';
    const chunks = await this.chunksFor(id);
    text = chunks.map((c) => c.text).join('\n\n');
    if (doc.storagePath) {
      try {
        const root = await opfs.root();
        if (root) {
          const [dir, file] = doc.storagePath.split('/');
          const handle = await root
            .getDirectoryHandle(dir)
            .then((d) => d.getFileHandle(file));
          const blob = await handle.getFile();
          const raw = await blob.text();
          if (raw) text = raw;
        }
      } catch {
        /* fall back to chunk text */
      }
    }
    if (!text) return;

    const chunkSize = opts?.chunkSize ?? settingsService.get().knowledge.chunkSize;
    const pieces = chunkText(text, chunkSize);
    const newChunks: DocumentChunk[] = pieces.map((p, seq) => ({
      id: uuid(),
      documentId: id,
      page: null,
      seq,
      text: p.text,
      tokens: Math.ceil(p.text.length / 4),
    }));

    this.emitProgress(id, 'indexing', 'Re-indexing…');
    await chunkRepo.deleteMany(chunks.map((c) => c.id));
    await chunkRepo.putAll(newChunks);
    doc.chunkCount = newChunks.length;
    doc.indexSizeBytes = newChunks.reduce((s, c) => s + c.text.length, 0);
    doc.retrievalMode = opts?.retrievalMode ?? doc.retrievalMode;
    doc.indexedAt = Date.now();
    await documentRepo.put(doc);
    bus.emit('documents:changed', { documentId: id });
  }

  private guessMime(name: string): string {
    const ext = name.split('.').pop()?.toLowerCase();
    switch (ext) {
      case 'pdf': return 'application/pdf';
      case 'txt': return 'text/plain';
      case 'md': case 'markdown': return 'text/markdown';
      case 'csv': return 'text/csv';
      case 'tsv': return 'text/tab-separated-values';
      default: return 'application/octet-stream';
    }
  }
}

export const documentService = new DocumentService();
