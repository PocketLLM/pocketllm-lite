import type { Metadata, Viewport } from "next";
import "./globals.css";
import { ThemeProvider } from "next-themes";
import { Toaster } from "@/components/ui/toaster";

/**
 * Root layout for PocketLLM Lite Web.
 *
 * - Loads the app type stack (Inter/Outfit/JetBrains Mono) plus the
 *   2026 marketing site stack (Caveat, Instrument Serif, Manrope) in
 *   one Google Fonts request so the ported landing page renders with
 *   its own typography from the first paint.
 * - Wraps the app in `next-themes` for light/dark/system support.
 * - Renders the shadcn Toaster for global notifications.
 */
export const metadata: Metadata = {
  title: "PocketLLM Lite — Your AI, on your terms",
  description:
    "PocketLLM Lite is a local-first, open-source AI workspace for Android with local models, Ollama, private memory, document RAG, tools, and explicit network controls.",
  keywords: [
    "PocketLLM",
    "local LLM",
    "offline AI",
    "Android AI",
    "Ollama",
    "GGUF",
    "RAG",
    "private AI",
  ],
  authors: [{ name: "PocketLLM" }],
  manifest: "/manifest.json",
  icons: {
    icon: "/logo.png",
    apple: "/logo.png",
  },
  openGraph: {
    title: "PocketLLM Lite — Your AI, on your terms",
    description:
      "Local-first AI with visible boundaries. Run compatible models on-device or connect an endpoint you control.",
    type: "website",
    images: ["/pocketllm-website/assets/hero-local-ai.webp"],
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#FFFDF5" },
    { media: "(prefers-color-scheme: dark)", color: "#131A22" },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        {/* App type stack + 2026 marketing type stack (one request) */}
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin="anonymous"
        />
        <link
          href="https://fonts.googleapis.com/css2?family=Caveat:wght@500;600&family=Instrument+Serif:ital@0;1&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&family=Manrope:wght@400;500;600;700&family=Outfit:wght@400;500;600;700&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="antialiased bg-background text-foreground min-h-screen">
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
        >
          {children}
          <Toaster />
        </ThemeProvider>
      </body>
    </html>
  );
}
