import { sha256 } from "@noble/hashes/sha256";

self.addEventListener("message", async (event: MessageEvent<{ id: string; blob: Blob }>) => {
  const { id, blob } = event.data;
  try {
    const hasher = sha256.create();
    const reader = blob.stream().getReader();
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      hasher.update(value);
    }
    const digest = hasher.digest();
    const hex = Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
    postMessage({ id, hex });
  } catch (error) {
    postMessage({ id, error: error instanceof Error ? error.message : String(error) });
  }
});
