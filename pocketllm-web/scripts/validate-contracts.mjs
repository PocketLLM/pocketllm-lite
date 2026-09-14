import fs from "node:fs";
import path from "node:path";
import Ajv2020 from "ajv/dist/2020.js";

const root = path.resolve(process.cwd(), "..");
const contractDir = path.join(root, "contracts");
const contractNames = [
  "message.schema.json",
  "chat.schema.json",
  "memory.schema.json",
  "provider.schema.json",
  "document.schema.json",
  "model-manifest.schema.json",
  "tool-call.schema.json",
  "network-audit.schema.json",
  "backup.schema.json"
];

const ajv = new Ajv2020({ allErrors: true, strict: false });
const schemas = new Map();
for (const name of contractNames) {
  const schema = JSON.parse(fs.readFileSync(path.join(contractDir, name), "utf8"));
  schemas.set(name, schema);
  ajv.addSchema(schema);
}

const now = new Date().toISOString();
const fixtures = new Map([
  ["message.schema.json", { id: "m1", chatId: "c1", role: "user", content: "hello", timestamp: now, createdAt: Date.now() }],
  ["chat.schema.json", { id: "c1", title: "Fixture chat", createdAt: now, model: "fixture", messages: [{ role: "user", content: "hello", timestamp: now }] }],
  ["memory.schema.json", { id: "mem1", type: "preference", subject: "user", fact: "Prefers concise answers", confidence: 0.9, sensitive: false, pinned: false, enabled: true, createdAt: now, updatedAt: now }],
  ["provider.schema.json", { id: "p1", name: "Local Ollama", kind: "ollama", baseUrl: "http://127.0.0.1:11434", model: "qwen" }],
  ["document.schema.json", { id: "d1", name: "notes.md", mimeType: "text/markdown", size: 10, sha256: "fixture", text: "hello", retrievalMode: "keyword" }],
  ["model-manifest.schema.json", { id: "model1", displayName: "Fixture model", source: "fixture", sha256: "fixture", capabilities: { text: true }, contextLimit: 4096 }],
  ["tool-call.schema.json", { name: "calculator", arguments: { expression: "2+2" }, risk: "low", requiresConfirmation: false }],
  ["network-audit.schema.json", { timestamp: now, destination: "http://127.0.0.1:11434", scope: "loopback", purpose: "provider-test", allowed: true }],
  ["backup.schema.json", { format: "pocketllm-backup", version: 3, kdf: { name: "PBKDF2-HMAC-SHA256", iterations: 600000, salt: "AA==" }, cipher: { name: "AES-256-GCM", nonce: "AA==", mac: "AA==" }, ciphertext: "AA==" }]
]);

for (const [name, fixture] of fixtures) {
  const schema = schemas.get(name);
  const validate = ajv.getSchema(schema.$id);
  if (!validate?.(fixture)) {
    console.error("Contract fixture failed:", name, validate?.errors);
    process.exit(1);
  }
}

const parity = fs.readFileSync(path.join(root, "parity/features.yaml"), "utf8");
const blocks = parity.split(/\n(?=- id: )/).filter((block) => block.startsWith("- id: "));
const ids = new Set();
for (const block of blocks) {
  const id = block.match(/^- id:\s*(.+)$/m)?.[1]?.trim();
  const mobile = block.match(/^\s*mobile:\s*(.+)$/m)?.[1]?.trim();
  const web = block.match(/^\s*web:\s*(.+)$/m)?.[1]?.trim();
  const reason = block.match(/^\s*reason:\s*(.+)$/m)?.[1]?.trim();
  if (!id || !mobile || !web) throw new Error("Parity entry is missing id/mobile/web:\n" + block);
  if (ids.has(id)) throw new Error("Duplicate parity feature id: " + id);
  ids.add(id);
  if (web === "constrained" && !reason) throw new Error("Constrained web feature must include a reason: " + id);
}
if (ids.size < 30) throw new Error("Parity manifest unexpectedly small: " + ids.size);

console.log(`Validated ${fixtures.size} contract fixtures and ${ids.size} parity entries.`);
