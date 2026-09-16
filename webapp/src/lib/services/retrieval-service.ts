/**
 * RetrievalService — local RAG retrieval.
 *
 * - Lexical: BM25 over structure-aware chunks (always available).
 * - Semantic: local TF-IDF cosine vectors (no model download needed,
 *   honestly labelled "local vector" in the UI).
 * - Hybrid: score normalization + reciprocal rank fusion of both.
 *
 * Documents never leave the browser — retrieval runs entirely locally.
 */
import { chunkRepo, documentRepo } from '@/lib/core/db/repositories';
import type {
  Citation,
  DocumentChunk,
  RetrievalMode,
} from '@/lib/types/domain';
import { settingsService } from './settings-service';

/* ----------------------------- BM25 ------------------------------- */

interface BM25Doc {
  id: string;
  tf: Map<string, number>;
  length: number;
}

export class BM25Index {
  private docs: BM25Doc[] = [];
  private df = new Map<string, number>();
  private avgLen = 0;
  private readonly k1 = 1.5;
  private readonly b = 0.75;

  add(docId: string, text: string): void {
    const terms = tokenize(text);
    const tf = new Map<string, number>();
    for (const t of terms) tf.set(t, (tf.get(t) ?? 0) + 1);
    this.docs.push({ id: docId, tf, length: terms.length });
    for (const t of tf.keys()) this.df.set(t, (this.df.get(t) ?? 0) + 1);
    this.recomputeAvg();
  }

  private recomputeAvg(): void {
    this.avgLen =
      this.docs.length === 0
        ? 0
        : this.docs.reduce((s, d) => s + d.length, 0) / this.docs.length;
  }

  build(): void {
    this.recomputeAvg();
  }

  search(query: string): Array<{ id: string; score: number }> {
    const terms = tokenize(query);
    const N = this.docs.length;
    const results: Array<{ id: string; score: number }> = [];
    for (const doc of this.docs) {
      let score = 0;
      for (const term of terms) {
        const f = doc.tf.get(term);
        if (!f) continue;
        const n = this.df.get(term) ?? 0;
        const idf = Math.log(1 + (N - n + 0.5) / (n + 0.5));
        const denom = f + this.k1 * (1 - this.b + this.b * (doc.length / (this.avgLen || 1)));
        score += idf * ((f * (this.k1 + 1)) / denom);
      }
      if (score > 0) results.push({ id: doc.id, score });
    }
    return results.sort((a, b) => b.score - a.score);
  }
}

/* --------------------------- TF-IDF vectors ------------------------ */

export class TfidfIndex {
  private vectors = new Map<string, Map<string, number>>();
  private idf = new Map<string, number>();

  add(docId: string, text: string): void {
    const tf = termFreq(text);
    this.vectors.set(docId, tf);
  }

  build(): void {
    const N = this.vectors.size;
    this.idf = new Map();
    for (const tf of this.vectors.values()) {
      for (const t of tf.keys()) this.idf.set(t, (this.idf.get(t) ?? 0) + 1);
    }
    for (const [t, n] of this.idf) this.idf.set(t, Math.log(1 + N / n));
    // Apply idf weights.
    for (const [docId, tf] of this.vectors) {
      const weighted = new Map<string, number>();
      let norm = 0;
      for (const [t, f] of tf) {
        const w = f * (this.idf.get(t) ?? 0);
        weighted.set(t, w);
        norm += w * w;
      }
      norm = Math.sqrt(norm) || 1;
      for (const [t, w] of weighted) weighted.set(t, w / norm);
      this.vectors.set(docId, weighted);
    }
  }

  search(query: string): Array<{ id: string; score: number }> {
    const qv = this.vectorizeQuery(query);
    const results: Array<{ id: string; score: number }> = [];
    for (const [docId, dv] of this.vectors) {
      let dot = 0;
      for (const [t, w] of qv) {
        const dw = dv.get(t);
        if (dw) dot += w * dw;
      }
      if (dot > 0) results.push({ id: docId, score: dot });
    }
    return results.sort((a, b) => b.score - a.score);
  }

