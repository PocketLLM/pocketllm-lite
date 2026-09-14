import { webcrypto } from "node:crypto";
import "fake-indexeddb/auto";
import "@testing-library/jest-dom/vitest";
Object.defineProperty(globalThis.navigator, "storage", {
  configurable: true,
  value: {
    estimate: async () => ({ usage: 1024, quota: 1048576 }),
    persisted: async () => false,
    persist: async () => true
  }
});

if (!globalThis.crypto?.subtle) {
  Object.defineProperty(globalThis, "crypto", { configurable: true, value: webcrypto });
}
