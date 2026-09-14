import { setting } from "../db/db";

let extractorPromise: Promise<any> | null = null;
let extractorModel = "";

async function loadExtractor() {
  const model = await setting("ragEmbeddingModel", "Xenova/all-MiniLM-L6-v2");
  if (!extractorPromise || extractorModel !== model) {
    extractorModel = model;
    extractorPromise = (async () => {
      const { pipeline, env } = await import("@huggingface/transformers");
      const strictOffline = await setting("strictOffline", false);
      env.allowRemoteModels = !strictOffline;
      const device = (navigator as Navigator & { gpu?: unknown }).gpu ? "webgpu" : "wasm";
      try {
        return await pipeline("feature-extraction", model, { device });
      } catch (error) {
        if (device === "webgpu") {
          return pipeline("feature-extraction", model, { device: "wasm" });
        }
        throw error;
      }
    })();
  }
  return extractorPromise;
}

export async function embedTexts(texts: string[]): Promise<number[][]> {
  if (!texts.length) return [];
  const extractor = await loadExtractor();
  const output = await extractor(texts, { pooling: "mean", normalize: true });
  const values = output.tolist() as number[][];
  return values;
}

export async function embedText(text: string) {
  return (await embedTexts([text]))[0] ?? [];
}

export function cosine(left: number[] | undefined, right: number[] | undefined) {
  if (!left?.length || !right?.length || left.length !== right.length) return 0;
  let dot = 0;
  let a = 0;
  let b = 0;
  for (let index = 0; index < left.length; index += 1) {
    dot += left[index] * right[index];
    a += left[index] ** 2;
    b += right[index] ** 2;
  }
  return a && b ? dot / Math.sqrt(a * b) : 0;
}

export function unloadEmbeddingModel() {
  extractorPromise = null;
  extractorModel = "";
}
