import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { resolve } from "node:path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

function copyWllamaWasm() {
  return {
    name: "copy-wllama-wasm",
    closeBundle() {
      const source = resolve("node_modules/@wllama/wllama/esm/wasm/wllama.wasm");
      const targetDir = resolve("dist/wllama");
      if (!existsSync(source)) {
        throw new Error("wllama wasm binary was not found in node_modules");
      }
      mkdirSync(targetDir, { recursive: true });
      copyFileSync(source, resolve(targetDir, "wllama.wasm"));
    },
  };
}

export default defineConfig({
  base: "/app/",
  plugins: [
    react(),
    copyWllamaWasm(),
    VitePWA({
      registerType: "prompt",
      includeAssets: ["icon.svg"],
      manifest: {
        name: "PocketLLM Web",
        short_name: "PocketLLM",
        description: "A local-first AI workspace for browser models and endpoints you control.",
        start_url: "/app/",
        scope: "/app/",
        display: "standalone",
        background_color: "#f7f7f4",
        theme_color: "#f7f7f4",
        icons: [
          { src: "/app/icon.svg", sizes: "any", type: "image/svg+xml", purpose: "any maskable" }
        ]
      },
      workbox: {
        navigateFallback: "/app/index.html",
        globPatterns: ["**/*.{js,css,html,svg}"],
        maximumFileSizeToCacheInBytes: 2 * 1024 * 1024,
        runtimeCaching: [
          {
            urlPattern: ({ url }) => url.origin === self.location.origin && url.pathname.endsWith(".wasm"),
            handler: "CacheFirst",
            options: {
              cacheName: "pocketllm-runtime-wasm",
              expiration: { maxEntries: 12, maxAgeSeconds: 60 * 60 * 24 * 365 }
            }
          }
        ]
      }
    })
  ],
  server: {
    headers: {
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Embedder-Policy": "require-corp",
      "Cross-Origin-Resource-Policy": "same-origin"
    }
  },
  preview: {
    headers: {
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Embedder-Policy": "require-corp",
      "Cross-Origin-Resource-Policy": "same-origin"
    }
  }
});
