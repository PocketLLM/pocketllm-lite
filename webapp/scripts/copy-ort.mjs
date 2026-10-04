/**
 * Copies the ONNX Runtime WebAssembly files used by on-device speech
 * transcription (Transformers.js) into /public/ort so they are served
 * from this origin instead of a third-party CDN.
 *
 * Runs automatically before `dev` and `build`.
 */
import { copyFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const from = join(root, 'node_modules', 'onnxruntime-web', 'dist');
const to = join(root, 'public', 'ort');
const files = ['ort-wasm-simd-threaded.mjs', 'ort-wasm-simd-threaded.wasm'];

if (!existsSync(from)) {
  console.warn('[copy-ort] onnxruntime-web not installed — skipping.');
  process.exit(0);
}
mkdirSync(to, { recursive: true });
for (const file of files) copyFileSync(join(from, file), join(to, file));
console.log(`[copy-ort] copied ${files.length} files to public/ort`);
