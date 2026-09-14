import { db, logActivity, setting } from "../db/db";
import type { DocumentChunk, KnowledgeDocument } from "./types";
import { embedTexts } from "./embeddings";
import { sha256, writeOpfs } from "./storage";

const MAX_TEXT_FILE_BYTES = 20 * 1024 * 1024;
const MAX_PDF_BYTES = 60 * 1024 * 1024;

type Extracted = { text: string; pages?: Array<{ page: number; text: string }>; pageCount?: number };

async function extractPdf(file: File): Promise<Extracted> {
  if (file.size > MAX_PDF_BYTES) throw new Error("PDF is larger than the 60 MB browser indexing limit.");
  const pdfjs = await import("pdfjs-dist");
  const workerUrl = (await import("pdfjs-dist/build/pdf.worker.min.mjs?url")).default;
  pdfjs.GlobalWorkerOptions.workerSrc = workerUrl;
  const task = pdfjs.getDocument({ data: new Uint8Array(await file.arrayBuffer()) });
  const pdf = await task.promise;
  const pages: Array<{ page: number; text: string }> = [];
  let total = "";
  for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber += 1) {
    const page = await pdf.getPage(pageNumber);
    const content = await page.getTextContent();
    const text = content.items
      .map((item) => ("str" in item ? item.str : ""))
      .join(" ")
      .replace(/\s+/g, " ")
      .trim();
    pages.push({ page: pageNumber, text });
    total += `${text}\n\n`;
  }
  if (total.trim().length < 40) {
    throw new Error("This PDF appears to be image-only or has no extractable text. OCR is not enabled for this document.");
  }
  return { text: total.trim(), pages, pageCount: pdf.numPages };
}

async function extractText(file: File): Promise<Extracted> {
  if (file.size > MAX_TEXT_FILE_BYTES) throw new Error("Text document is larger than the 20 MB browser indexing limit.");
  const text = await file.text();
  if (!text.trim()) throw new Error("The document is empty.");
  return { text };
}

export async function extractDocument(file: File): Promise<Extracted> {
  const lower = file.name.toLowerCase();
  if (lower.endsWith(".pdf") || file.type === "application/pdf") return extractPdf(file);
  if (
    lower.endsWith(".txt") ||
    lower.endsWith(".md") ||
    lower.endsWith(".markdown") ||
    lower.endsWith(".csv") ||
    file.type.startsWith("text/")
  ) return extractText(file);
  throw new Error("Supported document types are PDF, TXT, Markdown and CSV.");
}

function chunkString(text: string, maxChars = 1400, overlap = 220) {
  const paragraphs = text.split(/\n{2,}/).map((item) => item.trim()).filter(Boolean);
  const chunks: Array<{ content: string; start: number; end: number }> = [];
  let buffer = "";
  let start = 0;
  let cursor = 0;

  for (const paragraph of paragraphs) {
    if (!buffer) start = cursor;
    const candidate = buffer ? `${buffer}\n\n${paragraph}` : paragraph;
    if (candidate.length <= maxChars) {
      buffer = candidate;
    } else {
      if (buffer) chunks.push({ content: buffer, start, end: start + buffer.length });
      const carry = buffer.slice(Math.max(0, buffer.length - overlap));
      buffer = carry ? `${carry}\n\n${paragraph}` : paragraph;
      start = Math.max(0, cursor - carry.length);
      while (buffer.length > maxChars) {
        const piece = buffer.slice(0, maxChars);
        chunks.push({ content: piece, start, end: start + piece.length });
        buffer = buffer.slice(maxChars - overlap);
        start += maxChars - overlap;
      }
    }
    cursor += paragraph.length + 2;
  }
  if (buffer) chunks.push({ content: buffer, start, end: start + buffer.length });
  return chunks;
}

