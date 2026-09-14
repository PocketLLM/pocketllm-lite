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