  private vectorizeQuery(text: string): Map<string, number> {
    const tf = termFreq(text);
    const out = new Map<string, number>();
    let norm = 0;
    for (const [t, f] of tf) {
      const w = f * (this.idf.get(t) ?? Math.log(2));
      out.set(t, w);
      norm += w * w;
    }
    norm = Math.sqrt(norm) || 1;
    for (const [t, w] of out) out.set(t, w / norm);
    return out;
  }
}

/* ----------------------------- helpers ----------------------------- */

export function tokenize(text: string): string[] {
  return (text ?? '')
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s-]/gu, ' ')
    .split(/\s+/)
    .filter((t) => t.length > 1 && t.length < 40);
}

function termFreq(text: string): Map<string, number> {
  const counts = new Map<string, number>();
  const tokens = tokenize(text);
  for (const t of tokens) counts.set(t, (counts.get(t) ?? 0) + 1);
  const total = tokens.length || 1;
  for (const [t, c] of counts) counts.set(t, c / total);
  return counts;
}

/** Reciprocal rank fusion. */
function rrf(
  ...lists: Array<Array<{ id: string; score: number }>>
): Array<{ id: string; score: number }> {
  const k = 60;
  const fused = new Map<string, number>();
  for (const list of lists) {
    list.forEach((item, rank) => {
      fused.set(item.id, (fused.get(item.id) ?? 0) + 1 / (k + rank + 1));
    });
  }
  return [...fused.entries()]
    .map(([id, score]) => ({ id, score }))
    .sort((a, b) => b.score - a.score);
}

/* --------------------------- service ------------------------------- */

export interface RetrievedChunk extends DocumentChunk {
  documentName: string;
  score: number;
}

class RetrievalService {
  /**
   * Retrieves top-k chunks for a query across all ready documents
   * using the configured mode (or override).
   */
  async retrieve(
    query: string,
    opts?: { mode?: RetrievalMode; documentIds?: string[]; topK?: number }
  ): Promise<RetrievedChunk[]> {
    const settings = settingsService.get().knowledge;
    const mode = opts?.mode ?? settings.defaultRetrievalMode;
    const topK = opts?.topK ?? settings.topK;

    const documents = (await documentRepo.getAll()).filter(
      (d) =>
        d.status === 'ready' &&
        (!opts?.documentIds || opts.documentIds.includes(d.id))
    );
    if (documents.length === 0) return [];

    const chunks: DocumentChunk[] = [];
    for (const doc of documents) {
      const docChunks = await chunkRepo.getByIndex('documentId', doc.id);
      chunks.push(...docChunks);
    }
    if (chunks.length === 0) return [];

    const nameById = new Map(documents.map((d) => [d.id, d.name] as const));

    let ranked: Array<{ id: string; score: number }>;
    if (mode === 'lexical') {
      ranked = this.lexical(chunks, query);
    } else if (mode === 'semantic') {
      ranked = this.semantic(chunks, query);
    } else {
      ranked = rrf(this.lexical(chunks, query), this.semantic(chunks, query));
    }

    const chunkById = new Map(chunks.map((c) => [c.id, c] as const));
    return ranked
      .slice(0, topK)
      .map((r) => ({
        ...(chunkById.get(r.id) as DocumentChunk),
        documentName: nameById.get(chunkById.get(r.id)?.documentId ?? '') ?? 'Unknown',
        score: r.score,
      }))
      .filter((c) => c.id);
  }

  private lexical(chunks: DocumentChunk[], query: string) {
    const index = new BM25Index();
    for (const c of chunks) index.add(c.id, c.text);
    index.build();
    return index.search(query);
  }

  private semantic(chunks: DocumentChunk[], query: string) {
    const index = new TfidfIndex();
    for (const c of chunks) index.add(c.id, c.text);
    index.build();
    return index.search(query);
  }

  /** Converts retrieved chunks to chat citations. */
  toCitations(chunks: RetrievedChunk[]): Citation[] {
    return chunks.map((c) => ({
      documentId: c.documentId,
      documentName: c.documentName,
      chunkId: c.id,
      page: c.page ?? undefined,
      excerpt: c.text.slice(0, 240),
      score: Math.round(c.score * 1000) / 1000,
    }));
  }
}

export const retrievalService = new RetrievalService();