export async function ingestDocument(file: File, options?: { semantic?: boolean; onProgress?: (value: number, label: string) => void; documentId?: string }) {
  const onProgress = options?.onProgress ?? (() => {});
  onProgress(0.05, "Reading file");
  const hash = await sha256(file);
  const existing = options?.documentId ? undefined : await db.documents.where("sha256").equals(hash).first();
  if (existing) return existing;

  const extracted = await extractDocument(file);
  onProgress(0.2, "Extracting text");

  const id = options?.documentId ?? crypto.randomUUID();
  const safeName = file.name.replace(/[^a-zA-Z0-9._-]+/g, "_");
  const opfsPath = `documents/${hash}/${safeName}`;
  await writeOpfs(opfsPath, file);

  const rawChunks: Array<{ content: string; page?: number; start?: number; end?: number }> = [];
  if (extracted.pages?.length) {
    for (const page of extracted.pages) {
      for (const chunk of chunkString(page.text)) {
        rawChunks.push({ content: chunk.content, page: page.page, start: chunk.start, end: chunk.end });
      }
    }
  } else {
    for (const chunk of chunkString(extracted.text)) {
      rawChunks.push({ content: chunk.content, start: chunk.start, end: chunk.end });
    }
  }

  onProgress(0.35, "Chunking");
  let embeddings: number[][] | undefined;
  if (options?.semantic) {
    onProgress(0.45, "Loading embedding model");
    const batchSize = 12;
    embeddings = [];
    for (let index = 0; index < rawChunks.length; index += batchSize) {
      const batch = rawChunks.slice(index, index + batchSize);
      embeddings.push(...(await embedTexts(batch.map((chunk) => chunk.content))));
      onProgress(0.45 + 0.45 * Math.min(1, (index + batch.length) / rawChunks.length), "Embedding chunks");
    }
  }

  const chunks: DocumentChunk[] = rawChunks.map((chunk, index) => ({
    id: crypto.randomUUID(),
    documentId: id,
    index,
    content: chunk.content,
    page: chunk.page,
    startOffset: chunk.start,
    endOffset: chunk.end,
    embedding: embeddings?.[index],
  }));

  const now = Date.now();
  const mode = options?.semantic ? await setting<KnowledgeDocument["retrievalMode"]>("ragRetrievalMode", "hybrid") : "keyword";
  const document: KnowledgeDocument = {
    id,
    name: file.name,
    mimeType: file.type || "application/octet-stream",
    size: file.size,
    sha256: hash,
    opfsPath,
    text: extracted.text,
    pageCount: extracted.pageCount,
    chunkCount: chunks.length,
    retrievalMode: mode,
    embeddingModel: options?.semantic ? await setting("ragEmbeddingModel", "Xenova/all-MiniLM-L6-v2") : undefined,
    indexedAt: now,
    createdAt: now,
    updatedAt: now,
  };

  await db.transaction("rw", db.documents, db.documentChunks, async () => {
    await db.documents.add(document);
    await db.documentChunks.bulkAdd(chunks);
  });
  await logActivity("knowledge", "Document indexed", `${file.name} · ${chunks.length} chunks`);
  onProgress(1, "Ready");
  return document;
}

export async function reindexDocument(documentId: string, semantic: boolean, onProgress?: (value: number, label: string) => void) {
  const document = await db.documents.get(documentId);
  if (!document) throw new Error("Document not found.");
  const file = document.opfsPath ? await (await import("./storage")).readOpfs(document.opfsPath) : new File([document.text], document.name, { type: document.mimeType });
  await db.transaction("rw", db.documents, db.documentChunks, async () => {
    await db.documentChunks.where("documentId").equals(documentId).delete();
    await db.documents.delete(documentId);
  });
  return ingestDocument(new File([file], document.name, { type: document.mimeType }), {
    semantic,
    onProgress,
    documentId,
  });
}

export async function deleteDocument(documentId: string) {
  const document = await db.documents.get(documentId);
  await db.transaction("rw", db.documents, db.documentChunks, async () => {
    await db.documentChunks.where("documentId").equals(documentId).delete();
    await db.documents.delete(documentId);
  });
  if (document?.opfsPath) {
    const { deleteOpfs } = await import("./storage");
    await deleteOpfs(document.opfsPath).catch(() => undefined);
  }
}


export async function clearDocumentIndex(documentId: string) {
  const document = await db.documents.get(documentId);
  if (!document) throw new Error("Document not found.");
  await db.transaction("rw", db.documents, db.documentChunks, async () => {
    await db.documentChunks.where("documentId").equals(documentId).delete();
    await db.documents.update(documentId, {
      chunkCount: 0,
      retrievalMode: "keyword",
      embeddingModel: undefined,
      indexedAt: undefined,
      updatedAt: Date.now(),
    });
  });
  await logActivity("knowledge", "Document index removed", document.name);
}

export async function setDocumentRetrievalMode(
  documentId: string,
  mode: KnowledgeDocument["retrievalMode"],
  onProgress?: (value: number, label: string) => void,
) {
  const document = await db.documents.get(documentId);
  if (!document) throw new Error("Document not found.");
  const chunks = await db.documentChunks.where("documentId").equals(documentId).toArray();

  if (mode !== "keyword" && (!chunks.length || !chunks.some((chunk) => chunk.embedding?.length))) {
    const rebuilt = await reindexDocument(documentId, true, onProgress);
    await db.documents.update(rebuilt.id, { retrievalMode: mode, updatedAt: Date.now() });
    return db.documents.get(rebuilt.id);
  }

  await db.documents.update(documentId, { retrievalMode: mode, updatedAt: Date.now() });
  return db.documents.get(documentId);
}
