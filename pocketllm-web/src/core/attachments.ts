import type { AttachmentRef } from "./types";
import { sha256, writeOpfs } from "./storage";

const MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024;
const MAX_DIRECT_TEXT = 1_000_000;

function dataUrl(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(reader.error ?? new Error("Could not read image."));
    reader.onload = () => resolve(String(reader.result));
    reader.readAsDataURL(file);
  });
}

export async function prepareAttachment(file: File): Promise<AttachmentRef> {
  if (file.size > MAX_ATTACHMENT_BYTES) throw new Error(`${file.name} is larger than the 10 MB attachment limit.`);
  const id = crypto.randomUUID();
  const hash = await sha256(file);
  const path = `attachments/${hash}/${file.name.replace(/[^a-zA-Z0-9._-]+/g, "_")}`;
  await writeOpfs(path, file);

  if (file.type.startsWith("image/")) {
    return {
      id,
      name: file.name,
      mimeType: file.type,
      size: file.size,
      opfsPath: path,
      imageDataUrl: await dataUrl(file),
    };
  }

  if (
    file.type.startsWith("text/") ||
    /\.(txt|md|markdown|csv|json|xml|yaml|yml|js|ts|tsx|jsx|py|java|dart|go|rs|cpp|c|h|css|html)$/i.test(file.name)
  ) {
    if (file.size > MAX_DIRECT_TEXT) throw new Error(`${file.name} is too large for a direct chat attachment. Add it to Knowledge instead.`);
    return {
      id,
      name: file.name,
      mimeType: file.type || "text/plain",
      size: file.size,
      opfsPath: path,
      text: await file.text(),
    };
  }

  throw new Error(`${file.name} cannot be attached directly. Import PDF/large files into Knowledge.`);
}
